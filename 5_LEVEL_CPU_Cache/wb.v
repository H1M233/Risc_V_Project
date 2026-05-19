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
    output reg          mret_o,

    output reg          ecall_flush,
    output reg          mret_flush
);

    always@(*) begin
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = regs_wen_i;
        rd_data_o   = rd_data_i;
        ecall_o     = ecall_i;
        ecall_flush = ecall_i;  
        mret_o      = mret_i;
        mret_flush  = mret_i;
    end
endmodule