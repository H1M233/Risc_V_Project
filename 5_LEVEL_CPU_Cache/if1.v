`include "rv32I.vh"

module if1(
    // from pc
    input      [31:0]   pc_i,           // 从 pc 接受的指令地址

    input               pred_flush,

    // to if1_if2 & bpu & icache
    output reg [31:0]   pc_o           // 传递指令地址
);
    always @(*) begin
        pc_o   = (pred_flush) ? 32'b0 : pc_i;
    end
endmodule