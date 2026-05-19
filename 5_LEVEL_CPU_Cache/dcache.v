`include "rv32I.vh"
`include "switch.vh"

module dcache#(
    parameter INDEX_WIDTH   = 2,    // INDEX_WIDTH 需 < 6
    parameter TAG_WIDTH     = (30 - INDEX_WIDTH)
)(
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

    output              stall,

    // external DROM side
    output     [31:0]   mem_addr,
    output     [3:0]    mem_we,
    output              mem_wen,
    output     [31:0]   mem_wdata,
    input      [31:0]   mem_rdata,

    output              mem_ack
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    // 两路 FIFO
    (* ram_style = "distributed" *) reg [7:0] data_b0_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b1_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b2_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b3_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b0_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b1_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b2_w1 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [7:0] data_b3_w1 [0:LINE_NUM - 1];

    // [TAG_WIDTH]:Valid, [TAG_WIDTH-1:0]:Tag
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w0 [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_w1 [0:LINE_NUM - 1];
    reg replace_way [0:LINE_NUM - 1];

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
        for (i = 0; i < LINE_NUM; i = i + 1) tagv_w1[i] = 0;
        for (i = 0; i < LINE_NUM; i = i + 1) replace_way[i] = 0;
    end

    // 地址解码
    wire [INDEX_WIDTH - 1:0] dcache_index = cpu_addr[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   dcache_tag   = cpu_addr[31:INDEX_WIDTH + 2];

    // 判断命中
    wire [TAG_WIDTH:0] hit_tagv_w0 = tagv_w0[dcache_index];
    wire [TAG_WIDTH:0] hit_tagv_w1 = tagv_w1[dcache_index];
    wire [TAG_WIDTH - 1:0] hit_tag_w0 = hit_tagv_w0[TAG_WIDTH - 1:0];
    wire [TAG_WIDTH - 1:0] hit_tag_w1 = hit_tagv_w1[TAG_WIDTH - 1:0];
    wire hit_valid_w0 = hit_tagv_w0[TAG_WIDTH];
    wire hit_valid_w1 = hit_tagv_w1[TAG_WIDTH];
    wire hit_way0 = (hit_tag_w0 == dcache_tag && hit_valid_w0);
    wire hit_way1 = (hit_tag_w1 == dcache_tag && hit_valid_w1);
    wire dcache_hit = hit_way0 | hit_way1;
    wire miss_replace_way = replace_way[dcache_index];

    // 读
    wire [7:0] hit_data_b3_w0 = data_b3_w0[dcache_index];
    wire [7:0] hit_data_b2_w0 = data_b2_w0[dcache_index];
    wire [7:0] hit_data_b1_w0 = data_b1_w0[dcache_index];
    wire [7:0] hit_data_b0_w0 = data_b0_w0[dcache_index];
    wire [7:0] hit_data_b3_w1 = data_b3_w1[dcache_index];
    wire [7:0] hit_data_b2_w1 = data_b2_w1[dcache_index];
    wire [7:0] hit_data_b1_w1 = data_b1_w1[dcache_index];
    wire [7:0] hit_data_b0_w1 = data_b0_w1[dcache_index];

    // 命中数据
    reg [31:0] hit_data;
    always @(posedge clk) begin
        hit_data <= hit_way1 ?
                    {hit_data_b3_w1, hit_data_b2_w1, hit_data_b1_w1, hit_data_b0_w1} :
                    {hit_data_b3_w0, hit_data_b2_w0, hit_data_b1_w0, hit_data_b0_w0};
    end

    // Store 写 data
    always @(posedge clk) begin
        if (dcache_hit & cpu_req_store) begin
            if (hit_way0) begin
                if (cpu_we[3]) data_b3_w0[dcache_index] <= cpu_wdata[31:24];
                if (cpu_we[2]) data_b2_w0[dcache_index] <= cpu_wdata[23:16];
                if (cpu_we[1]) data_b1_w0[dcache_index] <= cpu_wdata[15:8];
                if (cpu_we[0]) data_b0_w0[dcache_index] <= cpu_wdata[7:0];
            end
            else begin
                if (cpu_we[3]) data_b3_w1[dcache_index] <= cpu_wdata[31:24];
                if (cpu_we[2]) data_b2_w1[dcache_index] <= cpu_wdata[23:16];
                if (cpu_we[1]) data_b1_w1[dcache_index] <= cpu_wdata[15:8];
                if (cpu_we[0]) data_b0_w1[dcache_index] <= cpu_wdata[7:0];
            end
        end
        else if (miss_r) begin
            if (miss_way == 0) begin
                data_b3_w0[miss_index] <= mem_rdata[31:24];
                data_b2_w0[miss_index] <= mem_rdata[23:16];
                data_b1_w0[miss_index] <= mem_rdata[15:8];
                data_b0_w0[miss_index] <= mem_rdata[7:0];
            end 
            else begin
                data_b3_w1[miss_index] <= mem_rdata[31:24];
                data_b2_w1[miss_index] <= mem_rdata[23:16];
                data_b1_w1[miss_index] <= mem_rdata[15:8];
                data_b0_w1[miss_index] <= mem_rdata[7:0];
            end
        end
    end

    // 写 tagv
    always @(posedge clk) begin
        if (miss_r) begin
            if (miss_way == 0)
                tagv_w0[miss_index] <= {1'b1, miss_tag};
            else
                tagv_w1[miss_index] <= {1'b1, miss_tag};
            replace_way[miss_index] <= ~replace_way[miss_index];    // FIFO 替换指针更新
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
                miss_index  <= dcache_index;
                miss_tag    <= dcache_tag;
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
    assign mem_addr     = cpu_addr;
    assign mem_we       = (cpu_write_dram) ? cpu_we : 4'b0;
    assign mem_wen      = cpu_req_store;
    assign mem_wdata    = cpu_wdata;

    // 如果两个 way 都无效，可以直接 stall，无需等待 tag 比较 - 让信号能够提前到达并稳定
    wire both_invalid   = !hit_valid_w0 && !hit_valid_w1;
    wire fast_miss      = both_invalid && cpu_req_load && !miss_wait;
    assign stall        = fast_miss || (!dcache_hit && cpu_req_load && !miss_wait);

    // 读数据
    assign cpu_rdata    = (miss_r) ? mem_rdata : hit_data;
    assign mem_ack      = hit_r | miss_r;
endmodule