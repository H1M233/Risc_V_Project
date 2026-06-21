`include "rv32I.svh"

module ex_mem(
    input  logic            clk,
    input  logic            rst,
    input  logic            pipe_hold,
    input  logic            pipe_flush,

    // from ex
    input  ex_mem_data_t    mem_data_packaged_i,
    input  ex_lsu_data_t    dcache_data_packaged_i,
    input  ex_csr_data_t    csr_data_packaged_i,
    
    // to mem
    output ex_mem_data_t    mem_data_packaged_o,
    output ex_csr_data_t    csr_data_packaged_o,

    // to dcache
    output ex_lsu_data_t    dcache_data_packaged_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            mem_data_packaged_o     <= 0;
            dcache_data_packaged_o  <= 0;
            csr_data_packaged_o     <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            mem_data_packaged_o     <= 0;
            dcache_data_packaged_o  <= 0;
            csr_data_packaged_o     <= 0;
        end
        else begin
            mem_data_packaged_o     <= mem_data_packaged_i;
            dcache_data_packaged_o  <= dcache_data_packaged_i;
            csr_data_packaged_o     <= csr_data_packaged_i;
        end
    end
endmodule
