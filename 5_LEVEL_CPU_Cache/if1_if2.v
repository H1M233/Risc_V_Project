`include "rv32I.vh"

module if1_if2(
    input               clk,
    input               rst,

    // ctrl
    input               pipe_hold,
    input               pipe_flush,

    // from if1
    input      [31:0]   pc_i,

    // to if2
    output reg [31:0]   pc_o
);
    always @(posedge clk) begin
        if (!rst) begin
            pc_o <= 32'h0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            pc_o <= 32'b0;
        end
        else begin
            pc_o <= pc_i;
        end
    end
endmodule