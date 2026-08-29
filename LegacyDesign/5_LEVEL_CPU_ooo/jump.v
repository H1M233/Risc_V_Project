`include "rv32I.vh"
module jump(
    // from ex
    input      [31:0]   jump_addr_i,    // 来自控制单元的跳转地址输入
    input               jump_en_i,      // 来自控制单元的跳转使能信号

    // to pc
    output reg [31:0]   jump_addr_o,    // 传递给PC模块的跳转地址输入

    // to if_id, id_ex, pc
    output reg          jump_en_o       // 传递给各模块的跳转使能信号
);
    always@(*) begin
        jump_en_o   = jump_en_i;
        jump_addr_o = (jump_en_i) ? jump_addr_i : 32'b0;
    end
endmodule