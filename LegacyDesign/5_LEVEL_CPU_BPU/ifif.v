`include "rv32I.vh"

module ifif(
    // from IROM
    input      [31:0]   inst_i,         // 从rom取出的指令内容

    // from pc
    input      [31:0]   pc_addr_i,      // 当前指令地址

    // to if_id & bpu
    output reg [31:0]   inst_o,         // 传递指令内容
    output reg [31:0]   pc_addr_o       // 传递指令地址
);
    always @(*) begin
        pc_addr_o   = pc_addr_i;        // 将输入的指令地址传递给输出
        inst_o      = inst_i;           // 将输入的指令内容传递给输出
    end
endmodule


