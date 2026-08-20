`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2025 06:21:13 PM
// Design Name: 
// Module Name: student_top
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


module student_top(
    input  logic        w_cpu_clk           ,
    input  logic        w_clk_50Mhz         ,
    input  logic        w_clk_rst           ,

    input  logic [3:0]  key_input	        ,

	output logic [7:0]  seg_digit_o         ,
    output logic [5:0]  seg_sel_o           ,
    output logic [3:0]  led_o               ,

    input  logic        uart_rx_i           ,
    output logic        uart_tx_o           
);
    // perip
    logic [31:0]    ICACHE_perip_addr, 
                    ICACHE_perip_rdata;

    logic           ICACHE_perip_arvalid,
                    ICACHE_perip_ren,
                    ICACHE_perip_ready,
                    ICACHE_perip_rvalid;

    logic [31:0]    DCACHE_perip_addr, 
                    DCACHE_perip_wdata, 
                    DCACHE_perip_rdata;

    logic [3:0]     DCACHE_perip_we;
    logic           DCACHE_perip_wen;

    top_riscv Core_cpu (
        .cpu_rst                    (w_clk_rst),
        .cpu_clk                    (w_cpu_clk),

        // Interface to Peripheral
        .ICACHE_perip_addr          (ICACHE_perip_addr),
        .ICACHE_perip_arvalid       (ICACHE_perip_arvalid),
        .ICACHE_perip_ren           (ICACHE_perip_ren),
        .ICACHE_perip_ready         (ICACHE_perip_ready),
        .ICACHE_perip_rdata         (ICACHE_perip_rdata),
        .ICACHE_perip_rvalid        (ICACHE_perip_rvalid),

        .DCACHE_perip_addr          (DCACHE_perip_addr),     
        .DCACHE_perip_we            (DCACHE_perip_we),
        .DCACHE_perip_wen           (DCACHE_perip_wen),
        .DCACHE_perip_wdata         (DCACHE_perip_wdata),    
        .DCACHE_perip_rdata         (DCACHE_perip_rdata)     
    );
    
    perip_bridge bridge_inst (
        .clk			            (w_cpu_clk),
        .cnt_clk                    (w_clk_50Mhz),
        .rst                        (w_clk_rst),

        .ICACHE_perip_addr          (ICACHE_perip_addr),
        .ICACHE_perip_arvalid       (ICACHE_perip_arvalid),
        .ICACHE_perip_ren           (ICACHE_perip_ren),
        .ICACHE_perip_ready         (ICACHE_perip_ready),
        .ICACHE_perip_rdata         (ICACHE_perip_rdata),
        .ICACHE_perip_rvalid        (ICACHE_perip_rvalid),

        .DCACHE_perip_addr          (DCACHE_perip_addr),     
        .DCACHE_perip_we            (DCACHE_perip_we),   
        .DCACHE_perip_wen           (DCACHE_perip_wen),    
        .DCACHE_perip_wdata         (DCACHE_perip_wdata),    
        .DCACHE_perip_rdata         (DCACHE_perip_rdata),

        .key_i	                    (key_input),
        .seg_digit_o                (seg_digit_o),
        .seg_sel_o                  (seg_sel_o),
        .led_o                      (led_o),

        .uart_rx_i                  (uart_rx_i),
        .uart_tx_o                  (uart_tx_o)
    );

endmodule
