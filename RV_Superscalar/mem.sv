`include "rv32I.vh"
`include "alu.vh"

module mem(
    input               clk,
    input               rst,

    input               forward_flush,

    // from dcache
    input               dcache_ack,
    input      [31:0]   dcache_rdata,
    input               dcache_stall,

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
    input      [31:0]   ecall_inst_i,
    
    // to hazard & wb
    output              mem1_is_load_o,
    output reg          mem2_is_load_o,

    // to forwarding
    output     [4:0]    mem1_rd_addr_o,
    output     [31:0]   mem1_rd_data_o,
    output              mem1_regs_wen_o,

    // to mem_wb & forwarding
    (* max_fanout = 20 *) output reg [4:0]    mem2_rd_addr_o,
    (* max_fanout = 20 *) output reg [31:0]   mem2_rd_data_o,
    (* max_fanout = 20 *) output reg          mem2_regs_wen_o,
    output reg          ecall_o,
    output reg          mret_o,
    output reg [31:0]   ecall_inst_o
);  
    logic        mem1_mem2_req_load_i;
    logic [4:0]  mem1_mem2_rd_addr_i;
    logic [31:0] mem1_mem2_rd_data_i;
    logic        mem1_mem2_regs_wen_i;
    logic        mem1_mem2_ecall_i;
    logic        mem1_mem2_mret_i;

    reg        mem2_req_load_i;
    reg [4:0]  mem2_rd_addr_i;
    reg [31:0] mem2_rd_data_i;
    reg        mem2_regs_wen_i;
    reg [1:0]  mem2_load_mask_i;
    reg [1:0]  mem2_load_addr_low_i;
    reg        mem2_load_is_signed_i;

    assign mem1_is_load_o   = mem1_mem2_req_load_i;
    assign mem1_rd_addr_o   = mem1_mem2_rd_addr_i;
    assign mem1_rd_data_o   = mem1_mem2_rd_data_i;
    assign mem1_regs_wen_o  = mem1_mem2_regs_wen_i;

    // mem1
    always_comb begin
        mem1_mem2_req_load_i  = mem_req_load_i;
        mem1_mem2_rd_addr_i   = rd_addr_i;
        mem1_mem2_rd_data_i   = rd_data_i;
        mem1_mem2_regs_wen_i  = (mem_req_load_i | forward_flush) ? 1'b0 : regs_wen;
        mem1_mem2_ecall_i     = ecall_i & !forward_flush;
        mem1_mem2_mret_i      = mret_i & !forward_flush;
    end

    // mem1_mem2
    always_ff @(posedge clk) begin
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
            ecall_inst_o            <= 0;
        end
        else if (dcache_stall) begin
            // ...
        end
        else begin
            mem2_req_load_i         <= mem1_mem2_req_load_i;
            mem2_rd_addr_i          <= mem1_mem2_rd_addr_i;
            mem2_rd_data_i          <= mem1_mem2_rd_data_i;
            mem2_regs_wen_i         <= mem1_mem2_regs_wen_i;
            mem2_load_mask_i        <= load_mask_i;
            mem2_load_addr_low_i    <= load_addr_low_i;
            mem2_load_is_signed_i   <= load_is_signed_i;
            ecall_o                 <= mem1_mem2_ecall_i;
            mret_o                  <= mem1_mem2_mret_i;
            ecall_inst_o            <= ecall_inst_i;
        end
    end

    // mem2
    wire [31:0] dcache_rdata_load_shift = load_shift(dcache_rdata, mem2_load_mask_i, mem2_load_addr_low_i, mem2_load_is_signed_i);
    always_ff @(*) begin
        mem2_rd_addr_o   = mem2_rd_addr_i;
        mem2_rd_data_o   = (mem2_req_load_i) ? dcache_rdata_load_shift : mem2_rd_data_i;
        mem2_regs_wen_o  = (mem2_req_load_i & dcache_ack) | mem2_regs_wen_i;
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
