`include "rv32I.vh"

// 为非返回 JALR 使用的直接映射 BTB 模块
// 直接映射准确率足够（基本上99%，不影响速度）

module btb #(
    parameter INDEX_WIDTH = 4,                  // 截取地址长度
    parameter TAG_WIDTH = (30 - INDEX_WIDTH)    // tag 宽度
)(
    input   clk,
    input   rst,
    
    // 查询
    input      [INDEX_WIDTH - 1:0]  slot0_query_index_i,
    input      [INDEX_WIDTH - 1:0]  slot1_query_index_i,
    input      [TAG_WIDTH - 1:0]    slot0_query_tag_i,
    input      [TAG_WIDTH - 1:0]    slot1_query_tag_i,
    output                          slot0_hit_o,              // 返回是否命中
    output                          slot1_hit_o,
    output     [31:0]               slot0_target_pc_o,        // 返回预测的目标地址
    output     [31:0]               slot1_target_pc_o,
    
    // 更新
    input                           update_en_i,        // ex 阶段返回的BTB更新使能
    input      [INDEX_WIDTH - 1:0]  update_index_i,
    input      [TAG_WIDTH - 1:0]    update_tag_i,
    input      [31:0]               update_target_i     // ex 阶段返回的实际目标地址
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;             // 组数：最多记录多少历史
    
    // 存储结构：
    reg  [31:0]         target  [0:LINE_NUM - 1];      // 提供上次跳转的目标地址
    reg  [TAG_WIDTH:0]  tagv    [0:LINE_NUM - 1];      // 用于区分映射到同一索引的不同地址，最高位为 valid
    
    // 查询
    wire [TAG_WIDTH:0] slot0_tagv_query  = tagv[slot0_query_index_i];
    wire [TAG_WIDTH:0] slot1_tagv_query  = tagv[slot1_query_index_i];
    
    // 输出命中结果和目标地址
    assign slot0_hit_o       = (slot0_tagv_query == {1'b1, slot0_query_tag_i});
    assign slot1_hit_o       = (slot1_tagv_query == {1'b1, slot1_query_tag_i});
    assign slot0_target_pc_o = target[slot0_query_index_i];
    assign slot1_target_pc_o = target[slot1_query_index_i];
    
    integer i;
    initial begin
        // 复位所有状态
        for (i = 0; i < LINE_NUM; i = i + 1) begin
            tagv[i]  = 0;
        end
    end
    always_ff @(posedge clk) begin
        if (update_en_i) begin
            // 更新目标地址
            tagv[update_index_i]      <= {1'b1, update_tag_i};
            target[update_index_i]    <= update_target_i;
        end
    end
endmodule