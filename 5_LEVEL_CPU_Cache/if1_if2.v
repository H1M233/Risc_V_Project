`include "rv32I.vh"

module if1_if2(
    input               clk,
    input               rst,

    // ctrl
    input               pipe_hold,
    input               pipe_flush,

    // from if1
    input      [31:0]   pc_i,

    // from wb
    input               ecall_flush,
    input               mret_flush,
    // to if2
    output reg          if2_valid_o,
    output reg [31:0]   pc_o
);
    wire if1_if2_flush_en = (ecall_flush | mret_flush);

    always @(posedge clk) begin
        if (!rst) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'h0;
        end
        else if(if1_if2_flush_en) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'h0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'b0;
        end
        else begin
            if2_valid_o <= 1'b1;
            pc_o        <= pc_i;
        end
    end
endmodule