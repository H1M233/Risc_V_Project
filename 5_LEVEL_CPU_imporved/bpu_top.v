`include "rv32I.vh"
// 预测单元：包含分支预测branch_predictor_gshare.v和返回栈ras.v
module bpu_top #(
    // 分支预测
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024,

    // RAS
    parameter RAS_DEPTH = 8
)(
    input               clk,
    input               rst,
    
    // 分支预测
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
    input               hazard_en
    
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
    wire [31:0]             btb_query_pc_i;
    wire                    btb_hit_o;
    wire [31:0]             btb_target_pc_o;

    wire                    btb_update_en_i;
    wire [31:0]             btb_update_pc_i;
    wire [31:0]             btb_update_target_i;

    bpu_controller #(
        .BHR_WIDTH  (BHR_WIDTH),
        .PHT_SIZE   (PHT_SIZE),

        .RAS_DEPTH  (RAS_DEPTH)
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
        .btb_query_pc               (btb_query_pc_i),
        .btb_hit                    (btb_hit_o),
        .btb_target_pc              (btb_target_pc_o),

        // btb - 更新
        .btb_update_en              (btb_update_en_i),
        .btb_update_pc              (btb_update_pc_i),
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
        .SETS   (16)
    ) BTB(
        .clk                        (clk),
        .rst                        (rst),
    
        // 查询
        .query_pc_i                 (btb_query_pc_i),
        .hit_o                      (btb_hit_o),
        .target_pc_o                (btb_target_pc_o),
    
        // 更新
        .update_en_i                (btb_update_en_i),
        .update_pc_i                (btb_update_pc_i),
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