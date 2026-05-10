`include "rv32I.vh"

module if1_if2(
    input               clk,
    input               rst,

    input               pipe_flush,
    input               pipe_hold,

    // from if1
    input      [31:0]   pc_i,

    // to if2
    output reg          if2_valid_o,
    output reg [31:0]   pc_o
);
    always @(posedge clk) begin
        if (!rst | pipe_flush) begin
            if2_valid_o <= 1'b0;
            pc_o        <= 32'h0;
        end
        else if (pipe_flush) begin
            // 预测跳转发生时，跳转指令位于 id 内，需要将 if1 & if2 内容全部冲刷
            // 预测错误跳转发生时，跳转指令位于 ex 内，需要将 if1 & if2 & id 内容全部冲刷
            if2_valid_o <= 1'b0;
            pc_o        <= 32'h0;
        end
        else if (!pipe_hold) begin
            if2_valid_o <= 1'b1;
            pc_o        <= pc_i;
        end
    end
endmodule