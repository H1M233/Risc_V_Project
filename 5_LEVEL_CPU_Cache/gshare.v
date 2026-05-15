`include "rv32I.vh"

// Gshare模块：
// 输入提前算好的 pht_index 返回最高位结果
// 并输出 ghr 和 ghr_d2 以用于在控制器内提前运算
// 若收到更新使能信号 update_en 则将提前算好的 update_pht_index 内容权重加减1 并恢复 ghr 状态
// 若收到上一个指令为 B 类型的信号 prev_b 则移动 ghr -> ghr_d1 -> ghr_d2

module gshare #(
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024
) (
    input                           clk,
    input                           rst,
    input                           pipe_hold,
    
    // 查询
    input      [BHR_WIDTH - 1:0]    pht_index_i,            // 控制模块提前算好的预测索引
    input                           prev_b,                 // 控制模块返回上一个指令是否为 B 类型
    output                          pred_taken_o,           // 输出预测是否跳转
    output     [BHR_WIDTH - 1:0]    gshare_ghr_o,           // 输出 ghr 到控制模块以提前计算预测索引
    output     [BHR_WIDTH - 1:0]    gshare_ghr_update_o,    // 输出 ghr_d3 到控制模块以提前计算更新索引

    // 更新
    input                           update_en_i,            // ex 阶段返回的 PHT 更新使能
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
    assign gshare_ghr_o         = ghr;
    assign gshare_ghr_update_o  = ghr_d4;
    wire   pred_taken           = pht_reg[1];
    assign pred_taken_o         = pred_taken;

    // Block RAM
    integer i;
    initial begin
        for (i = 0; i < PHT_SIZE; i = i + 1) begin
            pht[i] = 2'b01;
        end
    end
    always @(posedge clk) begin
        // 读
        pht_reg         <= pht[pht_index_i];
        pht_update_old  <= pht[update_pht_index_i];

        // 写
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

    // GHR - 流水线延迟
    reg pred_taken_r;
    always@(posedge clk) begin: gshare_ghr_ctrl
        if(!rst) begin
            ghr_d1  <= 0;
            ghr_d2  <= 0;
            ghr_d3  <= 0;
            ghr_d4  <= 0;
            pred_taken_r <= 0;
        end
        else if (!pipe_hold) begin
            ghr_d1  <= ghr;
            ghr_d2  <= ghr_d1;
            ghr_d3  <= ghr_d2;
            ghr_d4  <= ghr_d3;
            pred_taken_r <= pred_taken;
        end
    end

    always@(posedge clk) begin: gshare_update_ctrl
        if(!rst) begin
            pht_update_en_r        <= 0;
            actual_taken_update_r  <= 0;
            pht_index_update_r     <= 0;
        end
        else begin
            pht_update_en_r         <= update_en_i;
            actual_taken_update_r   <= actual_taken_i;
            pht_index_update_r      <= update_pht_index_i;
        end
    end
    
    // GHR
    always @(posedge clk) begin
        if (!rst) begin
            ghr     <= 0;
        end
        else begin
            if      (update_en_i)       ghr <= {ghr_d4[BHR_WIDTH - 2:0], actual_taken_i};    // 预测错误回退GHR
            else if (prev_b)            ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken_r};         // 预测投机更新GHR
        end
    end
endmodule