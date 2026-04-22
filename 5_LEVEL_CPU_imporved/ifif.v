`include "rv32I.vh"

module ifif(
    // from IROM
    input      [31:0]   inst_i,         // 从rom取出的指令内容

    // from pc
    input      [31:0]   pc_addr_i,      // 当前指令地址

    // to if_id & bpu
    output reg [31:0]   inst_o,         // 传递指令内容
    output reg [31:0]   pc_addr_o,      // 传递指令地址

    // from bpu
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,

    // to if_id
    output  reg         pred_taken_o,
    output  reg [31:0]  pred_pc_o
);
    always @(*) begin
        pc_addr_o   = pc_addr_i;        // 将输入的指令地址传递给输出
        inst_o      = inst_i;           // 将输入的指令内容传递给输出
        pred_taken_o= pred_taken_i;
        pred_pc_o   = pred_pc_i;
    end
endmodule


