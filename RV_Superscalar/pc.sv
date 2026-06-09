`include "rv32I.vh"

module pc(
    input               clk,
    input               rst,

    input               pipe_hold,
    input               dual_stall,

    // from ex
    input               pred_flush,
    input      [31:0]   pred_flush_pc,

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
    // 为冲刷 / 异常留的口
    // 发生冲刷 / 异常时: 重新回到取 s0
    logic [31:0] pc_s0_sel, pc_s1_sel;
    wire  pipe_flush = wb_ecall | wb_mret | pred_flush | pred_taken;
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
            pc_s0_sel = 32'b0;
            pc_s1_sel = 32'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_pc_o <= 32'h8000_0000;
            slot1_pc_o <= 32'h8000_0004;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            slot0_pc_o <= pc_s0_sel;
            slot1_pc_o <= pc_s1_sel;
        end
        else begin
            slot0_pc_o <= slot0_pc_o + 32'd8;
            slot1_pc_o <= slot1_pc_o + 32'd8;
        end
    end
endmodule