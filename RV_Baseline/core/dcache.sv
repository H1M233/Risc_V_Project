`include "rv32I.svh"
`include "switch.svh"

module dcache(
    input  logic clk,
    input  logic rst,

    // CPU/MEM side
    input  DCACHE_data_t    cpu_data_pkg_i,
    output logic [31:0]     cpu_rdata,
    output logic            load_ready,
    output logic            store_ready,

    output logic            stall,

    // external DROM side
    output logic [31:0]     perip_addr,
    output logic [3:0]      perip_we,
    output logic            perip_wen,
    output logic [31:0]     perip_wdata,
    input  logic [31:0]     perip_rdata
);
    localparam INDEX_WIDTH = `DCACHE_INDEX_WIDTH;
    localparam TAG_WIDTH = 30 - INDEX_WIDTH;
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    // 解码
    DCACHE_data_t dpkg;
    assign dpkg = cpu_data_pkg_i;

    // 两路 D-cache
    (* ram_style = "distributed" *) reg [31:0] data_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [31:0] data_w1 [0:LINE_NUM - 1];

    // [TAG_WIDTH]: Valid,  [TAG_WIDTH - 1:0]: Tag
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg replace_way [0:LINE_NUM - 1];

    // 初始化
    initial begin
        for (int i = 0; i < LINE_NUM; i++)  begin
            data_w0[i]      = 0;
            data_w1[i]      = 0;
            tagv_w0[i]      = 0;
            tagv_w1[i]      = 0;
            replace_way[i]  = 0;
        end
    end

    // 地址解码
    wire [INDEX_WIDTH - 1:0] query_index      = dpkg.addr[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   query_tag        = dpkg.addr[31:INDEX_WIDTH + 2];
    wire [INDEX_WIDTH - 1:0] query_index_data = dpkg.addr[INDEX_WIDTH + 1:2];    // D-cache 读专用
    wire [INDEX_WIDTH - 1:0] query_index_tagv = dpkg.addr[INDEX_WIDTH + 1:2];    // tagv 读专用
    wire [TAG_WIDTH - 1:0]   query_tag_tagv   = dpkg.addr[31:INDEX_WIDTH + 2];   // tagv 判断专用

    // 状态寄存
    logic                     tagv_wait, miss_wait, miss_ready;
    logic                     miss_way;
    logic [INDEX_WIDTH - 1:0] query_index_r, miss_index;
    logic [TAG_WIDTH - 1:0]   query_tag_r, miss_tag;
    logic [3:0]               store_buffer_we;
    logic [31:0]              cpu_wdata_r;
    logic                     cpu_req_store_r;
    always_ff @(posedge clk) begin
        if (rst) begin
            query_index_r   <= 0;
            query_tag_r     <= 0;
            store_buffer_we <= 0;
            cpu_wdata_r     <= 0;
            cpu_req_store_r <= 0;
        end
        else begin
            query_index_r   <= query_index;
            query_tag_r     <= query_tag;
            store_buffer_we <= dpkg.we;
            cpu_wdata_r     <= dpkg.wdata;
            cpu_req_store_r <= dpkg.req_store;
        end
    end
    
    // 判断命中 & replace_way & D-cache 读寄存器
    wire [TAG_WIDTH:0] hit_tagv_w0 = tagv_w0[query_index_tagv];
    wire [TAG_WIDTH:0] hit_tagv_w1 = tagv_w1[query_index_tagv];
    wire hit_way0 = (hit_tagv_w0 == {1'b1, query_tag_tagv});
    wire hit_way1 = (hit_tagv_w1 == {1'b1, query_tag_tagv});
    logic hit_way_r;
    logic dcache_hit, dcache_miss;
    logic replace_way_r;
    logic [31:0] data_rdata_w0, data_rdata_w1;
    always_ff @(posedge clk) begin
        if (rst) begin
            hit_way_r       <= 0;
            dcache_hit      <= 0;
            dcache_miss     <= 0;
        end
        else begin
            hit_way_r       <= hit_way1 && dpkg.write_dram;
            dcache_hit      <= (hit_way0 | hit_way1) && dpkg.write_dram;
            dcache_miss     <= ~(hit_way0 | hit_way1) || ~dpkg.write_dram;
        end
    end

    wire        replace_way_w   = replace_way[query_index];
    wire [31:0] data_rdata_w0_w = data_w0[query_index_data];
    wire [31:0] data_rdata_w1_w = data_w1[query_index_data];
    always_ff @(posedge clk) begin
        replace_way_r   <= replace_way_w;
        data_rdata_w0   <= data_rdata_w0_w;
        data_rdata_w1   <= data_rdata_w1_w;
    end

    // Store Buffer 状态传递
    wire store_buffer_en = dcache_hit & cpu_req_store_r;
    logic        store_buffer_hit;
    logic [31:0] store_buffer_data_merge;
    logic [31:0] store_buffer_hit_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            store_buffer_hit        <= 0;
            store_buffer_hit_data   <= 0;
        end
        else begin
            store_buffer_hit        <= store_buffer_en && (query_index == query_index_r) && (query_tag == query_tag_r);
            store_buffer_hit_data   <= store_buffer_data_merge;
        end
    end

    // Store Buffer 更新数据
    always_comb begin
        store_buffer_data_merge = (hit_way_r) ? data_rdata_w1 : data_rdata_w0;
        if (store_buffer_we[3]) store_buffer_data_merge[31:24] = cpu_wdata_r[31:24];
        if (store_buffer_we[2]) store_buffer_data_merge[23:16] = cpu_wdata_r[23:16];
        if (store_buffer_we[1]) store_buffer_data_merge[15:8]  = cpu_wdata_r[15:8];
        if (store_buffer_we[0]) store_buffer_data_merge[7:0]   = cpu_wdata_r[7:0];
    end

    // Dcache 写回
    wire dcache_wen;
    wire [INDEX_WIDTH - 1:0] dcache_waddr;
    wire [31:0] dcache_wdata;
    wire dcache_wway;

    // Dcache 写使能
    assign dcache_wen   = store_buffer_en | miss_ready;
    assign dcache_waddr = (miss_ready) ? miss_index : query_index_r;
    assign dcache_wdata = (miss_ready) ? cpu_rdata : store_buffer_data_merge;
    assign dcache_wway  = (miss_ready) ? miss_way : hit_way_r;
    always_ff @(posedge clk) begin: dcache_Write
        if (dcache_wen && dcache_wway == 1'b0) begin
            data_w0[dcache_waddr] <= dcache_wdata;
        end
        if (dcache_wen && dcache_wway == 1'b1) begin
            data_w1[dcache_waddr] <= dcache_wdata;
        end
    end

    // tagv 更新
    always_ff @(posedge clk) begin
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
    always_ff @(posedge clk) begin
        if (rst) begin
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
                tagv_wait <= dpkg.req_load;
            end
        end
    end

    // 输出状态寄存
    always_ff @(posedge clk) begin
        if (rst) begin
            miss_ready  <= 1'b0;
        end
        else begin
            miss_ready  <= miss_wait;
        end
    end

    // 传输至 DRAM
    assign perip_addr   = dpkg.addr;
    assign perip_we     = (dpkg.write_dram) ? dpkg.we : 4'b0;
    assign perip_wen    = dpkg.req_store;
    assign perip_wdata  = dpkg.wdata;

    // 暂停
    assign stall = (tagv_wait && dcache_miss) | miss_wait;

    // 读数据
    assign cpu_rdata   = (miss_ready) ? perip_rdata : hit_data;
    assign load_ready  = dcache_hit | miss_ready;
    always_ff @(posedge clk) begin
        store_ready <= cpu_req_store_r;
    end
endmodule