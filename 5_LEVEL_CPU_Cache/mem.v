`include "rv32I.vh"
`include "alu.vh"

module mem(
    input               clk,
    input               rst,
    input               dcache_ack,
    input      [31:0]   dcache_rdata,

    // from ex_mem
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input               mem_req_load_i,
    input               ecall_i,
    input               mret_i,
    input      [1:0]    load_mask_i,
    input      [1:0]    load_addr_low_i,
    input               load_is_signed_i,
    
    // to hazard & wb
    output              mem1_is_load_o,
    output reg          mem2_is_load_o,

    // to forwarding
    output     [4:0]    mem1_rd_addr_o,
    output     [31:0]   mem1_rd_data_o,
    output              mem1_regs_wen_o,

    // to mem_wb & forwarding
    output reg [4:0]    mem2_rd_addr_o,
    output reg [31:0]   mem2_rd_data_o,
    output reg          mem2_regs_wen_o,
    output reg          ecall_o,
    output reg          mret_o
);  
    reg        mem1_req_load_o;
    reg [4:0]  mem1_rd_addr_oo;
    reg [31:0] mem1_rd_data_oo;
    reg        mem1_regs_wen_oo;

    reg        mem2_req_load_i;
    reg [4:0]  mem2_rd_addr_i;
    reg [31:0] mem2_rd_data_i;
    reg        mem2_regs_wen_i;
    reg [1:0]  mem2_load_mask_i;
    reg [1:0]  mem2_load_addr_low_i;
    reg        mem2_load_is_signed_i;

    assign mem1_is_load_o   = mem1_req_load_o;
    assign mem1_rd_addr_o   = mem1_rd_addr_oo;
    assign mem1_rd_data_o   = mem1_rd_data_oo;
    assign mem1_regs_wen_o  = mem1_regs_wen_oo;

    // mem1
    always@(*) begin
        mem1_req_load_o         = mem_req_load_i;
        mem1_rd_addr_oo         = rd_addr_i;
        mem1_rd_data_oo         = rd_data_i;
        mem1_regs_wen_oo        = (mem_req_load_i) ? 1'b0 : regs_wen;
    end

    // mem1_mem2
    always @(posedge clk) begin
        if (!rst) begin
            mem2_req_load_i         <= 0;
            mem2_rd_addr_i          <= 0;
            mem2_rd_data_i          <= 0;
            mem2_regs_wen_i         <= 0;
            mem2_load_mask_i        <= 0;
            mem2_load_addr_low_i    <= 0;
            mem2_load_is_signed_i   <= 0;
            ecall_o                 <= 0;
            mret_o                  <= 0;
        end
        else begin
            mem2_req_load_i         <= mem1_req_load_o;
            mem2_rd_addr_i          <= mem1_rd_addr_oo;
            mem2_rd_data_i          <= mem1_rd_data_oo;
            mem2_regs_wen_i         <= mem1_regs_wen_oo;
            mem2_load_mask_i        <= load_mask_i;
            mem2_load_addr_low_i    <= load_addr_low_i;
            mem2_load_is_signed_i   <= load_is_signed_i;
            ecall_o                 <= ecall_i;
            mret_o                  <= mret_i;
        end
    end

    // mem2
    wire [31:0] dcache_rdata_load_shift = load_shift(dcache_rdata, mem2_load_mask_i, mem2_load_addr_low_i, mem2_load_is_signed_i);
    always@(*) begin
        mem2_rd_addr_o   = mem2_rd_addr_i;
        mem2_rd_data_o   = (mem2_req_load_i) ? dcache_rdata_load_shift : mem2_rd_data_i;
        mem2_regs_wen_o  = dcache_ack | mem2_regs_wen_i;
        mem2_is_load_o   = mem2_req_load_i;
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
