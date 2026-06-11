`include "rv32I.vh"
`include "alu.vh"

module wb(
    // from mem_wb
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               ecall_i,
    input               mret_i,
    input      [31:0]   ecall_inst_i,

    // to regs
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,

    // to pc
    output reg          ecall_o,
    output reg          mret_o,

    output reg [31:0]   ecall_inst_o
);

    always_comb begin
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = regs_wen_i;
        rd_data_o   = rd_data_i;
        ecall_o     = ecall_i;
        mret_o      = mret_i;
        ecall_inst_o = ecall_inst_i;
    end
endmodule