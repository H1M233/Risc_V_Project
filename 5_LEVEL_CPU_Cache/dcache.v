`include "rv32I.vh"
`include "switch.vh"

module dcache(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req_load,
    input               cpu_req_store,
    input      [31:0]   cpu_addr,
    (* max_fanout = 20 *)
    input      [31:0]   cpu_wdata,
    input      [3:0]    cpu_we,
    output     [31:0]   cpu_rdata,
    input               cpu_write_dram,

    (* max_fanout = 30 *)
    output              stall,

    // external DROM side
    output     [31:0]   mem_addr,
    output     [3:0]    mem_we,
    output              mem_wen,
    output     [31:0]   mem_wdata,
    input      [31:0]   mem_rdata,

    output              mem_ack
);
    localparam INDEX_WIDTH = `DCACHE_INDEX_WIDTH;
    localparam TAG_WIDTH = 30 - INDEX_WIDTH;
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    // 两路 FIFO
    (* ram_style = "distributed" *) reg [7:0] data_b0_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b1_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b2_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b3_w0 [0:LINE_NUM - 1];
`ifdef USE_2WAY_DCACHE
    (* ram_style = "distributed" *) reg [7:0] data_b0_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b1_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b2_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b3_w1 [0:LINE_NUM - 1];
`endif

    // [TAG_WIDTH]:Valid, [TAG_WIDTH-1:0]:Tag
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w0 [0:LINE_NUM - 1];
`ifdef USE_2WAY_DCACHE
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w1 [0:LINE_NUM - 1];
    reg replace_way [0:LINE_NUM - 1];
`endif

    // 状态寄存
    reg hit_r, miss_r;
    reg miss_wait;
    reg [INDEX_WIDTH-1:0] miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    reg miss_way;

    // 初始化
    integer i;
    initial begin
        for (i = 0; i < LINE_NUM; i = i + 1) tagv_w0[i] = 0;
    `ifdef USE_2WAY_DCACHE
        for (i = 0; i < LINE_NUM; i = i + 1) tagv_w1[i] = 0;
        for (i = 0; i < LINE_NUM; i = i + 1) replace_way[i] = 0;
    `endif
    end

    // 地址解码
    (* max_fanout = 30 *) wire [INDEX_WIDTH - 1:0] query_index = cpu_addr[INDEX_WIDTH + 1:2];
    (* max_fanout = 30 *) wire [TAG_WIDTH - 1:0]   query_tag   = cpu_addr[31:INDEX_WIDTH + 2];

    // 判断命中
    wire [TAG_WIDTH:0] hit_tagv_w0 = tagv_w0[query_index];
    wire hit_way0 = (hit_tagv_w0 == {1'b1, query_tag});
`ifdef USE_2WAY_DCACHE
    wire [TAG_WIDTH:0] hit_tagv_w1 = tagv_w1[query_index];
    wire hit_way1 = (hit_tagv_w1 == {1'b1, query_tag});
    wire dcache_hit = hit_way0 | hit_way1;
    wire miss_replace_way = replace_way[query_index];
`else
    wire hit_way1 = 1'b0;
    wire dcache_hit = hit_way0;
    wire miss_replace_way = 1'b0;
`endif

    // 读
    wire [7:0] hit_data_b3_w0 = data_b3_w0[query_index];
    wire [7:0] hit_data_b2_w0 = data_b2_w0[query_index];
    wire [7:0] hit_data_b1_w0 = data_b1_w0[query_index];
    wire [7:0] hit_data_b0_w0 = data_b0_w0[query_index];
`ifdef USE_2WAY_DCACHE
    wire [7:0] hit_data_b3_w1 = data_b3_w1[query_index];
    wire [7:0] hit_data_b2_w1 = data_b2_w1[query_index];
    wire [7:0] hit_data_b1_w1 = data_b1_w1[query_index];
    wire [7:0] hit_data_b0_w1 = data_b0_w1[query_index];
`endif

    // 命中数据
    reg [31:0] hit_data;
    always @(posedge clk) begin
        `ifdef USE_2WAY_DCACHE
            hit_data <= hit_way1 ?
                        {hit_data_b3_w1, hit_data_b2_w1, hit_data_b1_w1, hit_data_b0_w1} :
                        {hit_data_b3_w0, hit_data_b2_w0, hit_data_b1_w0, hit_data_b0_w0};
        `else
            hit_data <= {hit_data_b3_w0, hit_data_b2_w0, hit_data_b1_w0, hit_data_b0_w0};
        `endif
    end

    // Store 写 data
    always @(posedge clk) begin
        if (dcache_hit & cpu_req_store) begin
            if (hit_way0) begin
                if (cpu_we[3]) data_b3_w0[query_index] <= cpu_wdata[31:24];
                if (cpu_we[2]) data_b2_w0[query_index] <= cpu_wdata[23:16];
                if (cpu_we[1]) data_b1_w0[query_index] <= cpu_wdata[15:8];
                if (cpu_we[0]) data_b0_w0[query_index] <= cpu_wdata[7:0];
            end
        `ifdef USE_2WAY_DCACHE
            else begin
                if (cpu_we[3]) data_b3_w1[query_index] <= cpu_wdata[31:24];
                if (cpu_we[2]) data_b2_w1[query_index] <= cpu_wdata[23:16];
                if (cpu_we[1]) data_b1_w1[query_index] <= cpu_wdata[15:8];
                if (cpu_we[0]) data_b0_w1[query_index] <= cpu_wdata[7:0];
            end
        `endif
        end
        else if (miss_r) begin
            if (miss_way == 0) begin
                data_b3_w0[miss_index] <= mem_rdata[31:24];
                data_b2_w0[miss_index] <= mem_rdata[23:16];
                data_b1_w0[miss_index] <= mem_rdata[15:8];
                data_b0_w0[miss_index] <= mem_rdata[7:0];
            end 
        `ifdef USE_2WAY_DCACHE
            else begin
                data_b3_w1[miss_index] <= mem_rdata[31:24];
                data_b2_w1[miss_index] <= mem_rdata[23:16];
                data_b1_w1[miss_index] <= mem_rdata[15:8];
                data_b0_w1[miss_index] <= mem_rdata[7:0];
            end
        `endif
        end
    end

    // 写 tagv
    always @(posedge clk) begin
        if (miss_r) begin
            if (miss_way == 0)
                tagv_w0[miss_index] <= {1'b1, miss_tag};
        `ifdef USE_2WAY_DCACHE
            else
                tagv_w1[miss_index] <= {1'b1, miss_tag};
            replace_way[miss_index] <= ~miss_way;    // FIFO 替换指针更新
        `endif
        end
    end

    // 未命中状态转换
    always @(posedge clk) begin
        if (!rst) begin
            miss_wait   <= 0;
            miss_index  <= 0;
            miss_tag    <= 0;
            miss_way    <= 0;
        end
        else begin
            if (!dcache_hit && cpu_req_load && !miss_wait) begin
                miss_wait   <= 1'b1;
                miss_index  <= query_index;
                miss_tag    <= query_tag;
                miss_way    <= miss_replace_way;
            end
            else if (miss_wait) begin
                miss_wait   <= 1'b0;
            end
        end
    end

    // 输出状态寄存
    always @(posedge clk) begin
        if (!rst) begin
            hit_r       <= 1'b0;
            miss_r      <= 1'b0;
        end
        else begin
            hit_r       <= dcache_hit;
            miss_r      <= miss_wait;
        end
    end

    // 传输至 DRAM
    assign mem_addr   = cpu_addr;
    assign mem_we     = (cpu_write_dram) ? cpu_we : 4'b0;
    assign mem_wen    = cpu_req_store;
    assign mem_wdata  = cpu_wdata;

    // 暂停
    assign stall      = (!dcache_hit && cpu_req_load && !miss_wait);

    // 读数据
    assign cpu_rdata  = (miss_r) ? mem_rdata : hit_data;
    assign mem_ack    = hit_r | miss_r;
endmodule