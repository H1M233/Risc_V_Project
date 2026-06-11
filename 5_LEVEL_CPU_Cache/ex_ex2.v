`include "rv32I.vh"
`include "alu.vh"

module ex_ex2(
    input               clk,
    input               rst,
    input               dcache_stall,
    input               ecall_flush,
    input               mret_flush,

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
    input               dcache_write_dram_i,
    input      [3:0]    dcache_we_i,

    input      [`OP_INST_NUM - 1:0] inst_packaged_i,
    input      [31:0]   mdu_rs1_i,
    input      [31:0]   mdu_rs2_i,
    input signed [33:0] div_remainder_i,
    input      [31:0]   div_quotient_i,
    input      [31:0]   div_divisor_abs_i,

    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,
    output reg          mem_req_load_o,
    output reg          ecall_o,
    output reg          mret_o,
    output reg [1:0]    load_mask_o,
    output reg [1:0]    load_addr_low_o,
    output reg          load_is_signed_o,
    output reg [31:0]   ecall_inst_o,

    output reg          dcache_req_load_o,
    output reg          dcache_req_store_o,
    output reg [31:0]   dcache_addr_o,
    output reg [31:0]   dcache_wdata_o,
    output reg          dcache_write_dram_o,
    output reg [3:0]    dcache_we_o,

    output reg [`OP_INST_NUM - 1:0] inst_packaged_o,
    output reg [31:0]   mdu_rs1_o,
    output reg [31:0]   mdu_rs2_o,
    output reg signed [33:0] div_remainder_o,
    output reg [31:0]   div_quotient_o,
    output reg [31:0]   div_divisor_abs_o
);
    wire flush = ecall_flush | mret_flush;

    always @(posedge clk) begin
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
            dcache_req_load_o   <= 1'b0;
            dcache_req_store_o  <= 1'b0;
            dcache_addr_o       <= 32'b0;
            dcache_wdata_o      <= 32'b0;
            dcache_write_dram_o <= 1'b0;
            dcache_we_o         <= 4'b0;
            inst_packaged_o     <= {`OP_INST_NUM{1'b0}};
            mdu_rs1_o           <= 32'b0;
            mdu_rs2_o           <= 32'b0;
            div_remainder_o     <= 34'sd0;
            div_quotient_o      <= 32'b0;
            div_divisor_abs_o   <= 32'b0;
        end
        else if (flush) begin
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
            dcache_req_load_o   <= 1'b0;
            dcache_req_store_o  <= 1'b0;
            dcache_addr_o       <= 32'b0;
            dcache_wdata_o      <= 32'b0;
            dcache_write_dram_o <= 1'b0;
            dcache_we_o         <= 4'b0;
            inst_packaged_o     <= {`OP_INST_NUM{1'b0}};
            mdu_rs1_o           <= 32'b0;
            mdu_rs2_o           <= 32'b0;
            div_remainder_o     <= 34'sd0;
            div_quotient_o      <= 32'b0;
            div_divisor_abs_o   <= 32'b0;
        end
        else if (dcache_stall) begin
            // hold
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
            dcache_write_dram_o <= dcache_write_dram_i;
            dcache_we_o         <= dcache_we_i;
            inst_packaged_o     <= inst_packaged_i;
            mdu_rs1_o           <= mdu_rs1_i;
            mdu_rs2_o           <= mdu_rs2_i;
            div_remainder_o     <= div_remainder_i;
            div_quotient_o      <= div_quotient_i;
            div_divisor_abs_o   <= div_divisor_abs_i;
        end
    end
endmodule
