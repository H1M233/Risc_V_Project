`include "rv32I.svh"
`include "alu_def.svh"

module wb(
    // from mem_wb
    input  logic [31:0]     pc_i                ,
    input  logic            valid_i             ,
    input  RF_data_t        data_pkg_i          ,
    input  CSR_data_t       CSR_data_pkg_i      ,

    // to regs
    output RF_data_t        data_pkg_o          ,

    // to csr_regs
    output logic [31:0]     pc_o                ,
    output CSR_data_t       CSR_data_pkg_o      
);
    always_comb begin
        pc_o            = pc_i;
        CSR_data_pkg_o  = CSR_data_pkg_i;
        data_pkg_o      = data_pkg_i;

        data_pkg_o.regs_wen = data_pkg_o.regs_wen & valid_i;
    end
endmodule