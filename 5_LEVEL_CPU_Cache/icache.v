`include "rv32I.vh"
`include "switch.vh"

module icache #(
    parameter INDEX_WIDTH   = 6,        // 索引宽度
    parameter TAG_WIDTH     = 24,       // tag 宽度
    parameter WAYS          = 2         // 路数
)(
    input               clk,
    input               rst,

    // CPU / IF side
    input      [31:0]   cpu_pc,
    (* max_fanout = 30 *)
    output reg [31:0]   cpu_inst,
    input               pipe_hold,

    // IROM side
    output     [31:0]   mem_addr,
    input      [31:0]   mem_inst
);
    `ifdef ENABLE_ICACHE
    assign mem_addr = cpu_pc;

    localparam LINE_NUM    = 2 ** INDEX_WIDTH;  // 组数

    // 提取索引和 tag
    (* max_fanout = 20 *)
    wire [INDEX_WIDTH - 1:0] index = cpu_pc[INDEX_WIDTH + 1:2];
    (* max_fanout = 20 *) 
    wire [TAG_WIDTH - 1:0]   tag = cpu_pc[31:INDEX_WIDTH + 2];

    // 存储结构：
    `define ARRAY_ADDR(index, way) ((index) * WAYS + way)
    localparam ARRAY_DEPTH = LINE_NUM * WAYS;   // vivado 不会推断二维数组为 memory
    localparam ARRAY_WIDTH = INDEX_WIDTH + $clog2(WAYS);

    (* ram_style = "distributed" *) reg [31:0]              data_array  [0:ARRAY_DEPTH - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0]       tagv_array   [0:ARRAY_DEPTH - 1];   // 合并 tag & valid 放至最高位
    reg plru_state [0:LINE_NUM - 1];

    // 命中检测
    wire [WAYS - 1:0] hit_way;
    genvar way;
    generate
        for(way = 0; way < WAYS; way = way + 1) begin : hit_gen
            (* max_fanout = 10 *)
            wire [INDEX_WIDTH - 1:0] index_hit_way = cpu_pc[INDEX_WIDTH + 1:2];

            (* max_fanout = 10 *)
            wire [TAG_WIDTH:0] tagv_hit_way = tagv_array[`ARRAY_ADDR(index_hit_way, way)];
            wire [TAG_WIDTH - 1:0] tag_hit_way = tagv_hit_way[TAG_WIDTH - 1:0];
            wire valid_hit_way = tagv_hit_way[TAG_WIDTH];

            assign hit_way[way] = valid_hit_way & (tag_hit_way == tag);
        end
    endgenerate

    wire hit = |hit_way;
    wire miss = !hit;

    // 优先选择低路
    (* max_fanout = 20 *)
    wire hit_way_idx = ~hit_way[0];      // 由于只有两路直接优化判断 way0 是否命中，已有 hit 在外层做判断

    // 选择替换的路
    wire replace_way = plru_state[index];

    (* max_fanout = 20 *)
    wire [ARRAY_DEPTH - 1:0] array_raddr = `ARRAY_ADDR(index, hit_way_idx);
        (* max_fanout = 20 *)
        wire [31:0] data_rdata = data_array[array_raddr];

    always @(posedge clk) begin
        if (!pipe_hold) begin
            if (hit) begin
                cpu_inst <= data_rdata;
            end
            else begin
                cpu_inst <= mem_inst;
            end
        end
    end

    // 初始化 valid & plru
    integer i;
    initial begin
        for (i = 0; i < ARRAY_DEPTH; i = i + 1) begin
            tagv_array[i] = 0;
        end
        for (i = 0; i < LINE_NUM; i = i + 1) begin
            plru_state[i] = 3'b0;
        end
    end

    // LUT as Memory
    (* max_fanout = 30 *)
    reg [31:0] mem_inst_reg;
    reg miss_reg;
    reg [ARRAY_WIDTH - 1:0] miss_addr;
    reg [TAG_WIDTH - 1:0] miss_tag;

    always @(posedge clk) begin
        if (!pipe_hold) begin
            mem_inst_reg <= mem_inst;
        end
        if (rst & !pipe_hold & miss_reg) begin
            tagv_array[miss_addr]  <= {1'b1, miss_tag};
            data_array[miss_addr]  <= mem_inst_reg;
        end
    end

    // LUT as Logic
    always @(posedge clk) begin
        if (!rst) begin
            miss_reg    <= 1'b1;
            miss_addr   <= 0;
            miss_tag    <= 0;
        end 
        else begin
            if (!pipe_hold) begin
                miss_reg    <= miss;
                miss_addr   <= `ARRAY_ADDR(index, replace_way);
                miss_tag    <= tag;
            end

            // PLRU 更新
            if (!pipe_hold & hit) begin
                plru_state[index] <= ~replace_way;
            end
        end
    end
    `else
        assign mem_addr = cpu_pc;

        always @(posedge clk) begin
            if (!rst) begin
                cpu_inst <= `NOP;
            end
            else if (!pipe_hold) begin
                cpu_inst <= mem_inst;
            end
        end
    `endif
endmodule