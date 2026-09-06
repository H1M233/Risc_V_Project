module uart_driver (
    input  logic        cpu_clk         ,
    input  logic        cnt_clk         ,
    input  logic        rst             ,

    input  logic        uart_wen        ,
    input  logic [31:0] uart_reg        ,

    output logic [31:0] uart_status     ,

    input  logic        rx_i            ,
    output logic        tx_o            
);
    localparam UART_TX_BUSY  = 32'h0000_0001;

    // uart wire
    logic [7:0] rx_data;
    logic       rx_ready;
    logic [7:0] tx_data;
    logic       tx_valid;
    logic       tx_ready;

    // fifo - lock
    logic uart_tx_fifo_wen;
    always_ff @(posedge cpu_clk) begin
        if (rst) begin
            uart_tx_fifo_wen <= '0;
        end else begin
            uart_tx_fifo_wen <= uart_wen;
        end
    end
    logic tx_lock;
    always_ff @(posedge cpu_clk) begin
        if (rst) begin
            tx_lock <= '0;
        end else begin
            tx_lock <= tx_ready;
        end
    end

    // fifo
    logic uart_tx_fifo_empty, uart_tx_fifo_full;
    logic uart_tx_fifo_ren;
    assign uart_tx_fifo_ren = tx_lock && ~tx_ready && ~uart_tx_fifo_empty;
    fifo #(
        .DEPTH  (256),
        .WIDTH  (8)
    ) uart_tx_fifo_inst(
        .clk        (cpu_clk),
        .rst        (rst),
        .wr_en      (uart_tx_fifo_wen),
        .rd_en      (uart_tx_fifo_ren),
        .data_in    (uart_reg[7:0]),
        .data_out   (tx_data),
        .full       (uart_tx_fifo_full),
        .empty      (uart_tx_fifo_empty)
    );

    // uart instance
    assign uart_status = (uart_tx_fifo_full) ? UART_TX_BUSY : 32'h0;
    assign tx_valid = tx_ready && ~uart_tx_fifo_empty;
    uart #(
        .CLK_FREQ   (50000000),
        .BAUD_RATE  (1000000)
    ) uart_inst(
        .clk        (cnt_clk),
        .rst        (rst),
        .rx_data    (rx_data),
        .rx_ready   (rx_ready),
        .tx_data    (tx_data),
        .tx_valid   (tx_valid),
        .tx_ready   (tx_ready),
        .rx         (rx_i),
        .tx         (tx_o)
    );

endmodule