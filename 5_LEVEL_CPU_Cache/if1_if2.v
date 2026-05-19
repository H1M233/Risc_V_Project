`include "rv32I.vh"

module if1_if2(
    input               clk,
    input               rst,

    input               pred_taken,
    input               pred_flush,
    input               pipe_hold,

    // from if1
    input      [31:0]   pc_i,

    // form wb
    input               ecall_flush,
    input               mret_flush,

    // to if2
    output reg          if2_valid_o,
    output reg [31:0]   pc_o
);
    wire if1_if2_hold_en = pipe_hold;
    wire if1_if2_flush_en = (pred_taken | pred_flush | ecall_flush | mret_flush);

    always @(posedge clk) begin
        if (!rst) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'h0;
        end
        else if (if1_if2_hold_en) begin
            // ...
        end
        else if (if1_if2_flush_en) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'b0;
        end
        else begin
            if2_valid_o <= 1'b1;
            pc_o        <= pc_i;
        end
    end
endmodule