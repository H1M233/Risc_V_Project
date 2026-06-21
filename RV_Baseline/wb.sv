`include "rv32I.svh"
`include "alu_def.svh"

module wb(
    // from mem_wb
    input  logic [5:0]   rd_addr_i,
    input  logic [31:0]  rd_data_i,
    input  logic         regs_wen_i,
    input  ex_csr_data_t csr_data_packaged_i,

    // to regs
    output logic [5:0]   rd_addr_o,
    output logic [31:0]  rd_data_o,
    output logic         regs_wen_o,
    output ex_csr_data_t csr_data_packaged_o
);
    assign rd_addr_o   = rd_addr_i;
    assign regs_wen_o  = regs_wen_i;
    assign rd_data_o   = rd_data_i;

    assign csr_data_packaged_o = csr_data_packaged_i;
endmodule