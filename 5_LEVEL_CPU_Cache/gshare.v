`include "rv32I.vh"

module gshare #(
    parameter BHR_WIDTH = 8,
    parameter PHT_SIZE = 2 ** BHR_WIDTH
) (
    input                           clk,
    input                           rst,
    (* max_fanout = 20 *)
    input                           pipe_hold,
    
    // 查询
    input      [BHR_WIDTH - 1:0]    pht_index_i,            // 控制模块提前算好的预测索�?
    input                           prev_b,                 // 控制模块返回上一个指令是否为 B 类型
    output                          pred_taken_o,           // 输出预测是否跳转
    output     [BHR_WIDTH - 1:0]    gshare_ghr_o,           // 输出 ghr 到控制模块以提前计算预测索引
    output     [BHR_WIDTH - 1:0]    gshare_ghr_update_o,    // 输出 ghr_d3 到控制模块以提前计算更新索引

    // 更新
    input                           update_en_i,            // ex 阶段返回�? PHT 更新使能
    input      [BHR_WIDTH - 1:0]    update_pht_index_i,     // ex 阶段返回并在控制模块提前算好的更新的索引
    input                           actual_taken_i          // ex 阶段判断跳转为真
);
    reg     [BHR_WIDTH - 1:0]   ghr;                        // GHR全局历史寄存器：用于投机更新
    reg     [BHR_WIDTH - 1:0]   ghr_d1;                     // EX阶段时的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d2;                     // EX阶段时的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d3;                     // 寄存更新后的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d4;                     // 寄存更新后的GHR
    (* ram_style = "block" *)
    reg     [1:0]               pht [0:PHT_SIZE - 1];       // PHT 2 位饱和计数器

    // 查询
    reg pht_update_en_r;
    reg [1:0] pht_reg, pht_update_old, pht_update_new, actual_taken_update_r;
    reg [BHR_WIDTH - 1:0] pht_index_update_r;
    wire [BHR_WIDTH - 1:0] ghr_update = ghr_d4;
    wire pred_taken = pht_reg[1];

    assign gshare_ghr_o         = ghr;
    assign gshare_ghr_update_o  = ghr_update;
    assign pred_taken_o         = pred_taken;

    // Block RAM
    integer i;
    initial begin
        for (i = 0; i < PHT_SIZE; i = i + 1) begin
            pht[i] = 2'b01;
        end
    end
    always @(posedge clk) begin
        // �?
        pht_reg         <= pht[pht_index_i];
        pht_update_old  <= pht[update_pht_index_i];

        // �?
        if (rst & pht_update_en_r) begin
            pht[pht_index_update_r] <= pht_update_new;
        end
    end
    
    // 更新
    always @(*) begin
        case(pht_update_old)
            2'b00:      pht_update_new = (actual_taken_update_r) ? 2'b01 : 2'b00;
            2'b01:      pht_update_new = (actual_taken_update_r) ? 2'b10 : 2'b00;
            2'b10:      pht_update_new = (actual_taken_update_r) ? 2'b11 : 2'b01;
            2'b11:      pht_update_new = (actual_taken_update_r) ? 2'b11 : 2'b10;
            default:    pht_update_new = 2'b01;
        endcase
    end

    // GHR - 流水线延�?
    reg pred_taken_r;
    always@(posedge clk) begin: gshare_ghr_ctrl
        if(!rst) begin
            ghr_d1  <= 0;
            ghr_d2  <= 0;
            ghr_d3  <= 0;
            ghr_d4  <= 0;
        end
        else if (!pipe_hold) begin
            ghr_d1  <= ghr;
            ghr_d2  <= ghr_d1;
            ghr_d3  <= ghr_d2;
            ghr_d4  <= ghr_d3;
        end
    end

    always@(posedge clk) begin: gshare_update_ctrl
        if(!rst) begin
            pht_update_en_r         <= 0;
            actual_taken_update_r   <= 0;
            pht_index_update_r      <= 0;
            pred_taken_r            <= 0;
        end
        else begin
            pht_update_en_r         <= update_en_i;
            actual_taken_update_r   <= actual_taken_i;
            pht_index_update_r      <= update_pht_index_i;
            pred_taken_r            <= pred_taken;
        end
    end
    
    // GHR
    always @(posedge clk) begin
        if (!rst) begin
            ghr     <= 0;
        end
        else begin
            if      (update_en_i)   ghr <= {ghr_update[BHR_WIDTH - 2:0], actual_taken_i};   // 预测错误回�??GHR
            else if (prev_b)        ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken_r};            // 预测投机更新GHR
        end
    end
endmodule