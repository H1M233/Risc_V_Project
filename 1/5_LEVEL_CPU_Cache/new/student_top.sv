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


module student_top#(
    parameter                           P_SW_CNT            = 64,
    parameter                           P_LED_CNT           = 32,
    parameter                           P_SEG_CNT           = 40,
    parameter                           P_KEY_CNT           = 8
) (
    input                                       w_cpu_clk     ,
    input                                       w_clk_50Mhz   ,
    input                                       w_clk_rst     ,
    input  [P_KEY_CNT - 1:0]                    virtual_key   ,
    input  [P_SW_CNT  - 1:0]                    virtual_sw    ,

    output [P_LED_CNT - 1:0]                    virtual_led   ,
    output [P_SEG_CNT - 1:0]                    virtual_seg   
);

    // IROM
    logic [31:0] pc;
    logic [11:0] inst_addr;
    logic [31:0] instruction;

    // perip
    logic [31:0] perip_addr, perip_wdata, perip_rdata;
    logic perip_wen;
    logic [1:0] perip_mask;
    logic [P_LED_CNT - 1:0] virtual_led_cpu, virtual_led_meta, virtual_led_sync;
    logic [P_SEG_CNT - 1:0] virtual_seg_cpu, virtual_seg_meta, virtual_seg_sync;

    // 16KB = 2^12 * 32bit
    assign inst_addr = pc[13:2];

     top_riscv Core_cpu (
        .cpu_rst            (!w_clk_rst),
        .cpu_clk            (w_cpu_clk),

        // Interface to IROM
        .irom_addr          (pc),             
        .irom_data          (instruction),   

        // Interface to DRAM & periphera
        .perip_addr         (perip_addr),     
        .perip_wen          (perip_wen),     
        .perip_mask         (perip_mask),   
        .perip_wdata        (perip_wdata),    
        .perip_rdata        (perip_rdata)     
    );

    IROM Mem_IROM (
        .a          (inst_addr),
        .spo        (instruction)
    );
    
    perip_bridge bridge_inst (
        .clk				(w_cpu_clk),
        .cnt_clk            (w_clk_50Mhz),
        .rst                (w_clk_rst),
        .perip_addr			(perip_addr),
        .perip_wdata		(perip_wdata),
        .perip_wen			(perip_wen),
        .perip_mask			(perip_mask),
        .perip_rdata		(perip_rdata),
        .virtual_sw_input	(virtual_sw),
        .virtual_key_input	(virtual_key),	
        .virtual_seg_output	(virtual_seg_cpu),
        .virtual_led_output (virtual_led_cpu)
    );

    // Synchronize observable outputs into the 50 MHz controller domain.
    always_ff @(posedge w_clk_50Mhz or posedge w_clk_rst) begin
        if (w_clk_rst) begin
            virtual_led_meta <= '0;
            virtual_led_sync <= '0;
            virtual_seg_meta <= '0;
            virtual_seg_sync <= '0;
        end
        else begin
            virtual_led_meta <= virtual_led_cpu;
            virtual_led_sync <= virtual_led_meta;
            virtual_seg_meta <= virtual_seg_cpu;
            virtual_seg_sync <= virtual_seg_meta;
        end
    end

    assign virtual_led = virtual_led_sync;
    assign virtual_seg = virtual_seg_sync;

endmodule
