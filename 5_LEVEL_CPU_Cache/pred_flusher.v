`include "rv32I.vh"
module pred_flusher(
    input               clk,
    input               rst,
    input               pipe_hold,

    // from ex
    input               pred_flush_i,       // 来自控制单元的跳转使能信号
    input      [31:0]   pred_flush_pc_i,    // 来自控制单元的跳转地址输入

    // to if_id, id_ex, pc
    (* max_fanout = 10 *)
    output reg          pred_flush_r_o,     // 传递给各模块的跳转使能信号
    (* max_fanout = 10 *)
    output reg [31:0]   pred_flush_pc_r_o   // 传递给PC模块的跳转地址输入
);
    always @(posedge clk) begin: Pred_Flusher
        if (!rst) begin
            pred_flush_r_o     <= 1'b0;
            pred_flush_pc_r_o  <= 32'b0;
        end
        else if (!pipe_hold) begin
            pred_flush_r_o     <= pred_flush_i;
            pred_flush_pc_r_o  <= pred_flush_pc_i;
        end
    end
endmodule