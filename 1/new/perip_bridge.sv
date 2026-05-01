`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/04/22 10:25:24
// Design Name: 
// Module Name: perip_bridge
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

module perip_bridge(
    input  logic         clk				,
    input  logic         cnt_clk			,
    input  logic         rst                ,

    input  logic [31:0]  perip_addr			,
    input  logic [31:0]  perip_wdata		,
    input  logic         perip_wen			,
	input  logic [1:0]	 perip_mask			,
    output logic [31:0]  perip_rdata		,

    input  logic [63:0]  virtual_sw_input	,
    input  logic [7:0]   virtual_key_input	,	

	output logic [39:0]  virtual_seg_output	,
    output logic [31:0]  virtual_led_output
);
    localparam DRAM_ADDR_START = 32'h8010_0000;
    localparam DRAM_ADDR_END   = 32'h8013_FFFF;
    localparam SW0_ADDR  = 32'h8020_0000;  // sw[31:0]
    localparam SW1_ADDR  = 32'h8020_0004;  // sw[63:32]
    localparam KEY_ADDR  = 32'h8020_0010;  // key[7:0]
    localparam SEG_ADDR  = 32'h8020_0020;  // seg
    localparam LED_ADDR  = 32'h8020_0040;  // led[31:0]
    localparam CNT_ADDR  = 32'h8020_0050;  // counter
    localparam CNT_START_CMD = 32'h8000_0000;
    localparam CNT_STOP_CMD  = 32'hFFFF_FFFF;

    logic [31:0] LED;
    logic [31:0] seg_wdata, cnt_rdata, mmio_rdata, dram_rdata;
    logic [39:0] seg_output, seg_output_q;
    logic cnt_enable_cfg;
    logic [63:0] virtual_sw_meta, virtual_sw_sync;
    logic [7:0]  virtual_key_meta, virtual_key_sync;
    
    // delay perip_addr, perip_wen, perip_mask
    reg [31:0] perip_addr_d [0:2];
    reg perip_wen_d [0:2];
    reg [1:0] perip_mask_d [0:2];
    
    localparam READ_DELAY = 2'd2;
    wire [31:0] perip_addr_delay = perip_addr_d[READ_DELAY - 1];
    wire perip_wen_delay = perip_wen_d[READ_DELAY - 1];
    wire [1:0] perip_mask_delay = perip_mask_d[READ_DELAY - 1];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            perip_addr_d[0]   <= 32'b0;
            perip_addr_d[1]   <= 32'b0;
            perip_addr_d[2]   <= 32'b0 ;
            perip_wen_d[0]    <= 1'b0;
            perip_wen_d[1]    <= 1'b0;
            perip_wen_d[2]    <= 1'b0;
            perip_mask_d[0]   <= 2'b0;
            perip_mask_d[1]   <= 2'b0;
            perip_mask_d[2]   <= 2'b0;
        end
        else begin
            perip_addr_d[0]   <= perip_addr;
            perip_addr_d[1]   <= perip_addr_d[0];
            perip_addr_d[2]   <= perip_addr_d[1];
            perip_wen_d[0]    <= perip_wen;
            perip_wen_d[1]    <= perip_wen_d[0];
            perip_wen_d[2]    <= perip_wen_d[1];
            perip_mask_d[0]   <= perip_mask;
            perip_mask_d[1]   <= perip_mask_d[0];
            perip_mask_d[2]   <= perip_mask_d[1];
        end
    end
    
    
    // Synchronize slow virtual inputs into the CPU/peripheral clock domain.
    // This removes the clk_out1_pll -> clk_out2_pll MMIO timing path.
    always_ff @(posedge clk) begin
        if (rst) begin
            virtual_sw_meta  <= '0;
            virtual_sw_sync  <= '0;
            virtual_key_meta <= '0;
            virtual_key_sync <= '0;
        end
        else begin
            virtual_sw_meta  <= virtual_sw_input;
            virtual_sw_sync  <= virtual_sw_meta;
            virtual_key_meta <= virtual_key_input;
            virtual_key_sync <= virtual_key_meta;
        end
    end

    // we don't care perip_mask in LED, SEG, SW & KEY, only care in DRAM
    // write process
    always_ff @(posedge clk) begin
        if (rst) begin
            LED            <= 32'd0;
            seg_wdata      <= 32'd0;
            cnt_enable_cfg <= 1'b0;
        end else if (perip_wen) begin
            case (perip_addr)
                LED_ADDR:   LED <= perip_wdata;
                SEG_ADDR:   seg_wdata <= perip_wdata;
                CNT_ADDR: begin
                    if (perip_wdata == CNT_START_CMD) begin
                        cnt_enable_cfg <= 1'b1;
                    end else if (perip_wdata == CNT_STOP_CMD) begin
                        cnt_enable_cfg <= 1'b0;
                    end
                end
            endcase
        end
    end

    // read process: in one cycle
    always_comb begin
        if (~perip_wen) begin
            case (perip_addr_delay)
                SW0_ADDR:  mmio_rdata = virtual_sw_sync[31:0];
                SW1_ADDR:  mmio_rdata = virtual_sw_sync[63:32];
                KEY_ADDR:  mmio_rdata = {24'd0, virtual_key_sync};
                SEG_ADDR:  mmio_rdata = seg_wdata;
                default:   mmio_rdata = 32'hDEAD_BEEF;
            endcase
        end else begin
            mmio_rdata = 32'h0;
        end
    end

    // seg driver
    display_seg seg_driver (
        .clk    (clk),
        .rst    (rst),
        .s      (seg_wdata),
        .seg1   (seg_output[6:0]),
        .seg2   (seg_output[16:10]),
        .seg3   (seg_output[26:20]),
        .seg4   (seg_output[36:30]),
        .ans    ({seg_output[39:38], seg_output[29:28], seg_output[19:18], seg_output[9:8]})
    ); 
   
    assign seg_output[7]  = 0;
    assign seg_output[17] = 0;
    assign seg_output[27] = 0;
    assign seg_output[37] = 0;

    // Register display outputs in the CPU clock domain before crossing into
    // the 50 MHz observation domain, so the CDC path only carries registered data.
    always_ff @(posedge clk) begin
        if (rst) begin
            seg_output_q <= '0;
        end
        else begin
            seg_output_q <= seg_output;
        end
    end
    

    // dram rw
    dram_driver dram_driver_inst (
        .clk				(clk),
        .perip_addr			(perip_addr[17:0]),
        .perip_wdata		(perip_wdata),
        .perip_mask			(perip_mask),
        .dram_wen 			(perip_wen & (perip_addr >= DRAM_ADDR_START && perip_addr < DRAM_ADDR_END)),
        .perip_rdata		(dram_rdata),
        
        // delay
        .perip_addr_delay   (perip_addr_delay),
        .perip_mask_delay   (perip_mask_delay)
    );

    // counter rw
    counter counter_inst (
        .cpu_clk            (clk),
        .cnt_clk            (cnt_clk),
        .rst                (rst),
        .cnt_enable_cpu     (cnt_enable_cfg),
        .perip_rdata		(cnt_rdata)
    );

    assign perip_rdata = {32{perip_addr_delay == SW0_ADDR}} & mmio_rdata |
                        {32{perip_addr_delay == SW1_ADDR}} & mmio_rdata |
                        {32{perip_addr_delay == KEY_ADDR}} & mmio_rdata |
                        {32{perip_addr_delay == SEG_ADDR}} & mmio_rdata |
                        {32{perip_addr_delay >= DRAM_ADDR_START && perip_addr_delay < DRAM_ADDR_END}} & dram_rdata |
                        {32{perip_addr_delay == CNT_ADDR}} & cnt_rdata;
    
    assign virtual_led_output = LED;
    assign virtual_seg_output = seg_output_q;

endmodule
