`include "rv32I.vh"

module if_id(
    input               clk,
    input               rst,

    // from D-cache stall
    input               dcache_stall,

    // from I-cache front stall
    input               icache_block,

    // from hazard
    input               hazard_en,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_addr_i,

    // from jump
    input               jump_en,

    // to id
    output reg [31:0]   inst_o,
    output reg [31:0]   pc_addr_o,
    output reg          valid_o,

    // from bpu
    input               pred_taken
);
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
            valid_o   <= 1'b0;
        end
        else if(dcache_stall) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
            valid_o   <= valid_o;
        end
        else if(hazard_en) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
            valid_o   <= valid_o;
        end
        else if(icache_block) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
            valid_o   <= valid_o;
        end
        else begin
            // 关键点：
            // jump_en / pred_taken 不再直接清 inst_o，避免 EX 分支比较结果扇出到 32 位 IF_ID.inst_o 寄存器。
            // 错误路径指令可以被写入 inst_o，但 valid_o=0，后级会把它当 NOP。
            pc_addr_o <= pc_addr_i;
            inst_o    <= inst_i;
            valid_o   <= ~(jump_en | pred_taken);
        end
    end
endmodule