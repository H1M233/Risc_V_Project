`include "rv32I.vh"

module if1_if2(
    input               clk,
    input               rst,

    // ctrl
    input               pipe_hold,
    input               pipe_flush,

    // from if1
    input      [31:0]   pc_i,

    // from id
    input               stall,

    // from ex
    input               ctrl_stall,

    // from wb
    input               ecall_flush,
    input               mret_flush,
    // to if2
    output reg [31:0]   pc_o
);
    wire if1_if2_flush_en = (ecall_flush | mret_flush);
    wire div_stall = (!ctrl_stall)? stall : 1'b0;
    always @(posedge clk) begin
        if (!rst) begin
            pc_o <= 32'h0;
        end
        else if(if1_if2_flush_en) begin
            pc_o        <= 32'h0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            pc_o <= 32'b0;
        end
        else if (div_stall) begin
            // ...
        end
        else begin
            pc_o <= pc_i;
        end
    end
endmodule