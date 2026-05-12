`timescale 1ns / 1ps

module tb_verilator_software(
    input clk_50MHz,
    input clk_cpu,
    input rst,

    output [31:0] seg,
    output [31:0] mem_inst,
    output        icache_req,
    output        icache_hit,
    output        dcache_req,
    output        dcache_hit,
    output [31:0] pc,
    output reg [31:0] func_block_addr,
    output [31:0] LED
);
    top uut (
        .w_clk_50Mhz    (clk_50MHz),
        .cpu_clk        (clk_cpu),
        .w_clk_rst      (rst),
        .i_uart_rx      (1'b1),
        .o_uart_tx      (),
        .virtual_led    (LED),  
        .virtual_seg    ()
    );

    `ifdef PROJECT_5_LEVEL_CPU_CACHE
        initial begin
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/dram.txt", tb_verilator_software.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        assign seg = tb_verilator_software.uut.student_top_inst.bridge_inst.seg_driver.s;
        assign mem_inst = tb_verilator_software.uut.student_top_inst.Core_cpu.MEM.inst_i;
        assign pc = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.pc_addr_i;

        assign icache_req = (tb_verilator_software.uut.student_top_inst.Core_cpu.ICACHE.pipe_hold == 1'd0);
        assign icache_hit = tb_verilator_software.uut.student_top_inst.Core_cpu.ICACHE.hit;
        assign dcache_req = (tb_verilator_software.uut.student_top_inst.Core_cpu.DCACHE.state == 3'd1);
        assign dcache_hit = tb_verilator_software.uut.student_top_inst.Core_cpu.DCACHE.hit;
        wire ex_is_jal = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.is_jal;
        wire ex_is_jalr = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.is_jalr;
        wire ex_is_branch = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.is_branch;
        always @(posedge clk_cpu) begin
            if (ex_is_jal)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.add_res;
            else if (ex_is_jalr)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.jalr_target;
            else if (ex_is_branch & tb_verilator_software.uut.student_top_inst.Core_cpu.EX.branch_taken == 1'b1)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.branch_jump_addr;
        end

    `elsif PROJECT_5_LEVEL_CPU_IMPROVED
        initial begin
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/dram.txt", tb_verilator_software.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        assign seg = tb_verilator_software.uut.student_top_inst.bridge_inst.seg_driver.s;
        assign mem_inst = tb_verilator_software.uut.student_top_inst.Core_cpu.MEM.inst_i;
        assign pc = tb_verilator_software.uut.student_top_inst.Core_cpu.EX.pc_addr_i;

        assign icache_req = 1'b1;
        assign icache_hit = 1'b0;
        assign dcache_req = 1'b1;
        assign dcache_hit = 1'b0;
        always @(posedge clk_cpu) begin
            if (tb_verilator_software.uut.student_top_inst.Core_cpu.EX.jump_en)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.EX.jump_addr_o;
        end

    `elsif PROJECT_5_LEVEL_CPU_OOO
        initial begin
            $readmemh("./mem_init/irom.txt", tb_verilator_software.uut.student_top_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/dram.txt", tb_verilator_software.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        assign seg = tb_verilator_software.uut.student_top_inst.bridge_inst.seg_driver.s;
        // assign mem_inst = tb_verilator.uut.student_top_inst.Core_cpu.gen_ooo.CORE.MEM.inst_i;
        assign mem_inst = 32'b0;
        assign pc = tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ALU0.pc;

        assign icache_req = (tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ICACHE.flush == 1'd0);
        assign icache_hit = tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ICACHE.hit;
        assign dcache_req = (tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.DCACHE.state == 3'd1);
        // assign dcache_hit = tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.DCACHE.hit;
        assign dcache_hit = 1'b0;
        always @(posedge clk_cpu) begin
            if (tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ALU0.need_redirect)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ALU0.redirect_pc;
            else if (tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ALU0.pred_taken)
                func_block_addr <= tb_verilator_software.uut.student_top_inst.Core_cpu.gen_ooo.CORE.ALU0.actual_next_pc;
        end

    `endif
endmodule


module tb_verilator_inst(
    input clk_cpu,
    input rst,

    output x3,
    output x26,
    output x27
);
    `ifdef PROJECT_5_LEVEL_CPU_CACHE
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
        dram_driver dram_driver_inst (.clk(clk_cpu), .perip_addr(perip_addr[17:0]), .perip_wdata(perip_wdata), .perip_we(perip_we), .perip_rdata(perip_rdata));
        
        initial begin
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end
        
        assign x3  = tb_verilator_inst.Core_cpu.REGS.regs[3];   // 进行的test序号
        assign x26 = tb_verilator_inst.Core_cpu.REGS.regs[26];  // 测试结束信号
        assign x27 = tb_verilator_inst.Core_cpu.REGS.regs[27];  // 0: fail, 1: pass

    `elsif PROJECT_5_LEVEL_CPU_IMPROVED
        wire [31:0] pc, instruction;
        wire [31:0] perip_addr, perip_wdata, perip_rdata;
        wire [1:0] perip_mask;
        wire perip_wen;
        top_riscv Core_cpu (
            .cpu_rst            (rst),
            .cpu_clk            (clk_cpu),
            .irom_addr          (pc),             
            .irom_data          (instruction),   
            .perip_addr         (perip_addr),
            .perip_wen          (perip_wen),
            .perip_mask         (perip_mask),
            .perip_wdata        (perip_wdata),    
            .perip_rdata        (perip_rdata)     
        );

        IROM Mem_IROM (.a(pc[13:2]), .spo(instruction));
        dram_driver dram_driver_inst (.clk(clk_cpu), .perip_addr(perip_addr[17:0]), .perip_wdata(perip_wdata), .perip_mask(perip_mask), .dram_wen(perip_wen), .perip_rdata(perip_rdata));
        
        initial begin
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end

        assign x3  = tb_verilator_inst.Core_cpu.REGS.regs[3];   // 进行的test序号
        assign x26 = tb_verilator_inst.Core_cpu.REGS.regs[26];  // 测试结束信号
        assign x27 = tb_verilator_inst.Core_cpu.REGS.regs[27];  // 0: fail, 1: pass

    `elsif PROJECT_5_LEVEL_CPU_OOO
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
        dram_driver dram_driver_inst (.clk(clk_cpu), .perip_addr(perip_addr[17:0]), .perip_wdata(perip_wdata), .perip_we(perip_we), .perip_rdata(perip_rdata));
        initial begin
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.Mem_IROM.rom_mem);
            $readmemh("./mem_init/inst_test.txt", tb_verilator_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
        end

        assign x3  = tb_verilator_inst.Core_cpu.gen_ooo.CORE.REGS.regs[3];   // 进行的test序号
        assign x26 = tb_verilator_inst.Core_cpu.gen_ooo.CORE.REGS.regs[26];  // 测试结束信号
        assign x27 = tb_verilator_inst.Core_cpu.gen_ooo.CORE.REGS.regs[27];  // 0: fail, 1: pass

    `endif
endmodule
