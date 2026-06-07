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

    // from id
    input               stall,

    // from ex
    input               ctrl_stall,

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
    wire pc_hold_en = (hazard_en | dcache_stall);
    wire div_stall = (!ctrl_stall)? stall : 1'b0;
    // 为冲刷 / 异常留的口
    reg [31:0] pc_sel;
    always @(*) begin
        if (wb_ecall | wb_mret) begin
            pc_sel = ecall_mret_addr;
        end
        else if (pred_flush) begin
            pc_sel = pred_flush_pc;
        end
        else if (pred_taken) begin
            pc_sel = pred_pc;
        end
        else begin
            pc_sel = pc_addr_o + 32'd4;
        end
    end

    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'h8000_0000;
        end
        else if (pc_hold_en) begin
            // ...
        end
        else if (div_stall) begin
            // ...
        end
        else begin
            pc_addr_o <= pc_sel;
        end
    end
endmodule