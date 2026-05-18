`include "rv32I.vh"

module pc(
    input               clk,
    input               rst,

    // from hazard
    input               hazard_en,

    // from ex
    input               pred_flush,
    input      [31:0]   pred_flush_pc,
    input               dcache_stall,

    // from wb
    input               wb_ecall,
    input               wb_mret,

    // from csr_regs
    input      [31:0]   ecall_mret_addr,

    // to if
    (* max_fanout = 30 *)
    output reg [31:0]   pc_addr_o,

    // from bpu
    input      [31:0]   pred_pc,
    input               pred_taken
);
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'h8000_0000;
        end
        else if(wb_ecall) begin
            pc_addr_o <= ecall_mret_addr;   // ecall 处理，跳转到 ecall 处理函数
        end
        else if(wb_mret) begin
            pc_addr_o <= ecall_mret_addr;   // mret 处理，跳转到 mret 处理函数
        end
        else if(pred_flush) begin
            pc_addr_o <= pred_flush_pc;
        end
        else if(hazard_en) begin
            pc_addr_o <= pc_addr_o;
        end
        else if(pred_taken) begin
            pc_addr_o <= pred_pc;
        end
        else if (dcache_stall) begin
            pc_addr_o <= pc_addr_o;
        end
        else begin
            pc_addr_o <= pc_addr_o + 4;
        end
    end
endmodule