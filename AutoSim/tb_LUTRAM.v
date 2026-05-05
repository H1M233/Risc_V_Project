`timescale 1ns / 1ps
module tb_LUTRAM();

    reg rst, clk;

    // IROM
    wire [31:0] irom_addr;
    wire [31:0] irom_data;

    // DRAM
    wire [31:0] dram_addr;
    wire        dram_wen;
    wire [1:0]  dram_mask;
    wire [31:0] dram_wdata;
    wire [31:0] dram_rdata;

    top_riscv CPU(
        .cpu_rst        (rst),
        .cpu_clk        (clk),

        // from IROM
        .irom_addr      (irom_addr),
        .irom_data      (irom_data),

        // to DROM
        .perip_addr     (dram_addr),
        .perip_wen      (dram_wen),
        .perip_mask     (dram_mask),
        .perip_wdata    (dram_wdata),
        .perip_rdata    (dram_rdata)
    );

    irom IROM(
        .inst_addr_i    (irom_addr),
        .inst_o         (irom_data)
    );

    dram_LUTRAM DRAM(
        .clk            (clk),
        .rst            (rst),
        .dram_addr_i    (dram_addr),
        .dram_wen_i     (dram_wen),
        .dram_mask_i    (dram_mask),
        .dram_wdata_i   (dram_wdata),
        .dram_rdata_o   (dram_rdata)
    );

    // 测试内容
    wire x3  = tb_LUTRAM.CPU.REGS.regs[3];   // 进行的test序号
    wire x26 = tb_LUTRAM.CPU.REGS.regs[26];  // 测试结束信号
    wire x27 = tb_LUTRAM.CPU.REGS.regs[27];  // 0: fail, 1: pass

    // 初始化时钟信号
    initial clk <= 1'b1;
    always #10 clk = ~clk;

    initial begin
        rst <= 1'b0;    #30;    rst <= 1'b1;
    end

    // rom初始值
    initial begin
        $readmemh("./generated/inst_data.txt", tb_LUTRAM.IROM.rom_mem);
        $readmemh("./generated/inst_data.txt", tb_LUTRAM.DRAM.ram_mem);
    end

    initial begin
        wait(x26);  # 200;
        if(x27 == 32'b1) begin
            $display("----------------------------------");
            $display("pass!!!");
            $display("----------------------------------");
        end
        else begin
            $display("----------------------------------");
            $display("fail!!!");
            $display("----------------------------------");
        end
        $finish();
    end
endmodule