`include "rv32I.vh"

module ex_mem(
    input               clk,
    input               rst,
    input               pipe_hold,
    input               pipe_flush,

    // from ex
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               mem_req_load_i,
    input               ecall_i,
    input               mret_i,
    input      [1:0]    load_mask_i,
    input      [1:0]    load_addr_low_i,
    input               load_is_signed_i,
    input      [31:0]   ecall_inst_i,
    input               dcache_req_load_i,
    input               dcache_req_store_i,
    input      [31:0]   dcache_addr_i,
    input      [31:0]   dcache_wdata_i,
    input      [3:0]    dcache_we_i,
    input               dcache_write_dram_i,
    
    // to mem
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    (* max_fanout = 30 *)
    output reg          regs_wen_o,
    output reg          mem_req_load_o,
    output reg          ecall_o,
    output reg          mret_o,
    output reg [1:0]    load_mask_o,
    output reg [1:0]    load_addr_low_o,
    output reg          load_is_signed_o,
    output reg [31:0]   ecall_inst_o,

    // to dcache
    output  reg         dcache_req_load_o,
    output  reg         dcache_req_store_o,
    output  reg [31:0]  dcache_addr_o,
    output  reg [31:0]  dcache_wdata_o,
    output  reg [3:0]   dcache_we_o,
    output  reg         dcache_write_dram_o
);
    always@(posedge clk) begin
        if (!rst) begin
            rd_addr_o           <= 5'b0;
            rd_data_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            mem_req_load_o      <= 1'b0;
            ecall_o             <= 1'b0;
            mret_o              <= 1'b0;
            load_mask_o         <= 2'b0;
            load_addr_low_o     <= 2'b0;
            load_is_signed_o    <= 1'b0;
            ecall_inst_o        <= 32'b0;

            dcache_req_load_o   <= 0;
            dcache_req_store_o  <= 0;
            dcache_addr_o       <= 0;
            dcache_wdata_o      <= 0;
            dcache_we_o         <= 0;
            dcache_write_dram_o <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            rd_addr_o           <= 5'b0;
            rd_data_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            mem_req_load_o      <= 1'b0;
            ecall_o             <= 1'b0;    // ecall_flush 信号来自 wb，当发生 ecall 时，清空 ex_mem 寄存器，防止错误执行
            mret_o              <= 1'b0;    // mret_flush 信号来自 wb，当发生 mret 时，清空 ex_mem 寄存器，防止错误执行
            load_mask_o         <= 2'b0;
            load_addr_low_o     <= 2'b0;
            load_is_signed_o    <= 1'b0;
            ecall_inst_o        <= 32'b0;

            dcache_req_load_o   <= 0;
            dcache_req_store_o  <= 0;
            dcache_addr_o       <= 0;
            dcache_wdata_o      <= 0;
            dcache_we_o         <= 0;
            dcache_write_dram_o <= 0;
        end
        else begin
            rd_addr_o           <= rd_addr_i;
            rd_data_o           <= rd_data_i;
            regs_wen_o          <= regs_wen_i;
            mem_req_load_o      <= mem_req_load_i;
            ecall_o             <= ecall_i;
            mret_o              <= mret_i;
            load_mask_o         <= load_mask_i;
            load_addr_low_o     <= load_addr_low_i;
            load_is_signed_o    <= load_is_signed_i;
            ecall_inst_o        <= ecall_inst_i;

            dcache_req_load_o   <= dcache_req_load_i;
            dcache_req_store_o  <= dcache_req_store_i;
            dcache_addr_o       <= dcache_addr_i;
            dcache_wdata_o      <= dcache_wdata_i;
            dcache_we_o         <= dcache_we_i;
            dcache_write_dram_o <= dcache_write_dram_i;
        end
    end
endmodule