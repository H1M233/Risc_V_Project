module tb();
reg         clk;
reg         rst;

wire[31:0]  irom_addr;
wire[31:0]  irom_data;

wire[31:0]  drom_addr;
wire        drom_wen;
wire[1:0]   drom_mask;
wire[31:0]  drom_wdata;
wire[31:0]  drom_rdata;



top_riscv CPU(
    .cpu_rst        (rst),
    .cpu_clk        (clk),

    //from IROM
    .irom_addr      (irom_addr),
    .irom_data      (irom_data),

    //to DROM
    .perip_addr     (drom_addr),
    .perip_wen      (drom_wen),
    .perip_mask     (drom_mask),
    .perip_wdata    (drom_wdata),
    .perip_rdata    (drom_rdata)
);

rom IROM(
    .inst_addr_i    (irom_addr),
    .inst_o         (irom_data)
);

reg[3:0]   drom_wen_decoded;
always@(*) begin
    if(drom_wen) begin
        case(drom_mask)
            2'b00:      drom_wen_decoded = 4'b0000;
            2'b01:      drom_wen_decoded = 4'b0001;
            2'b10:      drom_wen_decoded = 4'b0011;
            2'b11:      drom_wen_decoded = 4'b1111;
            default:    drom_wen_decoded = 4'b0000;
        endcase
    end
    else
        drom_wen_decoded = 4'b0000;
end

ram DROM(
    .clk            (clk),
    .rst            (rst),
    .w_en_i         (drom_wen_decoded),       // 分别设置4个写使能
    .w_addr_i       (drom_addr),
    .w_data_i       (drom_wdata),
    .r_en_i         (1'b1),
    .r_addr_i       (drom_addr),
    .r_data_o       (drom_rdata)
);

// 测试内容
wire        x3  = tb.CPU.REGS.regs[3];   // 进行的test序号
wire        x26 = tb.CPU.REGS.regs[26];  // 测试结束
wire        x27 = tb.CPU.REGS.regs[27];  // 0: fail, 1: pass

// 初始化时钟信号
initial clk <= 1'b1;
always #10 clk = ~clk;

// 复位
initial begin
    rst <= 1'b0;    #30;    rst <= 1'b1;
end

// rom初始值
initial begin
    $readmemh("./generated/rv32ui-p-sub.txt", tb.IROM.rom_mem);
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