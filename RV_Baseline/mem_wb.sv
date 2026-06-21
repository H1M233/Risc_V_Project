`include "rv32I.svh"

module mem_wb(
    input  logic clk,
    input  logic rst,
    input  logic pipe_flush,

    // from mem
    input  mem_wb_data_t data_packaged_i,
    input  ex_csr_data_t csr_data_packaged_i,

    // to wb
    output logic [5:0]   rd_addr_o,
    output logic [31:0]  rd_data_o,
    output logic         regs_wen_o,
    output ex_csr_data_t csr_data_packaged_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            rd_data_o           <= 0;
            rd_addr_o           <= 0;
            regs_wen_o          <= 0;
            csr_data_packaged_o <= 0;
        end
        else if (pipe_flush) begin
            rd_data_o           <= 0;
            rd_addr_o           <= 0;
            regs_wen_o          <= 0;
            csr_data_packaged_o <= 0;
        end
        else begin
            rd_data_o           <= data_packaged_i.rd_data;
            rd_addr_o           <= data_packaged_i.rd_addr;
            regs_wen_o          <= data_packaged_i.regs_wen;
            csr_data_packaged_o <= csr_data_packaged_i;
        end
    end
endmodule
