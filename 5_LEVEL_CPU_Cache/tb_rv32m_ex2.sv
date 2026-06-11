`timescale 1ns/1ps
`include "alu.vh"

module tb_rv32m_ex2;
    reg  [4:0]  rd_addr_i;
    reg  [31:0] rd_data_i;
    reg         regs_wen_i;
    reg         mem_req_load_i;
    reg         ecall_i;
    reg         mret_i;
    reg  [1:0]  load_mask_i;
    reg  [1:0]  load_addr_low_i;
    reg         load_is_signed_i;
    reg  [31:0] ecall_inst_i;
    reg         dcache_req_load_i;
    reg         dcache_req_store_i;
    reg  [31:0] dcache_addr_i;
    reg  [31:0] dcache_wdata_i;
    reg         dcache_write_dram_i;
    reg  [3:0]  dcache_we_i;
    reg  [`OP_INST_NUM - 1:0] inst_packaged_i;
    reg  [31:0] mdu_rs1_i;
    reg  [31:0] mdu_rs2_i;

    wire signed [33:0] div_remainder_s1;
    wire [31:0]        div_quotient_s1;
    wire               signed_div_op = inst_packaged_i[`INST_DIV] | inst_packaged_i[`INST_REM];
    wire [31:0]        dividend_abs = (signed_div_op && mdu_rs1_i[31]) ? (~mdu_rs1_i + 32'd1) : mdu_rs1_i;
    wire [31:0]        divisor_abs  = (signed_div_op && mdu_rs2_i[31]) ? (~mdu_rs2_i + 32'd1) : mdu_rs2_i;

    wire [4:0]  rd_addr_o;
    wire [31:0] rd_data_o;
    wire        regs_wen_o;
    wire        mem_req_load_o;
    wire        ecall_o;
    wire        mret_o;
    wire [1:0]  load_mask_o;
    wire [1:0]  load_addr_low_o;
    wire        load_is_signed_o;
    wire [31:0] ecall_inst_o;
    wire        dcache_req_load_o;
    wire        dcache_req_store_o;
    wire [31:0] dcache_addr_o;
    wire [31:0] dcache_wdata_o;
    wire        dcache_write_dram_o;
    wire [3:0]  dcache_we_o;

    rv32m_div_step #(.STEPS(16)) stage1 (
        .remainder_i (34'sd0),
        .quotient_i  (dividend_abs),
        .divisor_i   (divisor_abs),
        .remainder_o (div_remainder_s1),
        .quotient_o  (div_quotient_s1)
    );

    ex2 dut (
        .rd_addr_i            (rd_addr_i),
        .rd_data_i            (rd_data_i),
        .regs_wen_i           (regs_wen_i),
        .mem_req_load_i       (mem_req_load_i),
        .ecall_i              (ecall_i),
        .mret_i               (mret_i),
        .load_mask_i          (load_mask_i),
        .load_addr_low_i      (load_addr_low_i),
        .load_is_signed_i     (load_is_signed_i),
        .ecall_inst_i         (ecall_inst_i),
        .dcache_req_load_i    (dcache_req_load_i),
        .dcache_req_store_i   (dcache_req_store_i),
        .dcache_addr_i        (dcache_addr_i),
        .dcache_wdata_i       (dcache_wdata_i),
        .dcache_write_dram_i  (dcache_write_dram_i),
        .dcache_we_i          (dcache_we_i),
        .inst_packaged_i      (inst_packaged_i),
        .mdu_rs1_i            (mdu_rs1_i),
        .mdu_rs2_i            (mdu_rs2_i),
        .div_remainder_i      (div_remainder_s1),
        .div_quotient_i       (div_quotient_s1),
        .div_divisor_abs_i    (divisor_abs),
        .rd_addr_o            (rd_addr_o),
        .rd_data_o            (rd_data_o),
        .regs_wen_o           (regs_wen_o),
        .mem_req_load_o       (mem_req_load_o),
        .ecall_o              (ecall_o),
        .mret_o               (mret_o),
        .load_mask_o          (load_mask_o),
        .load_addr_low_o      (load_addr_low_o),
        .load_is_signed_o     (load_is_signed_o),
        .ecall_inst_o         (ecall_inst_o),
        .dcache_req_load_o    (dcache_req_load_o),
        .dcache_req_store_o   (dcache_req_store_o),
        .dcache_addr_o        (dcache_addr_o),
        .dcache_wdata_o       (dcache_wdata_o),
        .dcache_write_dram_o  (dcache_write_dram_o),
        .dcache_we_o          (dcache_we_o)
    );

    integer errors;

    task automatic clear_inputs;
        begin
            rd_addr_i = 5'd3;
            rd_data_i = 32'h1234_5678;
            regs_wen_i = 1'b1;
            mem_req_load_i = 1'b0;
            ecall_i = 1'b0;
            mret_i = 1'b0;
            load_mask_i = 2'b11;
            load_addr_low_i = 2'b00;
            load_is_signed_i = 1'b1;
            ecall_inst_i = 32'h0000_1000;
            dcache_req_load_i = 1'b0;
            dcache_req_store_i = 1'b0;
            dcache_addr_i = 32'h0000_2000;
            dcache_wdata_i = 32'hcafe_beef;
            dcache_write_dram_i = 1'b0;
            dcache_we_i = 4'h0;
            inst_packaged_i = {`OP_INST_NUM{1'b0}};
            mdu_rs1_i = 32'b0;
            mdu_rs2_i = 32'b0;
        end
    endtask

    task automatic expect_result;
        input [8*32-1:0] name;
        input [31:0] expected;
        begin
            #1;
            if (rd_data_o !== expected) begin
                $display("FAIL %0s: expected %h, got %h", name, expected, rd_data_o);
                errors = errors + 1;
            end
        end
    endtask

    task automatic check_mdu;
        input [8*32-1:0] name;
        input integer op_bit;
        input [31:0] rs1;
        input [31:0] rs2;
        input [31:0] expected;
        begin
            clear_inputs();
            inst_packaged_i[op_bit] = 1'b1;
            mdu_rs1_i = rs1;
            mdu_rs2_i = rs2;
            expect_result(name, expected);
        end
    endtask

    initial begin
        errors = 0;

        clear_inputs();
        expect_result("pass-through", 32'h1234_5678);

        check_mdu("mul low",    `INST_MUL,    32'hffff_fffe, 32'h0000_0003, 32'hffff_fffa);
        check_mdu("mulh ss",    `INST_MULH,   32'hffff_fffe, 32'h0000_0003, 32'hffff_ffff);
        check_mdu("mulhsu",     `INST_MULHSU, 32'hffff_fffe, 32'h8000_0000, 32'hffff_ffff);
        check_mdu("mulhu",      `INST_MULHU,  32'hffff_ffff, 32'hffff_ffff, 32'hffff_fffe);

        check_mdu("div signed", `INST_DIV,    32'hffff_fff9, 32'h0000_0003, 32'hffff_fffe);
        check_mdu("divu",       `INST_DIVU,   32'hffff_fff0, 32'h0000_0004, 32'h3fff_fffc);
        check_mdu("rem signed", `INST_REM,    32'hffff_fff9, 32'h0000_0003, 32'hffff_ffff);
        check_mdu("remu",       `INST_REMU,   32'hffff_fff1, 32'h0000_0010, 32'h0000_0001);

        check_mdu("div by zero", `INST_DIV,   32'h1234_5678, 32'h0000_0000, 32'hffff_ffff);
        check_mdu("rem by zero", `INST_REM,   32'h1234_5678, 32'h0000_0000, 32'h1234_5678);
        check_mdu("div overflow", `INST_DIV,  32'h8000_0000, 32'hffff_ffff, 32'h8000_0000);
        check_mdu("rem overflow", `INST_REM,  32'h8000_0000, 32'hffff_ffff, 32'h0000_0000);

        if (errors != 0) begin
            $display("RV32M EX2 test failed: %0d errors", errors);
            $finish(1);
        end

        $display("RV32M EX2 test passed");
        $finish;
    end
endmodule
