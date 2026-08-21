`timescale 1ns / 1ps
`include "switch.svh"

module perip_bridge(
    input  logic        clk				            ,
    input  logic        cnt_clk			            ,
    input  logic        rst                         ,

    input  logic [31:0] ICACHE_perip_addr           ,
    input  logic        ICACHE_perip_arvalid        ,
    input  logic        ICACHE_perip_ren            ,
    output logic        ICACHE_perip_ready          ,
    output logic [31:0] ICACHE_perip_rdata          ,
    output logic        ICACHE_perip_rvalid         ,

    input  logic [31:0] DCACHE_perip_addr			,
    input  logic [31:0] DCACHE_perip_wdata		    ,
    input  logic [3:0]  DCACHE_perip_we			    ,
    input  logic        DCACHE_perip_wen            ,
    output logic [31:0] DCACHE_perip_rdata		    ,

    input  logic [3:0]  key_i	                    ,

	output logic [7:0]  seg_digit_o	                ,
    output logic [5:0]  seg_sel_o                   ,
    output logic [3:0]  led_o                       ,

    input  logic        uart_rx_i                   ,
    output logic        uart_tx_o                   
);
    localparam KEY_ADDR         = 32'h8020_0010;    // key[3:0]
    localparam SEG_ADDR         = 32'h8020_0020;    // seg
    localparam LED_ADDR         = 32'h8020_0040;    // led[3:0]
    localparam CNT_ADDR         = 32'h8020_0050;    // counter
    localparam UART_ADDR        = 32'h8020_0060;    // uart[7:0]
    localparam UART_STATUS_ADDR = 32'h8020_0064;
    
    localparam CNT_RESET_CMD = 32'h4000_0000;
    localparam CNT_START_CMD = 32'h8000_0000;
    localparam CNT_STOP_CMD  = 32'hFFFF_FFFF;

    logic [31:0] LED, SEG;
    logic [31:0] cnt_rdata, mmio_rdata, dram_rdata;
    logic        cnt_enable_cfg, cnt_reset_cfg;
    logic [31:0] uart_wdata;
    
    // delay
    logic [31:0] perip_addr_d [0:1];
    logic        perip_wen_d  [0:1];
    logic        perip_hit_dram;
    logic        perip_hit_mmio;
    
    // read & write process
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 3; i++) begin
                perip_addr_d[i] <= 0;
                perip_wen_d[i]  <= 0;  
            end
            perip_hit_dram  <= 0;
            perip_hit_mmio  <= 0;
        end
        else begin
            perip_addr_d[0] <= DCACHE_perip_addr;
            perip_wen_d[0]  <= DCACHE_perip_wen;

            perip_addr_d[1] <= perip_addr_d[0];
            perip_wen_d[1]  <= perip_wen_d[0];

            perip_hit_dram  <= (perip_addr_d[1] >= `DRAM_ADDR_START && perip_addr_d[1] < `DRAM_ADDR_END);
            perip_hit_mmio  <= (perip_addr_d[1] == KEY_ADDR)
                            |  (perip_addr_d[1] == LED_ADDR)
                            |  (perip_addr_d[1] == SEG_ADDR)
                            |  (perip_addr_d[1] == CNT_ADDR)
                            |  (perip_addr_d[1] == UART_STATUS_ADDR);
        end
    end
    
    // write process
    assign cnt_reset_cfg = DCACHE_perip_wen && (DCACHE_perip_addr == CNT_ADDR) && (DCACHE_perip_wdata == CNT_RESET_CMD);
    always_ff @(posedge clk) begin
        if (rst) begin
            LED             <= '0;
            SEG             <= '0;
            cnt_enable_cfg  <= '0;
        end else if (DCACHE_perip_wen) begin
            case (DCACHE_perip_addr)
                LED_ADDR : LED  <= DCACHE_perip_wdata;
                SEG_ADDR : SEG  <= DCACHE_perip_wdata;
                CNT_ADDR : begin
                    case (DCACHE_perip_wdata)
                        CNT_START_CMD : cnt_enable_cfg <= 1'b1;
                        CNT_STOP_CMD  : cnt_enable_cfg <= 1'b0;
                        default;
                    endcase
                end
                UART_ADDR : uart_wdata <= DCACHE_perip_wdata;
                default;
            endcase
        end
    end

    // read process: in 3 cycles
    always_ff @(posedge clk) begin
        if (~perip_wen_d[1]) begin
            case (perip_addr_d[1])
                LED_ADDR: 
                    mmio_rdata <= LED;
                
                KEY_ADDR: 
                    mmio_rdata <= {28'd0, key_i};

                SEG_ADDR: 
                    mmio_rdata <= SEG;

                CNT_ADDR: 
                    mmio_rdata <= cnt_rdata;

                UART_STATUS_ADDR: 
                    mmio_rdata <= uart_status;
                default :  mmio_rdata <= 32'hDEAD_BEEF;
            endcase
        end else begin
            mmio_rdata <= 32'h0;
        end
    end

    // seg driver
    display_seg seg_driver_inst (
        .clk                (clk),
        .rst                (rst),
        .s                  (SEG),
        .sel                (seg_sel_o),
        .seg                (seg_digit_o)
    ); 

    // DRAM rw
    dram_driver dram_driver_inst (
        .clk				(clk),
        .perip_addr			(DCACHE_perip_addr),
        .perip_wdata		(DCACHE_perip_wdata),
        .perip_we 			(DCACHE_perip_we),
        .perip_rdata		(dram_rdata)
    );

    // counter rw
    counter counter_inst (
        .cpu_clk            (clk),
        .cnt_clk            (cnt_clk),
        .rst                (rst),
        .cnt_reset_cpu      (cnt_reset_cfg),
        .cnt_enable_cpu     (cnt_enable_cfg),
        .perip_rdata		(cnt_rdata)
    );
    
    // uart driver
    logic [31:0] uart_status;
    logic        uart_wen;
    assign uart_wen = DCACHE_perip_wen && (DCACHE_perip_addr == UART_ADDR);
    uart_driver uart_driver_inst (
        .cpu_clk            (clk),
        .cnt_clk            (cnt_clk),
        .rst                (rst),
        .uart_wen           (uart_wen),
        .uart_reg           (uart_wdata),
        .uart_status        (uart_status),
        .rx_i               (uart_rx_i),
        .tx_o               (uart_tx_o)
    );

    // IROM r
    irom_driver irom_driver_inst (
        .clk				(clk),
        .perip_addr			(ICACHE_perip_addr),
        .perip_rdata		(ICACHE_perip_rdata),
        .arvalid            (ICACHE_perip_arvalid),
        .ren                (ICACHE_perip_ren),
        .ready              (ICACHE_perip_ready),
        .rvalid             (ICACHE_perip_rvalid)
    );

    always_comb begin
        unique case (1'b1)
            perip_hit_dram: DCACHE_perip_rdata = dram_rdata;
            perip_hit_mmio: DCACHE_perip_rdata = mmio_rdata;
            default:        DCACHE_perip_rdata = 32'b0;
        endcase
    end
    assign led_o = LED[3:0];

endmodule
