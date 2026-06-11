`timescale 1ns / 1ps

module tb_verilator_inst(
    input clk_cpu,
    input rst,

    output x3,
    output x26,
    output x27
);
    `define VERILATOR_INST_TEST
    `ifdef PROJECT_RV_SUPERSCALAR
        wire [31:0] pc_s0, pc_s1, instruction_s0, instruction_s1;
        wire [31:0] perip_addr, perip_wdata, perip_rdata;
        wire [3:0] perip_we;
        top_riscv Core_cpu (
            .cpu_rst            (rst),
            .cpu_clk            (clk_cpu),
            .slot0_irom_addr    (pc_s0),
            .slot1_irom_addr    (pc_s1),
            .slot0_irom_data    (instruction_s0),
            .slot1_irom_data    (instruction_s1),
            .perip_addr         (perip_addr),     
            .perip_we           (perip_we),
            .perip_wen          (),
            .perip_wdata        (perip_wdata),    
            .perip_rdata        (perip_rdata)     
        );

        IROM Mem_IROM_s0 (.a(pc_s0[13:2]), .spo(instruction_s0));
        IROM Mem_IROM_s1 (.a(pc_s1[13:2]), .spo(instruction_s1));
        dram_driver dram_driver_inst (.clk(clk_cpu), .dram_addr(perip_addr[17:2]), .perip_wdata(perip_wdata), .perip_we(perip_we), .perip_rdata(perip_rdata));
        
        initial begin
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM_s0.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM_s1.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        
        assign x3  = tb_verilator_inst.Core_cpu.REGS.regs_p1[3];   // 进行的test序号
        assign x26 = tb_verilator_inst.Core_cpu.REGS.regs_p1[26];  // 测试结束信号
        assign x27 = tb_verilator_inst.Core_cpu.REGS.regs_p1[27];  // 0: fail, 1: pass

    `elsif PROJECT_RV_BASELINE
        wire [31:0] pc, instruction;
        wire [31:0] perip_addr, perip_wdata, perip_rdata;
        wire [3:0] perip_we;
        top_riscv Core_cpu (
            .cpu_rst            (rst),
            .cpu_clk            (clk_cpu),
            .irom_addr          (pc),             
            .irom_data          (instruction),   
            .perip_addr         (perip_addr),     
            .perip_we           (perip_we),
            .perip_wen          (),
            .perip_wdata        (perip_wdata),    
            .perip_rdata        (perip_rdata)     
        );

        IROM Mem_IROM (.a(pc[13:2]), .spo(instruction));
        dram_driver dram_driver_inst (.clk(clk_cpu), .dram_addr(perip_addr[17:2]), .perip_wdata(perip_wdata), .perip_we(perip_we), .perip_rdata(perip_rdata));
        
        initial begin
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        
        assign x3  = tb_verilator_inst.Core_cpu.REGS.regs_p1[3];   // 进行的test序号
        assign x26 = tb_verilator_inst.Core_cpu.REGS.regs_p1[26];  // 测试结束信号
        assign x27 = tb_verilator_inst.Core_cpu.REGS.regs_p1[27];  // 0: fail, 1: pass
        
    `endif

    reg [31:0] cycle_count;
    always @(posedge clk_cpu) begin
    if (x26 == 1'b1) begin
        if (cycle_count >= 32'd100)  // 等待 100 个时钟周期
            $finish();
        else
            cycle_count <= cycle_count + 1'd1;
    end
end
endmodule
