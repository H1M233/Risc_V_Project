module tb;
    reg         clk;
    reg         rst;

    open_risc_v_soc open_risc_v_soc_inst(
        .clk    (clk),
        .rst    (rst)
    );

    wire        x3  = tb.open_risc_v_soc_inst.open_risc_v_inst.regs_inst.regs[3];   // 进行的test序号
    wire        x26 = tb.open_risc_v_soc_inst.open_risc_v_inst.regs_inst.regs[26];  // 测试结束
    wire        x27 = tb.open_risc_v_soc_inst.open_risc_v_inst.regs_inst.regs[27];  // 0: fail, 1: pass
    
    // 初始化时钟信号
    initial clk <= 1'b1;
    always #10 clk = ~clk;

    // 复位
    initial begin
        rst <= 1'b0;    #30;    rst <= 1'b1;
    end

    // rom初始值
    initial begin
        $readmemh("../sim/generated/rv32ui-p-add.txt", tb.open_risc_v_soc_inst.rom_inst.rom_mem);
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