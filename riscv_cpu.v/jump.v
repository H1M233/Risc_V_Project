`include "rv32I.vh"
module jump(
    input jump_en_i,              // 来自控制单元的跳转使能信号
    input [31:0] jump_addr_i,   // 来自控制单元的跳转地址输入

    output reg jump_en_o,              // 传递给PC模块的跳转使能信号
    output reg [31:0] jump_addr_o   // 传递给PC模块的跳转地址输入
);
    always@(*) begin
        jump_en_o = 1'b0;
        jump_addr_o = 32'b0;
        if(jump_en_i) begin
            jump_en_o = 1'b1;
            jump_addr_o = jump_addr_i;
        end
    end
endmodule