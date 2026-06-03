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
    output reg [31:0]   slot0_pc_o,
    output reg [31:0]   slot1_pc_o,

    // from bpu
    input      [31:0]   pred_pc,
    input               pred_taken
);
    wire pc_hold_en = (hazard_en | dcache_stall);

    // 为冲刷 / 异常留的口
    // 发生冲刷 / 异常时: 重新回到取 s0
    reg [31:0] pc_s0_sel, pc_s1_sel;
    always_comb begin
        if (wb_ecall | wb_mret) begin
            pc_s0_sel = ecall_mret_addr;
            pc_s1_sel = ecall_mret_addr + 32'd4;
        end
        else if (pred_flush) begin
            pc_s0_sel = pred_flush_pc;
            pc_s1_sel = pred_flush_pc + 32'd4;
        end
        else if (pred_taken) begin
            pc_s0_sel = pred_pc;
            pc_s1_sel = pred_pc + 32'd4;
        end
        else begin
            pc_s0_sel = slot0_pc_o + 32'd8;
            pc_s1_sel = slot1_pc_o + 32'd8;
        end
    end

    always_ff @(posedge clk) begin
        if(!rst) begin
            slot0_pc_o <= 32'h8000_0000;
            slot1_pc_o <= 32'h8000_0004;
        end
        else if (pc_hold_en) begin
            // ...
        end
        else begin
            slot0_pc_o <= pc_s0_sel;
            slot1_pc_o <= pc_s1_sel;
        end
    end
endmodule