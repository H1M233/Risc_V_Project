module ex_bpu(
    input               rst,
    input               clk,

    input               pipe_hold,
    input               pipe_flush,

    input               update_btb_en_i,
    input               update_gshare_en_i,
    input      [31:0]   update_pc_i,
    input      [31:0]   update_target_i,
    input               actual_taken_i,

    input               pred_flush_en_i,
    input      [31:0]   pred_flush_pc_i,

    output reg          update_btb_en_o,
    output reg          update_gshare_en_o,
    output reg [31:0]   update_pc_o,
    output reg [31:0]   update_target_o,
    output reg          actual_taken_o,

    output reg          pred_flush_en_o,
    output reg [31:0]   pred_flush_pc_o
);
    always @(posedge clk) begin
        if (!rst) begin
            update_btb_en_o     <= 0;
            update_gshare_en_o  <= 0;
            update_pc_o         <= 0;
            update_target_o     <= 0;
            actual_taken_o      <= 0;

            pred_flush_en_o     <= 0;
            pred_flush_pc_o     <= 0;

        end
        else if (pipe_flush) begin
            update_btb_en_o     <= 0;
            update_gshare_en_o  <= 0;
            update_pc_o         <= 0;
            update_target_o     <= 0;
            actual_taken_o      <= 0;

            pred_flush_en_o     <= 0;
            pred_flush_pc_o     <= 0;
        end
        else begin
            update_btb_en_o     <= update_btb_en_i;
            update_gshare_en_o  <= update_gshare_en_i;
            update_pc_o         <= update_pc_i;
            update_target_o     <= update_target_i;
            actual_taken_o      <= actual_taken_i;

            pred_flush_en_o     <= pred_flush_en_i;
            pred_flush_pc_o     <= pred_flush_pc_i;
        end
    end
endmodule