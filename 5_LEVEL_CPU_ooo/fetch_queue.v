`include "ooo_defs.vh"

module fetch_queue (
    input               clk,
    input               rst,
    input               push_en,
    input   [31:0]      push_pc,
    input   [31:0]      push_inst,
    input               push_pred_taken,
    input   [31:0]      push_pred_pc,
    input   [1:0]       pop_count,
    output  [31:0]      pop_pc_0,
    output  [31:0]      pop_inst_0,
    output              pop_valid_0,
    output              pop_pred_taken_0,
    output  [31:0]      pop_pred_pc_0,
    output  [31:0]      pop_pc_1,
    output  [31:0]      pop_inst_1,
    output              pop_valid_1,
    output              pop_pred_taken_1,
    output  [31:0]      pop_pred_pc_1,
    output              empty,
    output              almost_full,
    output              full,
    input               flush
);
    localparam DEPTH = 8;
    localparam AW = 3;

    reg [31:0] pc_mem  [0:DEPTH-1];
    reg [31:0] inst_mem[0:DEPTH-1];
    reg        pt_mem  [0:DEPTH-1];
    reg [31:0] ppc_mem [0:DEPTH-1];

    reg [AW:0] head, tail;
    wire [AW:0] count = tail - head;

    assign empty       = (count == 0);
    assign full        = (count == DEPTH);
    assign almost_full = full;

    assign pop_valid_0      = (count >= 1);
    assign pop_pc_0         = pc_mem  [head[AW-1:0]];
    assign pop_inst_0       = inst_mem[head[AW-1:0]];
    assign pop_pred_taken_0 = pt_mem  [head[AW-1:0]];
    assign pop_pred_pc_0    = ppc_mem [head[AW-1:0]];

    wire [AW:0] h1 = head + 1;
    assign pop_valid_1      = (count >= 2);
    assign pop_pc_1         = pc_mem  [h1[AW-1:0]];
    assign pop_inst_1       = inst_mem[h1[AW-1:0]];
    assign pop_pred_taken_1 = pt_mem  [h1[AW-1:0]];
    assign pop_pred_pc_1    = ppc_mem [h1[AW-1:0]];

    wire [AW:0] pop_req = {1'b0, pop_count};
    wire [AW:0] actual_pop = (pop_req > count) ? count : pop_req;

    always @(posedge clk) begin
        if (!rst || flush) begin
            head <= 0;
            tail <= 0;
        end else begin
            if (push_en && !full) begin
                pc_mem  [tail[AW-1:0]] <= push_pc;
                inst_mem[tail[AW-1:0]] <= push_inst;
                pt_mem  [tail[AW-1:0]] <= push_pred_taken;
                ppc_mem [tail[AW-1:0]] <= push_pred_pc;
                tail <= tail + 1;
            end
            head <= head + actual_pop;
        end
    end
endmodule
