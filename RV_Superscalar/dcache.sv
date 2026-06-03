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

    (* max_fanout = 20 *)
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

    // 两路 D-cache
    (* ram_style = "distributed" *) reg [31:0] data_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [31:0] data_w1 [0:LINE_NUM - 1];

    // [TAG_WIDTH]: Valid,  [TAG_WIDTH - 1:0]: Tag
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w1 [0:LINE_NUM - 1];
    reg replace_way [0:LINE_NUM - 1];

    // 地址解码
    (* max_fanout = 20 *) wire [INDEX_WIDTH - 1:0] query_index = cpu_addr[INDEX_WIDTH + 1:2];
    (* max_fanout = 20 *) wire [TAG_WIDTH - 1:0]   query_tag   = cpu_addr[31:INDEX_WIDTH + 2];
    wire [INDEX_WIDTH - 1:0] query_index_data = cpu_addr[INDEX_WIDTH + 1:2];    // D-cache 读专用
    (* max_fanout = 20 *) wire [INDEX_WIDTH - 1:0] query_index_tagv = cpu_addr[INDEX_WIDTH + 1:2];    // tagv 读专用
    wire [TAG_WIDTH - 1:0]   query_tag_tagv   = cpu_addr[31:INDEX_WIDTH + 2];   // tagv 判断专用

    // 状态寄存
    reg miss_ready;
    reg tagv_wait, miss_wait;
    reg miss_way;
    reg [INDEX_WIDTH - 1:0] query_index_r;
    reg [TAG_WIDTH - 1:0] query_tag_r;
    reg [3:0] cpu_we_r;
    reg [31:0] cpu_wdata_r;
    reg cpu_req_store_r;
    always @(posedge clk) begin
        if (!rst) begin
            query_index_r   <= 0;
            query_tag_r     <= 0;
            cpu_we_r        <= 0;
            cpu_wdata_r     <= 0;
            cpu_req_store_r <= 0;
        end
        else begin
            query_index_r   <= query_index;
            query_tag_r     <= query_tag;
            cpu_we_r        <= cpu_we;
            cpu_wdata_r     <= cpu_wdata;
            cpu_req_store_r <= cpu_req_store;
        end
    end

    // 初始化
    integer i;
    initial begin
        for (i = 0; i < LINE_NUM; i = i + 1)  begin
            tagv_w0[i] = 0;
            tagv_w1[i] = 0;
            replace_way[i] = 0;
        end
    end

    // 判断命中 & replace_way & D-cache 读寄存器
    wire [TAG_WIDTH:0] hit_tagv_w0 = tagv_w0[query_index_tagv];
    wire [TAG_WIDTH:0] hit_tagv_w1 = tagv_w1[query_index_tagv];
    wire hit_way0 = (hit_tagv_w0 == {1'b1, query_tag_tagv});
    wire hit_way1 = (hit_tagv_w1 == {1'b1, query_tag_tagv});
    (* max_fanout = 20 *) reg hit_way_r;
    reg dcache_hit, dcache_miss;
    reg replace_way_r;
    reg [31:0] data_rdata_w0, data_rdata_w1;
    always @(posedge clk) begin
        hit_way_r       <= hit_way1;
        dcache_hit      <= (hit_way0 | hit_way1);
        dcache_miss     <= ~(hit_way0 | hit_way1);
        replace_way_r   <= replace_way[query_index];
        data_rdata_w0   <= data_w0[query_index_data];
        data_rdata_w1   <= data_w1[query_index_data];
    end

    // Store Buffer 状态传递
    wire store_buffer_en = dcache_hit & cpu_req_store_r;
    reg store_buffer_hit;
    reg [31:0] store_buffer_hit_data;
    always @(posedge clk) begin
        if (!rst) begin
            store_buffer_hit        <= 0;
            store_buffer_hit_data   <= 0;
        end
        else begin
            store_buffer_hit        <= (store_buffer_en && query_index == query_index_r && query_tag == query_tag_r);
            store_buffer_hit_data   <= store_buffer_data_merge;
        end
    end

    // Store Buffer 更新数据
    reg [31:0] store_buffer_data_merge;
    always @(*) begin
        store_buffer_data_merge = (hit_way_r) ? data_rdata_w1 : data_rdata_w0;
        if (cpu_we_r[3]) store_buffer_data_merge[31:24] = cpu_wdata_r[31:24];
        if (cpu_we_r[2]) store_buffer_data_merge[23:16] = cpu_wdata_r[23:16];
        if (cpu_we_r[1]) store_buffer_data_merge[15:8]  = cpu_wdata_r[15:8];
        if (cpu_we_r[0]) store_buffer_data_merge[7:0]   = cpu_wdata_r[7:0];
    end

    // Dcache 写回
    wire dcache_wen;
    wire [INDEX_WIDTH - 1:0] dcache_waddr;
    wire [31:0] dcache_wdata;
    wire dcache_wway;

    // Dcache 写使能
    assign dcache_wen   = (store_buffer_en | miss_ready);
    assign dcache_waddr = (miss_ready) ? miss_index : query_index_r;
    assign dcache_wdata = (miss_ready) ? mem_rdata : store_buffer_data_merge;
    assign dcache_wway  = (miss_ready) ? miss_way : hit_way_r;
    always @(posedge clk) begin: dcache_Write
        if (dcache_wen && dcache_wway == 1'b0) begin
            data_w0[dcache_waddr] <= dcache_wdata;
        end
        if (dcache_wen && dcache_wway == 1'b1) begin
            data_w1[dcache_waddr] <= dcache_wdata;
        end
    end

    // tagv 更新
    always @(posedge clk) begin
        if (miss_ready) begin
            replace_way[miss_index] <= ~miss_way;    // FIFO 替换指针更新
        end
        if (miss_ready && miss_way == 1'b0) begin
            tagv_w0[miss_index] <= {1'b1, miss_tag};
        end
        if (miss_ready && miss_way == 1'b1) begin
            tagv_w1[miss_index] <= {1'b1, miss_tag};
        end
    end

    // 命中数据
    wire [31:0] hit_data  = (store_buffer_hit) ? store_buffer_hit_data :
                            (hit_way_r) ? data_rdata_w1 : data_rdata_w0;

    // 未命中状态转换
    reg [INDEX_WIDTH - 1:0] miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    always @(posedge clk) begin
        if (!rst) begin
            tagv_wait       <= 0;
            miss_wait       <= 0;
            miss_way        <= 0;
            miss_index      <= 0;
            miss_tag        <= 0;
        end
        else begin
            if (tagv_wait && dcache_miss) begin
                tagv_wait   <= 1'b0;
                miss_wait   <= 1'b1;
                miss_way    <= replace_way_r;
                miss_index  <= query_index_r;
                miss_tag    <= query_tag_r;
            end
            else if (miss_wait) begin
                miss_wait   <= 1'b0;
            end
            else begin
                tagv_wait <= cpu_req_load;
            end
        end
    end

    // 输出状态寄存
    always @(posedge clk) begin
        if (!rst) begin
            miss_ready  <= 1'b0;
        end
        else begin
            miss_ready  <= miss_wait;
        end
    end

    // 传输至 DRAM
    assign mem_addr   = cpu_addr;
    assign mem_we     = (cpu_write_dram) ? cpu_we : 4'b0;
    assign mem_wen    = cpu_req_store;
    assign mem_wdata  = cpu_wdata;

    // 暂停
    assign stall = (tagv_wait && dcache_miss) | miss_wait;

    // 读数据
    assign cpu_rdata  = (miss_ready) ? mem_rdata : hit_data;
    assign mem_ack    = dcache_hit | miss_ready;
endmodule