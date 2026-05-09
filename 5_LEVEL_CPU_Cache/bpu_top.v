`include "rv32I.vh"

// 预测单元顶层，包含：
// 控制模块 bpu_controller.v
// 为B类型跳转使用的Gshare预测器 gshare.v
// 为返回JALR使用的RAS栈 ras.v
// 为非返回JALR使用的2路组相联BTB模块 btb.v
// 命中计数器 pred_cnt.v

module bpu_top #(
    // 分支预测
    parameter BHR_WIDTH = 10,               // BHR宽度：PHT索引根据
    parameter PHT_SIZE  = 1024,             // PHT深度

    // BTB
    parameter BTB_INDEX_WIDTH = 4,

    // RAS
    parameter RAS_DEPTH = 8
)(
    input               clk,
    input               rst,
    
    // from if
    input      [31:0]   pc_addr,            // if阶段指令地址
    input      [31:0]   pc_inst,            // if取得的指令

    // to pc & id
    output     [31:0]   pred_pc,            // 向if输出预测的地址
    output              pred_taken,         // 从PHT中读取的计数器高位值

    // from ex
    input               update_btb_en,      // ex阶段返回的BTB更新使能
    input               update_gshare_en,   // ex阶段返回的PHT更新使能
    input      [31:0]   update_pc,          // ex阶段返回更新的指令地址
    input      [31:0]   update_target,      // ex阶段返回的实际跳转地址
    input               actual_taken,       // ex阶段判断跳转为真
    input               pred_mispredict,    // ex阶段判断预测错误

    // from hazard
    input               hazard_en,
    input               dcache_stall
    
);
    // connect gshare with bpu_controller
    wire [BHR_WIDTH - 1:0]  gshare_pht_index_i;
    wire                    gshare_pred_taken_o;
    wire                    gshare_prev_b_i;
    wire [BHR_WIDTH - 1:0]  gshare_ghr_o;
    wire [BHR_WIDTH - 1:0]  gshare_ghr_d2_o;

    wire                    gshare_update_en_i;
    wire [BHR_WIDTH - 1:0]  gshare_update_pht_index_i;
    wire                    gshare_actual_taken_i;
    wire                    gshare_pred_mispredict_i;

    // connect ras with bpu_controller
    wire                    ras_push_en_i;
    wire                    ras_pop_en_i;
    wire [31:0]             ras_push_addr_i;

    wire [31:0]             ras_pop_addr_o;
    wire                    ras_isempty_o;
    wire                    ras_isfull_o;

    // connect btb with bpu_controller
    wire [BTB_INDEX_WIDTH - 1:0]        btb_query_index_i;
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_query_tag_i;
    wire                                btb_hit_o;
    wire [31:0]                         btb_target_pc_o;

    wire                                btb_update_en_i;
    wire [BTB_INDEX_WIDTH - 1:0]        btb_update_index_i;
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_i;
    wire [31:0]                         btb_update_target_i;

    bpu_controller #(
        .BHR_WIDTH          (BHR_WIDTH),
        .PHT_SIZE           (PHT_SIZE),

        .BTB_INDEX_WIDTH    (BTB_INDEX_WIDTH),

        .RAS_DEPTH          (RAS_DEPTH)
    ) BPU_CTRL(
        .clk                        (clk),
        .rst                        (rst),

        // from  if
        .pc_addr                    (pc_addr),
        .pc_inst                    (pc_inst),
        
        // to pc & id
        .pred_pc                    (pred_pc),
        .pred_taken                 (pred_taken),

        // from ex
        .update_btb_en              (update_btb_en),
        .update_gshare_en           (update_gshare_en),
        .update_pc                  (update_pc),
        .update_target              (update_target),
        .actual_taken               (actual_taken),
        .pred_mispredict            (pred_mispredict),

        // from hazard
        .hazard_en                  (hazard_en),
        .dcache_stall               (dcache_stall),

        // Gshare - 查询
        .gshare_pht_index           (gshare_pht_index_i),
        .gshare_prev_b              (gshare_prev_b_i),
        .gshare_pred_taken          (gshare_pred_taken_o),
        .gshare_ghr                 (gshare_ghr_o),
        .gshare_ghr_d2              (gshare_ghr_d2_o),

        // Gshare - 更新
        .gshare_update_en           (gshare_update_en_i),
        .gshare_update_pht_index    (gshare_update_pht_index_i),
        .gshare_actual_taken        (gshare_actual_taken_i),
        .gshare_pred_mispredict     (gshare_pred_mispredict_i),

        // ras - to bpu_controller
        .ras_push_en                (ras_push_en_i),
        .ras_pop_en                 (ras_pop_en_i),
        .ras_push_addr              (ras_push_addr_i),

        // ras - from bpu_controller
        .ras_pop_addr               (ras_pop_addr_o),
        .ras_isempty                (ras_isempty_o),
        .ras_isfull                 (ras_isfull_o),

        // btb - 查询
        .btb_query_index            (btb_query_index_i),
        .btb_query_tag              (btb_query_tag_i),
        .btb_hit                    (btb_hit_o),
        .btb_target_pc              (btb_target_pc_o),

        // btb - 更新
        .btb_update_en              (btb_update_en_i),
        .btb_update_index           (btb_update_index_i),
        .btb_update_tag             (btb_update_tag_i),
        .btb_update_target          (btb_update_target_i)
    );

    gshare #(
        .BHR_WIDTH  (BHR_WIDTH),
        .PHT_SIZE   (PHT_SIZE)
    ) GSHARE(
        .clk                        (clk),
        .rst                        (rst),
    
        // 查询
        .pht_index_i                (gshare_pht_index_i),
        .prev_b                     (gshare_prev_b_i),
        .pred_taken_o               (gshare_pred_taken_o),
        .gshare_ghr_o               (gshare_ghr_o),
        .gshare_ghr_d2_o            (gshare_ghr_d2_o),

        // 更新
        .update_en_i                (gshare_update_en_i),
        .update_pht_index_i         (gshare_update_pht_index_i),
        .actual_taken_i             (gshare_actual_taken_i),
        .pred_mispredict_i          (gshare_pred_mispredict_i)
    );

    ras #(
        .DEPTH  (RAS_DEPTH)
    ) RAS(
        .clk                        (clk),
        .rst                        (rst),

        // from bpu_controller
        .push_en_i                  (ras_push_en_i),
        .pop_en_i                   (ras_pop_en_i),
        .push_addr_i                (ras_push_addr_i),

        // to bpu_controller
        .pop_addr_o                 (ras_pop_addr_o),
        .isempty_o                  (ras_isempty_o),
        .isfull_o                   (ras_isfull_o)
    );

    btb #(
        .INDEX_WIDTH (BTB_INDEX_WIDTH)
    ) BTB(
        .clk                        (clk),
        .rst                        (rst),
    
        // 查询
        .query_index_i              (btb_query_index_i),
        .query_tag_i                (btb_query_tag_i),
        .hit_o                      (btb_hit_o),
        .target_pc_o                (btb_target_pc_o),
    
        // 更新
        .update_en_i                (btb_update_en_i),
        .update_index_i             (btb_update_index_i),
        .update_tag_i               (btb_update_tag_i),
        .update_target_i            (btb_update_target_i)
    );

    pred_cnt PRED_CNT(
        .clk                        (clk),
        .rst                        (rst),

        .update_btb_en              (update_btb_en),
        .update_gshare_en           (update_gshare_en),
        .pred_mispredict            (pred_mispredict)
    );

endmodule