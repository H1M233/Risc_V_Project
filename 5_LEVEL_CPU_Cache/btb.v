`include "rv32I.vh"

// 为非返回 JALR 使用的 2 路组相联 BTB 模块
// 即根据地址的部分位建立的历史记录表 2 路可以提升准确率

module btb #(
    parameter INDEX_WIDTH = 4,      // 截取地址长度
    parameter TAG_WIDTH   = 26,     // tag 宽度
    parameter WAYS = 2
)(
    input   clk,
    input   rst,
    
    // 查询
    input      [INDEX_WIDTH - 1:0]  query_index_i,
    input      [TAG_WIDTH - 1:0]    query_tag_i,
    output                          hit_o,              // 返回是否命中
    output     [31:0]               target_pc_o,        // 返回预测的目标地址
    
    // 更新
    input                           update_en_i,        // ex 阶段返回的BTB更新使能
    input      [INDEX_WIDTH - 1:0]  update_index_i,
    input      [TAG_WIDTH - 1:0]    update_tag_i,
    input      [31:0]               update_target_i     // ex 阶段返回的实际目标地址
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;             // 组数：最多记录多少历史
    
    // 存储结构：
    `define ARRAY_ADDR(index, way) ((index) * WAYS + way)
    localparam ARRAY_DEPTH = LINE_NUM * WAYS;   // vivado 不会推断二维数组为 memory
    localparam ARRAY_WIDTH = INDEX_WIDTH + $clog2(WAYS);

    reg  [31:0]         target  [0:ARRAY_DEPTH - 1];      // 提供上次跳转的目标地址
    reg  [TAG_WIDTH:0]  tagv    [0:ARRAY_DEPTH - 1];      // 用于区分映射到同一索引的不同地址，最高位为 valid
    reg                 lru     [0:LINE_NUM - 1];         // LRU 替换信息：每组的最近最少使用记录（0表示Way0最近被使用，1表示Way1最近被使用）
    
    // 查询
    wire [31:0] way_target [0:WAYS];
    wire [WAYS:0]  way_hit;
    genvar  w;
    generate
        for(w = 0; w < WAYS; w = w + 1) begin
            wire [TAG_WIDTH:0] tagv_hit_way = tagv[`ARRAY_ADDR(query_index_i, w)];
            wire valid_hit_way     = tagv_hit_way[TAG_WIDTH];
            wire [TAG_WIDTH - 1:0] tag_hit_way = tagv_hit_way[TAG_WIDTH - 1:0];

            assign way_target[w]    = target[query_index_i][w];
            assign way_hit[w]       = (valid_hit_way && tag_hit_way == query_tag_i);
        end
    endgenerate
    
    // 输出命中结果和目标地址（优先Way0）
    assign hit_o       =    |way_hit;
    assign target_pc_o =    (way_hit[0]) ? way_target[0] : 
                            (way_hit[1]) ? way_target[1] : 32'b0;
    
    // 更新
    wire replace_way = lru[update_index_i];  // 替换最近最少使用的路
    
    integer i;
    initial begin
        // 复位所有状态
        for (i = 0; i < ARRAY_DEPTH; i = i + 1) begin
            tagv[i]  = 0;
        end
        for (i = 0; i < LINE_NUM; i = i + 1) begin
            lru[i] = 1'b0;
        end
    end
    always @(posedge clk) begin
        if (rst & update_en_i) begin
            // 更新目标地址
            tagv[`ARRAY_ADDR(update_index_i, replace_way)]      <= {1'b1, update_tag_i};
            target[`ARRAY_ADDR(update_index_i, replace_way)]    <= update_target_i;

            // 更新 LRU
            lru[update_index_i] <= ~replace_way;
        end
    end
endmodule