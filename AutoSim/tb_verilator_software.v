`timescale 1ns / 1ps

module tb_verilator_software(
    input clk_50MHz,
    input clk_cpu,
    input rst,

    output [31:0] seg,
    output [1:0] commit,
    output pred_total, pred_miss, pred_total_b, pred_total_jr, pred_miss_b, pred_miss_jr,
    output [31:0] pc0, pc1,
    output reg [31:0] func_block_pc0, func_block_pc1,
    output [31:0] LED,
    output hold_signal, flush_signal,
    output reg [31:0] branch1, branch2
);
    `define VERILATOR_SOFTEWARE_TEST
    top uut (
        .w_clk_50Mhz    (clk_50MHz),
        .cpu_clk        (clk_cpu),
        .w_clk_rst      (rst),
        .i_uart_rx      (1'b1),
        .o_uart_tx      (),
        .virtual_led    (LED),  
        .virtual_seg    ()
    );
    `ifdef PROJECT_RV_SUPERSCALAR
        initial begin
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM_s0.rom_mem);
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM_s1.rom_mem);
            $readmemh("./mem_init/dram.txt", tb_verilator_software.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        assign seg = tb_verilator_software.uut.student_top_inst.bridge_inst.seg_driver.s;
        wire pred_flush = tb_verilator_software.uut.student_top_inst.Core_cpu.pred_flush_en;
        wire ex_mem_flush_en = tb_verilator_software.uut.student_top_inst.Core_cpu.pipe_flush_ex_mem;
        wire slot0_ex_valid = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.valid_o && !ex_mem_flush_en;
        wire slot1_ex_valid = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.valid_o 
                            && !tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.pred_flush_en
                            && !ex_mem_flush_en;
        assign commit = slot0_ex_valid + slot1_ex_valid;
        wire hazard_en = 1'b0;

        assign pc0 = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.pc_addr_i;
        assign pc1 = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.pc_addr_i;

        assign hold_signal = tb_verilator_software.uut.student_top_inst.Core_cpu.PC.dual_stall 
                            | tb_verilator_software.uut.student_top_inst.Core_cpu.PC.pipe_hold;
        assign flush_signal = tb_verilator_software.uut.student_top_inst.Core_cpu.PC.pipe_flush;

        wire [31:0] query_pc = 32'h8000_056c;

        always @(posedge clk_cpu) begin
            if (pc0 == 32'h80000520 && slot0_ex_valid) begin
                branch1 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.branch_rs1_data;
                // branch2 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.branch_rs2_data;
            end
            else if (pc1 == 32'h80000520 && slot1_ex_valid) begin
                branch1 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.branch_rs1_data;
                // branch2 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.branch_rs2_data;
            end

            // if (pc0 == query_pc && slot0_ex_valid) begin
            //     branch2 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.pred_flush_en;
            // end
            // else if (pc1 == query_pc && slot1_ex_valid) begin
            //     branch2 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.pred_flush_en;
            // end

            if ((pc0 == query_pc && slot0_ex_valid) || (pc1 == query_pc && slot1_ex_valid)) begin
                branch2 <= branch2 + 32'h1;
                // $finish();
            end
        end

        wire slot0_ex_is_jal = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.is_jal;
        wire slot0_ex_is_jalr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.is_jalr;
        wire slot0_ex_is_branch = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.is_branch;
        wire slot1_ex_is_jal = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.is_jal;
        wire slot1_ex_is_jalr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.is_jalr;
        wire slot1_ex_is_branch = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.is_branch;

        assign pred_total_b = slot0_ex_is_branch & !pred_flush;
        assign pred_total_jr = slot0_ex_is_jalr & !pred_flush;
        assign pred_total = (pred_total_b | pred_total_jr);
        assign pred_miss_b = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.update_gshare_en_o & !pred_flush;
        assign pred_miss_jr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.jalr_pred_mispredict & !pred_flush;
        assign pred_miss = pred_miss_b | pred_miss_jr;

        always @(posedge clk_cpu) begin
            if (slot0_ex_is_jal)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.jal_target;
            else if (slot0_ex_is_jalr)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.jalr_target;
            else if (slot0_ex_is_branch & tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.branch_taken == 1'b1)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT0.branch_jump_addr;
        end

        always @(posedge clk_cpu) begin
            if (slot1_ex_is_jal)
                func_block_pc1 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.jal_target;
            else if (slot1_ex_is_jalr)
                func_block_pc1 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.jalr_target;
            else if (slot1_ex_is_branch & tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.branch_taken == 1'b1)
                func_block_pc1 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX_SLOT1.branch_jump_addr;
        end

    `elsif PROJECT_RV_BASELINE
        initial begin
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/dram.txt", tb_verilator_software.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        assign seg = tb_verilator_software.uut.student_top_inst.bridge_inst.seg_driver.s;
        wire hazard_en = tb_verilator_software.uut.student_top_inst.Core_cpu.hazard_hazard_en;
        wire ex_valid = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.valid_o;
        assign commit = ex_valid & tb_verilator_software.uut.student_top_inst.Core_cpu.EX.inst_packaged_i != 0;

        assign pc0 = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.pc_addr_i;
        assign pc1 = 0;

        assign hold_signal = tb_verilator_software.uut.student_top_inst.Core_cpu.pipe_hold_pc;
        assign flush_signal = tb_verilator_software.uut.student_top_inst.Core_cpu.pipe_flush_icache;

        wire ex_is_jal = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.inst_packaged_i.is_jal & ex_valid;
        wire ex_is_jalr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.inst_packaged_i.is_jalr & ex_valid;
        wire ex_is_branch = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.inst_packaged_i.is_branch & ex_valid;
        assign pred_total = (ex_is_jalr | ex_is_branch);
        assign pred_total_b = ex_is_branch;
        assign pred_total_jr = ex_is_jalr;
        assign pred_miss_b = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.bpu_data_packaged_o.update_gshare_en;
        assign pred_miss_jr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.bpu_data_packaged_o.update_btb_en;
        assign pred_miss = pred_miss_b | pred_miss_jr;

        always @(posedge clk_cpu) begin
            if (ex_is_jal)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.add_res;
            else if (ex_is_jalr)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.jalr_target;
            else if (ex_is_branch & tb_verilator_software.uut.student_top_inst.Core_cpu.EX.branch_taken == 1'b1)
                func_block_pc0 <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.branch_jump_addr;
        end

    `endif
endmodule