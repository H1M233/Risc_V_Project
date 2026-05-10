`include "rv32I.vh"

module if1(
    // from pc
    input      [31:0]   pc_i,           // 从 pc 接受的指令地址

    // to if1_if2 & bpu & icache
    output reg [31:0]   pc_o            // 传递指令地址
);
    always @(*) begin
        pc_o   = pc_i;                  // 将输入的指令地址传递给输出
    end
endmodule