module tb_verilator_coremark(
    input  logic        clk_cpu     ,
    input  logic        clk_50MHz   ,
    input  logic        rst         ,

    output logic        cnt_enable  ,
    output logic [31:0] cnt_time
);
    `ifdef PROJECT_RV_BASELINE
    
    `endif

    student_top student_top_inst(
        .w_cpu_clk      (clk_cpu),
        .w_clk_50Mhz    (clk_50MHz),
        .w_clk_rst      (~rst),
        .virtual_key    (),
        .virtual_sw     (),
        .virtual_led    (),
        .virtual_seg    ()
    );

    assign cnt_enable = tb_verilator_coremark.student_top_inst.bridge_inst.cnt_enable_cfg;
    assign cnt_time   = tb_verilator_coremark.student_top_inst.bridge_inst.cnt_rdata;

    initial begin
        $readmemh("./mem_init/irom.txt", tb_verilator_coremark.student_top_inst.Mem_IROM.rom_mem);
        $readmemh("./mem_init/dram.txt", tb_verilator_coremark.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
    end
    

endmodule