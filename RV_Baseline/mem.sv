`include "rv32I.vh"
`include "alu_def.svh"

module mem(
    input  logic clk,
    input  logic rst,
    input  logic pipe_flush,
    input  logic pipe_hold,

    // from dcache
    input  logic         dcache_ack,
    input  logic [31:0]  dcache_rdata,

    // from ex_mem
    input  ex_mem_data_t data_packaged_i,
    input  ex_csr_data_t csr_data_packaged_i,

    // to mem_wb & forwarding
    output mem_wb_data_t data_packaged_o,
    output ex_csr_data_t csr_data_packaged_o
);  
    ex_mem_data_t mpkg_i;
    ex_mem_data_t mpkg_o;

    // mem1
    always_comb begin
        mpkg_i          = data_packaged_i;
        mpkg_i.regs_wen = (data_packaged_i.req_load) ? 1'b0 : data_packaged_i.regs_wen;
    end

    // mem1_mem2
    always_ff @(posedge clk) begin
        if (!rst) begin
            mpkg_o              <= 0;
            csr_data_packaged_o <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            mpkg_o              <= 0;
            csr_data_packaged_o <= 0;
        end
        else begin
            mpkg_o              <= mpkg_i;
            csr_data_packaged_o <= csr_data_packaged_i;
        end
    end

    // mem2
    wire [31:0] dcache_rdata_load_shift = 
        load_shift(
            dcache_rdata,
            mpkg_o.load_mask,
            mpkg_o.load_addr_low,
            mpkg_o.load_is_signed
        );
    always_comb begin
        data_packaged_o          = mpkg_o;
        data_packaged_o.rd_addr  = mpkg_o.rd_addr;
        data_packaged_o.rd_data  = (mpkg_o.req_load) ? dcache_rdata_load_shift : mpkg_o.rd_data;
        data_packaged_o.regs_wen = (mpkg_o.req_load & dcache_ack) | mpkg_o.regs_wen;
    end
        
    // 函数：
    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  mask;
        input [1:0]  addr_low;
        input        is_signed;
        reg   [31:0] shifted_word;
        reg   [7:0]  byte_val;
        reg   [15:0] half_val;
        begin 
            shifted_word = word >> {addr_low, 3'b000};
            byte_val  = shifted_word[7:0];
            half_val  = shifted_word[15:0];
            case (mask)
                2'b01:  // byte
                    load_shift = {{24{byte_val[7] & is_signed}}, byte_val};
                2'b10:  // half
                    load_shift = {{16{half_val[15] & is_signed}}, half_val};
                2'b11:  // word
                    load_shift = shifted_word;
                default: load_shift = 32'b0;
            endcase
        end
    endfunction
endmodule
