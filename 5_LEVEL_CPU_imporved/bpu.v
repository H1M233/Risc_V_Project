`include "rv32I.vh"
// 预测单元：包含分支预测branch_predictor_gshare.v和返回栈ras.v
module bpu #(
    // 分支预测
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024,

    // RAS
    parameter RAS_DEPTH = 8,
    parameter PTR_WIDTH = $clog2(RAS_DEPTH)
)(
    input               clk,
    input               rst,
    
    // 分支预测
    // from if
    input      [31:0]   pc_addr,            // if阶段指令地址
    input      [31:0]   pc_inst,            // pc取得的指令

    // to pc & if
    output     [31:0]   pred_pc,            // 向if输出预测的地址
    output              pred_taken,         // 从PHT中读取的计数器高位值

    // from ex
    input      [1:0]    update_en,          // ex阶段返回的0: PHT更新使能 1: BTB更新使能
    input      [31:0]   update_pc,          // ex阶段返回更新的指令地址
    input      [31:0]   update_target,      // ex阶段返回的实际跳转地址
    input               actual_taken,       // ex阶段判断跳转为真
    input               pred_mispredict     // ex阶段判断预测错误
);
    // connect ras with Gshare
    wire        ras_push_en;
    wire        ras_pop_en;
    wire [31:0] ras_push_addr;
    wire [31:0] ras_pop_addr;
    wire        ras_isempty;
    wire        ras_isfull;

    // connect btb with Gshare
    wire [31:0] btb_query_pc;
    wire        btb_hit;
    wire [31:0] btb_target_pc;

    branch_predictor_gshare #(
        .BHR_WIDTH  (BHR_WIDTH),
        .PHT_SIZE   (PHT_SIZE)
    ) GSHARE(
        .clk                (clk),
        .rst                (rst),
    
        // from pc
        .pc_addr            (pc_addr),
        .pc_inst            (pc_inst),

        // to pc & ex
        .pred_pc            (pred_pc),
        .pred_taken         (pred_taken),

        // from ex
        .update_en          (update_en[0]),
        .update_pc          (update_pc),
        .actual_taken       (actual_taken),
        .pred_mispredict    (pred_mispredict),

        // from ras
        .ras_isempty        (ras_isempty),
        .ras_isfull         (ras_isfull),
        .ras_pop_addr       (ras_pop_addr),

        // to ras
        .ras_pop_en         (ras_pop_en),
        .ras_push_en        (ras_push_en),
        .ras_push_addr      (ras_push_addr),

        // to btb
        .btb_query_pc       (btb_query_pc),

        // from btb
        .btb_hit            (btb_hit),
        .btb_target_pc      (btb_target_pc)
    );

    pred_cnt PRED_CNT(
        .clk                (clk),
        .rst                (rst),

        .update_en          (update_en),
        .pred_mispredict    (pred_mispredict)
    );

    ras #(
        .DEPTH  (RAS_DEPTH)
    ) RAS(
        .clk                (clk),
        .rst                (rst),

        // from gshare
        .push_en            (ras_push_en),
        .pop_en             (ras_pop_en),
        .push_addr_i        (ras_push_addr),

        // to gshare
        .pop_addr_o         (ras_pop_addr),
        .isempty_o          (ras_isempty),
        .isfull_o           (ras_isfull)
    );

    btb #(
        .SETS   (16)
    ) BTB(
        .clk                (clk),
        .rst                (rst),
    
        // 查询
        .query_pc           (btb_query_pc),
        .hit                (btb_hit),
        .target_pc          (btb_target_pc),
    
        // 更新
        .update_en          (update_en[1]),
        .update_pc          (update_pc),
        .update_target      (update_target)
    );

endmodule