`include "rv32I.svh"
`include "switch.svh"

module dcache(
    input  logic            clk                 ,
    input  logic            rst                 ,

    // CPU/MEM side
    input  DCACHE_data_t    cpu_data_pkg_i      ,
    output logic [31:0]     cpu_rdata           ,
    output logic            load_ready          ,
    output logic            store_ready         ,
    output logic            stall               ,

    // external DROM side
    output logic [31:0]     perip_addr          , 
    output logic [3:0]      perip_we            ,
    output logic            perip_wen           ,
    output logic [31:0]     perip_wdata         ,
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

    // ===============================
    // STAGE 1 : 发送读写请求 & 判断命中
    // ===============================
    // 地址解码
    (* max_fanout = 128 *)
    wire [INDEX_WIDTH - 1:0] query_index = dpkg.addr[INDEX_WIDTH + 1:2];
    (* max_fanout = 128 *)
    wire [TAG_WIDTH - 1:0]   query_tag   = dpkg.addr[31:INDEX_WIDTH + 2];

    // tagv 异步读
    wire [TAG_WIDTH:0] tagv_w0_rdata = tagv_w0[query_index];
    wire [TAG_WIDTH:0] tagv_w1_rdata = tagv_w1[query_index];

    // 判断命中
    wire hit_way0 = (tagv_w0_rdata == {1'b1, query_tag});
    wire hit_way1 = (tagv_w1_rdata == {1'b1, query_tag});

    // 状态寄存 STAGE 1 -> STAGE 2
    logic                       miss_wait;
    logic                       miss_ready;
    logic                       miss_way;
    logic [INDEX_WIDTH - 1:0]   miss_index;
    logic [TAG_WIDTH - 1:0]     miss_tag;
    
    logic [INDEX_WIDTH - 1:0]   req_index;
    logic [TAG_WIDTH - 1:0]     req_tag;
    logic                       req_load;
    logic                       req_store;
    logic [3:0]                 req_store_we;
    logic [31:0]                req_wdata;

    logic                       DCACHE_hit;
    logic                       DCACHE_miss;
    logic                       hit_way_r;
    logic                       replace_way_r;
    logic [31:0]                cache_rdata_w0;
    logic [31:0]                cache_rdata_w1;

    always_ff @(posedge clk) begin
        if (rst) begin
            req_index       <= 0;
            req_tag         <= 0;
            req_store       <= 0;
            req_store_we    <= 0;
            req_wdata       <= 0;

            DCACHE_hit      <= 0;
            DCACHE_miss     <= 0;
            hit_way_r       <= 0;

            replace_way_r   <= 0;
            cache_rdata_w0  <= 0;
            cache_rdata_w1  <= 0;
        end else begin
            req_index       <= query_index;
            req_tag         <= query_tag;
            req_store       <= dpkg.req_store;
            req_store_we    <= dpkg.we;
            req_wdata       <= dpkg.wdata;

            DCACHE_hit      <= (hit_way0 | hit_way1) && dpkg.write_dram;
            DCACHE_miss     <= ~(hit_way0 | hit_way1) || ~dpkg.write_dram;
            hit_way_r       <= hit_way1 && dpkg.write_dram;

            replace_way_r   <= replace_way[query_index];
            cache_rdata_w0  <= data_w0[query_index];
            cache_rdata_w1  <= data_w1[query_index];
        end
    end

    // Store Buffer 状态传递
    wire         store_buffer_en = DCACHE_hit & req_store;
    logic        store_buffer_hit;
    logic [31:0] store_buffer_data_merge;
    logic [31:0] store_buffer_hit_data;

    always_ff @(posedge clk) begin
        if (rst) begin
            store_buffer_hit        <= 0;
            store_buffer_hit_data   <= 0;
        end else begin
            store_buffer_hit        <= store_buffer_en && (query_index == req_index) && (query_tag == req_tag);
            store_buffer_hit_data   <= store_buffer_data_merge;
        end
    end

    // Store Buffer 更新数据
    always_comb begin
        store_buffer_data_merge = (hit_way_r) ? cache_rdata_w1 : cache_rdata_w0;
        if (req_store_we[3]) store_buffer_data_merge[31:24] = req_wdata[31:24];
        if (req_store_we[2]) store_buffer_data_merge[23:16] = req_wdata[23:16];
        if (req_store_we[1]) store_buffer_data_merge[15:8]  = req_wdata[15:8];
        if (req_store_we[0]) store_buffer_data_merge[7:0]   = req_wdata[7:0];
    end

    // Dcache 写回
    wire dcache_wen;
    wire [INDEX_WIDTH - 1:0] dcache_waddr;
    wire [31:0] dcache_wdata;
    wire dcache_wway;

    // Dcache 写使能
    assign dcache_wen   = store_buffer_en | miss_ready;
    assign dcache_waddr = (miss_ready) ? miss_index : req_index;
    assign dcache_wdata = (miss_ready) ? cpu_rdata : store_buffer_data_merge;
    assign dcache_wway  = (miss_ready) ? miss_way : hit_way_r;
    always_ff @(posedge clk) begin: DCACHE_WriteBack
        if (dcache_wen && dcache_wway == 1'b0) begin
            data_w0[dcache_waddr]   <= dcache_wdata;
        end
        if (dcache_wen && dcache_wway == 1'b1) begin
            data_w1[dcache_waddr]   <= dcache_wdata;
        end
        if (miss_ready) begin
            replace_way[miss_index] <= ~miss_way;    // FIFO 替换指针更新
        end
        if (miss_ready && miss_way == 1'b0) begin
            tagv_w0[miss_index]     <= {1'b1, miss_tag};
        end
        if (miss_ready && miss_way == 1'b1) begin
            tagv_w1[miss_index]     <= {1'b1, miss_tag};
        end
    end

    // 命中数据
    wire [31:0] hit_data  = (store_buffer_hit) ? store_buffer_hit_data :
                            (hit_way_r) ? cache_rdata_w1 : cache_rdata_w0;

    // 未命中状态转换
    always_ff @(posedge clk) begin
        if (rst) begin
            req_load        <= 0;
            miss_wait       <= 0;
            miss_way        <= 0;
            miss_index      <= 0;
            miss_tag        <= 0;
        end else begin
            if (req_load && DCACHE_miss) begin
                req_load    <= 1'b0;
                miss_wait   <= 1'b1;
                miss_way    <= replace_way_r;
                miss_index  <= req_index;
                miss_tag    <= req_tag;
            end else if (miss_wait) begin
                miss_wait   <= 1'b0;
            end else begin
                req_load   <= dpkg.req_load;
            end
        end
    end

    // 输出状态寄存
    always_ff @(posedge clk) begin
        if (rst) begin
            miss_ready  <= 1'b0;
        end else begin
            miss_ready  <= miss_wait;
        end
    end

    // 传输至 DRAM
    assign perip_addr   = dpkg.addr;
    assign perip_we     = (dpkg.write_dram) ? dpkg.we : 4'b0;
    assign perip_wen    = dpkg.req_store;
    assign perip_wdata  = dpkg.wdata;

    // 暂停
    assign stall = (req_load && DCACHE_miss) | miss_wait;

    // 读数据
    assign cpu_rdata   = (miss_ready) ? perip_rdata : hit_data;
    assign load_ready  = DCACHE_hit | miss_ready;

    always_ff @(posedge clk) begin
        store_ready <= req_store;
    end
endmodule