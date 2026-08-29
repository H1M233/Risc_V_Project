`include "tb_def.svh"

module tb_verilator_coremark(
    input  logic        clk_cpu     ,
    input  logic        clk_50MHz   ,
    input  logic        rst         ,

    output logic        cnt_enable  ,
    output logic [31:0] cnt_time
);
`define VERILATOR_COREMARK

    top uut (
        .w_clk_50Mhz        (clk_50MHz),
        .cpu_clk            (clk_cpu),
        .w_clk_rst          (rst),
        .i_uart_rx          (),
        .o_uart_tx          (),

        .i_key              (),
        .o_seg_digit        (),
        .o_seg_sel          (),
        .o_led              ()
    );

    assign cnt_enable = tb_verilator_coremark.`PERIP_BRIDGE_PATH.cnt_enable_cfg;
    assign cnt_time   = tb_verilator_coremark.`PERIP_BRIDGE_PATH.cnt_rdata;

    initial begin
        $readmemh("./mem_init/irom.txt", tb_verilator_coremark.`IROM_PATH);
        $readmemh("./mem_init/dram.txt", tb_verilator_coremark.`DRAM_PATH);
    end
    

endmodule