`include "rv32I.vh"
`include "alu.vh"

module wb(
    // from mem_wb
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               ecall_i,
    input               mret_i,

    // to regs
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,

    // to pc
    output reg          ecall_o,
    output reg          mret_o
);
    assign rd_addr_o   = rd_addr_i;
    assign regs_wen_o  = regs_wen_i;
    assign rd_data_o   = rd_data_i;
    assign ecall_o     = ecall_i;
    assign mret_o      = mret_i;
endmodule