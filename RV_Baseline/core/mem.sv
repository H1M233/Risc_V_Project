`include "rv32I.svh"
`include "alu_def.svh"

module mem(
    input  logic            clk                     ,
    input  logic            rst                     ,
    input  logic            pipe_hold               ,

    // from dcache
    input  logic            DCACHE_ack              ,
    input  logic [31:0]     DCACHE_rdata            ,

    // from ex_mem
    input  logic [31:0]     pc_i                    ,
    input  logic            valid_i                 ,
    input  MEM_data_t       MEM_data_pkg_i          ,
    input  RF_data_t        RF_data_pkg_i           ,
    input  CSR_data_t       CSR_data_pkg_i          ,

    // to mem_wb & forwarding
    output logic [31:0]     pc_o                    ,
    output logic            valid_o                 ,
    output RF_data_t        RF_data_pkg_o           ,
    output CSR_data_t       CSR_data_pkg_o          
);  
    RF_data_t RF_pkg_i;
    RF_data_t RF_pkg_o;
    MEM_data_t MEM_pkg_i;
    MEM_data_t MEM_pkg_o;

    // mem1
    always_comb begin
        RF_pkg_i          = RF_data_pkg_i;
        RF_pkg_i.regs_wen = (MEM_data_pkg_i.req_load) ? 1'b0 : RF_data_pkg_i.regs_wen;
        MEM_pkg_i         = MEM_data_pkg_i;
    end

    // mem1_mem2
    always_ff @(posedge clk) begin
        if (rst) begin
            pc_o                <= 0;
            valid_o             <= 0;
            RF_pkg_o            <= 0;
            MEM_pkg_o           <= 0;
            CSR_data_pkg_o      <= 0;
        end else if (pipe_hold) begin
            // ...
        end else begin
            pc_o                <= pc_i;
            valid_o             <= valid_i;
            RF_pkg_o            <= RF_pkg_i;
            MEM_pkg_o           <= MEM_pkg_i;
            CSR_data_pkg_o      <= CSR_data_pkg_i;
        end
    end

    // mem2
    wire [31:0] dcache_rdata_load_shift = 
        load_shift(
            DCACHE_rdata,
            MEM_pkg_o.load_mask,
            MEM_pkg_o.load_addr_low,
            MEM_pkg_o.load_is_signed
        );

    always_comb begin
        RF_data_pkg_o.rd_addr  = RF_pkg_o.rd_addr;
        RF_data_pkg_o.rd_data  = (MEM_pkg_o.req_load) ? dcache_rdata_load_shift : RF_pkg_o.rd_data;
        RF_data_pkg_o.regs_wen = (MEM_pkg_o.req_load & DCACHE_ack) | RF_pkg_o.regs_wen;
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
