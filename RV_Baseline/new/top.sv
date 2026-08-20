`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2025 06:21:44 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top(
    `ifdef VERILATOR
    input  logic        w_clk_50Mhz         ,
    input  logic        cpu_clk             ,
    input  logic        w_clk_rst           ,
    `else
    input  logic        i_sys_clk_p         ,
    input  logic        i_sys_clk_n         ,
    `endif
    input  logic        i_uart_rx           ,
    output logic        o_uart_tx           ,

    input  logic [3:0]  i_key	            ,

	output logic [7:0]  o_seg_digit	        ,
    output logic [5:0]  o_seg_sel           ,
    output logic [3:0]  o_led
);

    `ifndef VERILATOR
    wire w_clk_50Mhz, cpu_clk;
    wire w_clk_rst;
    `endif

    `ifndef VERILATOR
    pll pll_inst(
        .clk_in1_p(i_sys_clk_p),
        .clk_in1_n(i_sys_clk_n),
        .clk_out1(w_clk_50Mhz),
        .clk_out2(cpu_clk),
        .locked(w_clk_rst)
    );
    `endif

    student_top student_top_inst(
        .w_cpu_clk(cpu_clk),
        .w_clk_50Mhz(w_clk_50Mhz),
        .w_clk_rst(~w_clk_rst),
        .key_input(i_key),
        .seg_digit_o(o_seg_digit),
        .seg_sel_o(o_seg_sel),
        .led_o(o_led),
        .uart_rx_i(i_uart_rx),
        .uart_tx_o(o_uart_tx)
    );

endmodule

