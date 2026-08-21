`include "rv32I.svh"

module gshare #(
    parameter BHR_WIDTH     = 10,
    parameter PHT_IDX_WIDTH = 12,
    parameter PHT_SIZE      = 2 ** PHT_IDX_WIDTH
) (
    input  logic                        clk,
    input  logic                        rst,
    
    // 查询
    input  logic [BHR_WIDTH - 1:0]      pht_index_i,
    input  logic                        prev_b,
    output logic                        pred_taken_o,
    output logic [BHR_WIDTH - 1:0]      gshare_ghr_o,

    // 更新
    input  logic                        update_en_i,
    input  logic [BHR_WIDTH - 1:0]      update_pht_index_i,
    input  logic [BHR_WIDTH - 1:0]      update_ghr_i,
    input  logic                        actual_taken_i
);
    reg [BHR_WIDTH - 1:0]   ghr;                    // GHR全局历史寄存器：用于投机更新
    (* ram_style = "block" *) 
    reg [1:0]               pht [0:PHT_SIZE - 1];   // PHT 2 位饱和计数器

    // 初始化
    initial begin
        for (int i = 0; i < PHT_SIZE; i++) pht[i] = 2'b01;
    end

    // 查询
    logic                   pht_update_en_r;
    logic [1:0]             pht_reg,
                            pht_update_old,
                            pht_update_new,
                            actual_taken_r;
    logic [BHR_WIDTH - 1:0] pht_index_update_r,
                            update_ghr_r;

    wire pred_taken = pht_reg[1];

    assign gshare_ghr_o = ghr;
    assign pred_taken_o = pred_taken;

    // Block RAM
    always_ff @(posedge clk) begin
        // 查询
        pht_reg         <= pht[pht_index_i];
        pht_update_old  <= pht[update_pht_index_i];

        // 更新
        if (pht_update_en_r) begin
            pht[pht_index_update_r] <= pht_update_new;
        end
    end
    
    // 更新
    always_comb begin
        case(pht_update_old)
            2'b00:      pht_update_new = (actual_taken_r) ? 2'b01 : 2'b00;
            2'b01:      pht_update_new = (actual_taken_r) ? 2'b10 : 2'b00;
            2'b10:      pht_update_new = (actual_taken_r) ? 2'b11 : 2'b01;
            2'b11:      pht_update_new = (actual_taken_r) ? 2'b11 : 2'b10;
            default:    pht_update_new = 2'b01;
        endcase
    end

    // 流水线
    logic pred_taken_r;
    always_ff @(posedge clk) begin: gshare_update_ctrl
        if (rst) begin
            pht_update_en_r         <= 0;
            actual_taken_r          <= 0;
            pht_index_update_r      <= 0;
            pred_taken_r            <= 0;
            update_ghr_r            <= 0;
        end else begin
            pht_update_en_r         <= update_en_i;
            actual_taken_r          <= actual_taken_i;
            pht_index_update_r      <= update_pht_index_i;
            pred_taken_r            <= pred_taken;
            update_ghr_r            <= update_ghr_i;
        end
    end
    
    // GHR
    always_ff @(posedge clk) begin
        if (rst) begin
            ghr <= 0;
        end else begin
            if (update_en_i) 
                ghr <= {update_ghr_i[BHR_WIDTH - 2:0], actual_taken_i};
            else if (prev_b) 
                ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken_r};
        end
    end
endmodule