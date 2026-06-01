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

    // 两路 FIFO
    (* ram_style = "distributed" *) reg [31:0] data_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [31:0] data_w1 [0:LINE_NUM - 1];

    // [TAG_WIDTH]: Valid,  [TAG_WIDTH - 1:0]: Tag
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w1 [0:LINE_NUM - 1];
    reg replace_way [0:LINE_NUM - 1];

    // 状态寄存
    reg hit_r, miss_r, hit_way_r;
    reg miss_wait1, miss_wait2;
    reg [INDEX_WIDTH-1:0] miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    reg miss_way;

    // 初始化
    integer i;
    initial begin
        for (i = 0; i < LINE_NUM; i = i + 1)  begin
            tagv_w0[i] = 0;
            tagv_w1[i] = 0;
            replace_way[i] = 0;
        end
    end

    // 地址解码
    (* max_fanout = 20 *) wire [INDEX_WIDTH - 1:0] query_index = cpu_addr[INDEX_WIDTH + 1:2];
    (* max_fanout = 20 *) wire [TAG_WIDTH - 1:0]   query_tag   = cpu_addr[31:INDEX_WIDTH + 2];

    // 判断命中
    wire [TAG_WIDTH:0] hit_tagv_w0 = tagv_w0[query_index];
    wire [TAG_WIDTH:0] hit_tagv_w1 = tagv_w1[query_index];
    wire hit_way0 = (hit_tagv_w0 == {1'b1, query_tag});
    wire hit_way1 = (hit_tagv_w1 == {1'b1, query_tag});
    wire dcache_hit = (hit_way0 | hit_way1);
    wire miss_replace_way = replace_way[query_index];

    // Dcache 读寄存器
    reg [31:0] data_rdata_w0;
    reg [31:0] data_rdata_w1;

    always @(posedge clk) begin
        data_rdata_w0 <= data_w0[query_index];
        data_rdata_w1 <= data_w1[query_index];
    end

    // Store Buffer 状态传递
    reg store_buffer_en;
    reg store_buffer_hit_way;
    reg [3:0] store_buffer_we;
    reg [INDEX_WIDTH - 1:0] store_buffer_index;
    reg [31:0] store_buffer_wdata;

    always @(posedge clk) begin
        if (dcache_hit & cpu_req_store) begin
            store_buffer_en         <= 1'b1;
            store_buffer_hit_way    <= hit_way1;
            store_buffer_we         <= cpu_we;
            store_buffer_index      <= query_index;
            store_buffer_wdata      <= cpu_wdata;
        end
        else begin
            store_buffer_en         <= 0;
            store_buffer_hit_way    <= 0;
            store_buffer_we         <= 0;
            store_buffer_index      <= 0;
            store_buffer_wdata      <= 0;
        end
    end

    // Store Buffer 更新数据
    reg [31:0] store_buffer_data_merge;
    always @(*) begin
        store_buffer_data_merge = (store_buffer_hit_way) ? data_rdata_w1 : data_rdata_w0;
        if (store_buffer_we[3]) store_buffer_data_merge[31:24] = store_buffer_wdata[31:24];
        if (store_buffer_we[2]) store_buffer_data_merge[23:16] = store_buffer_wdata[23:16];
        if (store_buffer_we[1]) store_buffer_data_merge[15:8]  = store_buffer_wdata[15:8];
        if (store_buffer_we[0]) store_buffer_data_merge[7:0]   = store_buffer_wdata[7:0];
    end

    // Dcache 写回
    wire dcache_wen;
    wire [INDEX_WIDTH - 1:0] dcache_waddr;
    wire [31:0] dcache_wdata;
    wire dcache_wway;

    assign dcache_wen   = (store_buffer_en | miss_r);
    assign dcache_waddr = (store_buffer_en) ? store_buffer_index : miss_index;
    assign dcache_wdata = (store_buffer_en) ? store_buffer_data_merge : mem_rdata;
    assign dcache_wway  = (store_buffer_en) ? store_buffer_hit_way : miss_way;

    always @(posedge clk) begin: dcache_Read_And_Write
        if (dcache_wen) begin
            if (dcache_wway == 1'b0) begin
                data_w0[dcache_waddr] <= dcache_wdata;
            end
            else begin
                data_w1[dcache_waddr] <= dcache_wdata;
            end
        end
    end

    // tagv 更新
    always @(posedge clk) begin
        if (miss_r) begin
            replace_way[miss_index] <= ~miss_way;    // FIFO 替换指针更新
            if (miss_way == 1'b0) begin
                tagv_w0[miss_index] <= {1'b1, miss_tag};
            end
            else begin
                tagv_w1[miss_index] <= {1'b1, miss_tag};
            end
        end
    end

    // 为 Load 寄存一拍 Store Buffer 数据
    wire store_buffer_hit = (dcache_hit && query_index == store_buffer_index && store_buffer_hit_way == hit_way1);
    reg store_buffer_hit_r;
    reg [31:0] store_buffer_hit_data;

    always @(posedge clk) begin
        if (store_buffer_en) begin
            store_buffer_hit_r      <= store_buffer_hit;
            store_buffer_hit_data   <= store_buffer_data_merge;
        end
        else begin
            store_buffer_hit_r      <= 0;
            store_buffer_hit_data   <= 0;
        end 
    end

    // 命中数据
    wire [31:0] hit_data  = (store_buffer_hit_r) ? store_buffer_hit_data :
                            (hit_way_r) ? data_rdata_w1 : data_rdata_w0;

    // 未命中状态转换
    always @(posedge clk) begin
        if (!rst) begin
            miss_wait1  <= 0;
            miss_wait2  <= 0;
            miss_index  <= 0;
            miss_tag    <= 0;
            miss_way    <= 0;
        end
        else begin
            if (!dcache_hit && cpu_req_load && !miss_wait1 && !miss_wait2) begin
                miss_wait1  <= 1'b1;
                miss_index  <= query_index;
                miss_tag    <= query_tag;
                miss_way    <= miss_replace_way;
            end
            else if (miss_wait1) begin
                miss_wait1  <= 1'b0;
                miss_wait2  <= 1'b1;
            end
            else if (miss_wait2) begin
                miss_wait2  <= 1'b0;
            end
        end
    end

    // 输出状态寄存
    always @(posedge clk) begin
        if (!rst) begin
            hit_r       <= 1'b0;
            miss_r      <= 1'b0;
            hit_way_r   <= 1'b0;
        end
        else begin
            hit_r       <= dcache_hit;
            miss_r      <= miss_wait2;
            hit_way_r   <= hit_way1;
        end
    end

    // 传输至 DRAM
    assign mem_addr   = cpu_addr;
    assign mem_we     = (cpu_write_dram) ? cpu_we : 4'b0;
    assign mem_wen    = cpu_req_store;
    assign mem_wdata  = cpu_wdata;

    // 暂停
    assign stall = miss_wait1 | miss_wait2;

    // 读数据
    assign cpu_rdata  = (miss_r) ? mem_rdata : hit_data;
    assign mem_ack    = hit_r | miss_r;
endmodule