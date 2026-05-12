`include "rv32I.vh"

// 为非返回 JALR 使用的 2 路组相联 BTB 模块
// 即根据地址的部分位建立的历史记录表 2 路可以提升准确率

module btb #(
    parameter INDEX_WIDTH = 4               // 截取地址长度
)(
    input   clk,
    input   rst,
    
    // 查询
    input      [INDEX_WIDTH - 1:0]          query_index_i,
    input      [31 - INDEX_WIDTH - 2:0]     query_tag_i,
    output                                  hit_o,              // 返回是否命中
    output     [31:0]                       target_pc_o,        // 返回预测的目标地址
    
    // 更新
    input                                   update_en_i,        // ex 阶段返回的BTB更新使能
    input      [INDEX_WIDTH - 1:0]          update_index_i,
    input      [31 - INDEX_WIDTH - 2:0]     update_tag_i,
    input      [31:0]                       update_target_i     // ex 阶段返回的实际目标地址
);
    localparam SETS = 2 ** INDEX_WIDTH;     // 组数：最多记录多少历史
    
    // 存储结构：
    reg                             valid   [0:SETS - 1][0:1];      // 标记BTB是否有效（即非初始化状态）
    reg  [31 - INDEX_WIDTH - 2:0]   tag     [0:SETS - 1][0:1];      // 用于区分映射到同一索引的不同地址
    reg  [31:0]                     target  [0:SETS - 1][0:1];      // 提供上次跳转的目标地址
    reg                             lru     [0:SETS - 1];           // LRU 替换信息：每组的最近最少使用记录（0表示Way0最近被使用，1表示Way1最近被使用）
    
    // 查询
    wire                            way_valid   [0:1];
    wire [31 - INDEX_WIDTH - 2:0]   way_tag     [0:1];
    wire [31:0]                     way_target  [0:1];
    wire                            way_hit     [0:1];
    genvar  w;
    generate
        for(w = 0; w < 2; w = w + 1) begin
            assign way_valid[w]     = valid[query_index_i][w];
            assign way_tag[w]       = tag[query_index_i][w];
            assign way_target[w]    = target[query_index_i][w];
            assign way_hit[w]       = (way_valid[w] && way_tag[w] == query_tag_i);
        end
    endgenerate
    
    // 输出命中结果和目标地址（优先Way0）
    assign hit_o       =    (way_hit[0] | way_hit[1]);
    assign target_pc_o =    (way_hit[0]) ? way_target[0] : 
                            (way_hit[1]) ? way_target[1] : 32'b0;
    
    // 更新
    // 查找是否有空闲路或需要替换的路
    wire    update_way_valid    [0:1];
    wire    update_way_hit      [0:1];
    generate
        for(w = 0; w < 2; w = w + 1) begin
            assign update_way_valid[w]  = valid[update_index_i][w];
            assign update_way_hit[w]    = update_way_valid[w] && (tag[update_index_i][w] == update_tag_i);
        end
    endgenerate
    
    // 选择要更新的路0: Way0, 1: Way1
    // 替换策略：
    // 1. 如果命中某路，更新该路
    // 2. 如果有无效路，使用无效路
    // 3. 否则根据 LRU 替换
    wire replace_way    =   (update_way_hit[0] || !update_way_valid[0]) ? 1'b0 :
                            (update_way_hit[1] || !update_way_valid[1]) ? 1'b1 :
                            lru[update_index_i];  // 替换最近最少使用的路
    
    integer i, j;
    always @(posedge clk) begin
        if (!rst) begin
            // 复位所有状态
            for (i = 0; i < SETS; i = i + 1) begin
                lru[i] <= 1'b0;
                for (j = 0; j < 2; j = j + 1) begin
                    valid[i][j]  <= 1'b0;
                end
            end
        end 
        else if (update_en_i) begin
            // 更新目标地址
            valid[update_index_i][replace_way]    <= 1'b1;
            tag[update_index_i][replace_way]      <= update_tag_i;
            target[update_index_i][replace_way]   <= update_target_i;

            // 更新 LRU
            lru[update_index_i]                   <= ~replace_way;
        end
    end
endmodule