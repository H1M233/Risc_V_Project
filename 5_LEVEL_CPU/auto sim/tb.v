`timescale 1ns / 1ps
module tb();
reg         clk;
reg         rst;
reg         clk_50Mhz;

wire[7:0]    virtual_key;
wire[63:0]   virtual_sw;

wire[31:0]   virtual_led;
wire[39:0]   virtual_seg;

student_top #(
    .P_SW_CNT       (64),
    .P_LED_CNT      (32),
    .P_SEG_CNT      (40),
    .P_KEY_CNT      (8)
) TOP(
    // input
    .w_cpu_clk     (clk),
    .w_clk_50Mhz   (clk_50Mhz),
    .w_clk_rst     (rst),
    .virtual_key   (virtual_key),
    .virtual_sw    (virtual_sw),

    // output
    .virtual_led   (virtual_led),
    .virtual_seg   (virtual_seg)
);


// 测试内容
wire        x3  = tb.TOP.Core_cpu.REGS.regs[3];   // 进行的test序号
wire        x26 = tb.TOP.Core_cpu.REGS.regs[26];  // 测试结束
wire        x27 = tb.TOP.Core_cpu.REGS.regs[27];  // 0: fail, 1: pass

// 初始化时钟信号
initial clk <= 1'b1;
always #10 clk = ~clk;

initial clk_50Mhz <= 1'b1;
always #10 clk_50Mhz = ~clk_50Mhz;


initial begin
    rst <= 1'b1;    #30;    rst <= 1'b0;
end

// rom初始值
initial begin
    $readmemh("./generated/inst_data.txt", tb.TOP.Mem_IROM.rom_mem);
    // $readmemh("./inst_txt/rv32ui-p-andi.txt", tb.open_risc_v_soc_inst.rom_inst.rom_mem);
end

initial begin
    wait(x26);  # 200;
    // $display("c: 00009f13 = %d", tb.open_risc_v_soc_inst.rom_inst.rom_mem[3]);
    if(x27 == 32'b1) begin
        $display("----------------------------------");
        $display("pass!");
        $display("----------------------------------");
    end
    else begin
        $display("----------------------------------");
        $display("fail!");
        $display("----------------------------------");
    end
    $finish();
end
endmodule