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
    wire pc_hold_en       = (hazard_en | dcache_stall);
    wire flush_or_trap_en = (wb_ecall | wb_mret | pred_flush); // ecall 处理，跳转到 ecall 处理函数 / mret 处理，跳转到 mret 处理函数
    wire [31:0] flush_or_trap_pc = (wb_ecall | wb_mret) ? ecall_mret_addr : pred_flush_pc;
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'h8000_0000;
        end
        else if(flush_or_trap_en) begin        // ecall 处理，跳转到 ecall 处理函数 / mret 处理，跳转到 mret 处理函数
            pc_addr_o <= flush_or_trap_pc;
        end 
        else if(pred_taken) begin
            pc_addr_o <= pred_pc;
        end
        else if(pc_hold_en) begin
            // ...
        end
        else begin
            pc_addr_o <= pc_addr_o + 4;
        end
    end
endmodule