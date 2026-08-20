module fifo #(
    parameter DEPTH = 256,
    parameter WIDTH = 8
)(
    input  logic                        clk         ,
    input  logic                        rst         ,
    input  logic                        wr_en       ,   // din 写
    input  logic                        rd_en       ,   // dout 读
    input  logic [WIDTH - 1:0]          data_in     ,
    output logic [WIDTH - 1:0]          data_out    ,
    output logic                        full        ,
    output logic                        empty       
);
    localparam PTR_WIDTH = $clog2(DEPTH);
    localparam COUNT_WIDTH = $clog2(DEPTH + 1);

    logic [WIDTH - 1:0]       mem [0:DEPTH - 1];
    logic [PTR_WIDTH - 1:0]   wr_ptr;   // 高位写指针
    logic [PTR_WIDTH - 1:0]   rd_ptr;   // 低位读指针
    logic [COUNT_WIDTH - 1:0] count_r;

    assign empty = (count_r == 0);
    assign full  = (count_r == DEPTH);

    // 初始化
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = {WIDTH{1'b0}};
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count_r  <= 0;
            data_out <= 0;
        end else begin
            if (rd_en) begin
                if (empty) begin
                    data_out <= 32'b0;
                end else begin
                    data_out <= mem[rd_ptr];
                end
            end

            if (wr_en & ~full) begin   // 写操作 - 入队
                mem[wr_ptr] <= data_in;
                wr_ptr      <= wr_ptr + 1'b1;
            end

            if (rd_en & ~empty) begin  // 读操作 - 仅出队
                rd_ptr   <= rd_ptr + 1'b1;
            end

            if (wr_en & ~full & rd_en & ~empty) begin    // 计数控制
                // 读写同时进行时计数器不变
            end else begin
                if (wr_en & ~full) begin
                    count_r <= count_r + 1'b1;
                end
                if (rd_en & ~empty) begin
                    count_r <= count_r - 1'b1;
                end
            end
        end
    end
endmodule