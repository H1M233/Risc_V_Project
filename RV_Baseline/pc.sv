`include "rv32I.vh"

module pc(
    input  logic        clk,
    input  logic        rst,
    input  logic        pipe_hold,

    // from ex
    input  logic        pred_flush,
    input  logic [31:0] pred_flush_pc,

    // from csr_regs
    input  logic        trap_en,
    input  logic [31:0] trap_pc,

    // from bpu
    input  logic [31:0] pred_pc,
    input  logic        pred_taken,

    // to if
    output logic [31:0] pc_o
);
    // 为冲刷 / 异常留的口
    reg [31:0] pc_sel;
    always_comb begin
        if (trap_en) begin
            pc_sel = trap_pc;
        end
        else if (pred_flush) begin
            pc_sel = pred_flush_pc;
        end
        else if (pred_taken) begin
            pc_sel = pred_pc;
        end
        else begin
            pc_sel = pc_o + 32'd4;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            pc_o <= 32'h8000_0000;
        end
        else if (pipe_hold) begin
            // ...
        end
        else begin
            pc_o <= pc_sel;
        end
    end
endmodule