module ex_bpu(
    input               rst,
    input               clk,

    input               pipe_flush,
    input               pipe_hold,

    input               slot0_update_ras_i,
    input               slot1_update_ras_i,
    input      [3:0]    slot0_ras_snapshot_i,
    input      [3:0]    slot1_ras_snapshot_i,
    input               slot0_update_gshare_en_i,
    input               slot0_actual_taken_i,
    input      [31:0]   slot0_update_pc_i,
    input      [31:0]   slot1_update_pc_i,
    input               slot0_update_btb_en_i,
    input               slot1_update_btb_en_i,
    input      [31:0]   slot0_update_target_i,
    input      [31:0]   slot1_update_target_i,

    input  logic        slot0_pred_flush_en_i,
    input  logic        slot1_pred_flush_en_i,
    input  logic [31:0] slot0_pred_flush_pc_i,
    input  logic [31:0] slot1_pred_flush_pc_i,

    output reg          update_ras_o,
    output reg [3:0]    ras_snapshot_o,
    output reg          update_gshare_en_o,
    output reg          actual_taken_o,
    output reg          update_btb_en_o,
    output reg [31:0]   update_target_o,
    output reg [31:0]   btb_update_pc_o,
    output reg [31:0]   gshare_update_pc_o,

    output logic        slot0_pred_flush_en_o,
    output logic        slot1_pred_flush_en_o,
    output logic [31:0] slot0_pred_flush_pc_o,
    output logic [31:0] slot1_pred_flush_pc_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_pred_flush_en_o   <= 0;
            slot1_pred_flush_en_o   <= 0;
            slot0_pred_flush_pc_o   <= 0;
            slot1_pred_flush_pc_o   <= 0;

        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin            
            slot0_pred_flush_en_o   <= 0;
            slot1_pred_flush_en_o   <= 0;
            slot0_pred_flush_pc_o   <= 0;
            slot1_pred_flush_pc_o   <= 0;
        end
        else begin
            slot0_pred_flush_en_o   <= slot0_pred_flush_en_i;
            slot1_pred_flush_en_o   <= slot1_pred_flush_en_i;
            slot0_pred_flush_pc_o   <= slot0_pred_flush_pc_i;
            slot1_pred_flush_pc_o   <= slot1_pred_flush_pc_i;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst) begin
            update_ras_o            <= 0;
            ras_snapshot_o          <= 0;
            update_gshare_en_o      <= 0;
            actual_taken_o          <= 0;
            update_btb_en_o         <= 0;
            update_target_o         <= 0;
            btb_update_pc_o         <= 0;
            gshare_update_pc_o      <= 0;
        end
        else if (pipe_flush) begin
            update_ras_o            <= 0;
            ras_snapshot_o          <= 0;
            update_gshare_en_o      <= 0;
            actual_taken_o          <= 0;
            update_btb_en_o         <= 0;
            update_target_o         <= 0;
            btb_update_pc_o         <= 0;
            gshare_update_pc_o      <= 0;
        end
        else begin
            // ras 栈恢复
            update_ras_o            <= slot0_update_ras_i || slot1_update_ras_i;
            ras_snapshot_o          <= (slot0_update_ras_i) ? slot0_ras_snapshot_i : slot1_ras_snapshot_i;
            // Gshare 更新
            update_gshare_en_o      <= slot0_update_gshare_en_i;
            actual_taken_o          <= slot0_actual_taken_i;
            
            // BTB 更新
            update_btb_en_o         <= slot0_update_btb_en_i || slot1_update_btb_en_i;
            update_target_o         <= (slot0_update_btb_en_i) ? slot0_update_target_i : slot1_update_target_i;
            btb_update_pc_o         <= (slot0_update_btb_en_i) ? slot0_update_pc_i : slot1_update_pc_i;

            // 更新目标 pc
            gshare_update_pc_o      <= (slot0_update_gshare_en_i) ? slot0_update_pc_i : slot1_update_pc_i;
        end
    end
endmodule