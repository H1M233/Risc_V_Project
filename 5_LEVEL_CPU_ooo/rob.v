`include "ooo_defs.vh"

module rob (
    input               clk,
    input               rst,

    input               alloc_0,
    input               alloc_1,
    input  [31:0]       alloc_pc_0,
    input  [31:0]       alloc_pc_1,
    input  [31:0]       alloc_inst_0,
    input  [31:0]       alloc_inst_1,
    input  [4:0]        alloc_rd_0,
    input  [4:0]        alloc_rd_1,
    input               alloc_wen_0,
    input               alloc_wen_1,
    input               alloc_is_store_0,
    input               alloc_is_store_1,
    input               alloc_is_load_0,
    input               alloc_is_load_1,
    output [4:0]        alloc_tag_0,
    output [4:0]        alloc_tag_1,
    output              rob_full,
    output              rob_almost_full,
    output [`ROB_IDX_WIDTH:0] rob_count,
    output [`ROB_IDX_WIDTH:0] rob_free_count,

    input               wb_en_0,
    input  [4:0]        wb_tag_0,
    input  [31:0]       wb_value_0,
    input               wb_en_1,
    input  [4:0]        wb_tag_1,
    input  [31:0]       wb_value_1,

    output              commit_en_0,
    output [4:0]        commit_tag_0,
    output [4:0]        commit_rd_0,
    output [31:0]       commit_value_0,
    output              commit_wen_0,
    output              commit_is_store_0,
    output [31:0]       commit_pc_0,

    output              commit_en_1,
    output [4:0]        commit_tag_1,
    output [4:0]        commit_rd_1,
    output [31:0]       commit_value_1,
    output              commit_wen_1,
    output              commit_is_store_1,
    output [31:0]       commit_pc_1,

    output              store_commit_req,
    output [4:0]        store_commit_tag,
    input               store_done,
    input  [4:0]        store_done_tag,

    input               flush
);

    localparam DEPTH = `ROB_SIZE;

    reg         valid   [0:DEPTH-1];
    reg         ready   [0:DEPTH-1];
    reg  [31:0] pc      [0:DEPTH-1];
    reg  [31:0] inst    [0:DEPTH-1];
    reg  [4:0]  rd      [0:DEPTH-1];
    reg         wen     [0:DEPTH-1];
    reg  [31:0] rvalue  [0:DEPTH-1];
    reg         is_store[0:DEPTH-1];
    reg         is_load [0:DEPTH-1];
    reg         store_committed [0:DEPTH-1];

    reg [4:0] head;
    reg [4:0] tail;
    reg [`ROB_IDX_WIDTH:0] count;

    wire [4:0] tail_p1 = tail + 5'd1;
    wire [4:0] head_p1 = head + 5'd1;

    assign alloc_tag_0 = tail;
    assign alloc_tag_1 = tail_p1;

    assign rob_count      = count;
    assign rob_free_count = `ROB_SIZE - count;
    assign rob_full       = (rob_free_count == 0);
    assign rob_almost_full= (rob_free_count <= 1);

    wire head_valid    = valid[head];
    wire head_ready    = ready[head];
    wire head_is_store = is_store[head];
    wire head_store_ok = store_committed[head];

    assign store_commit_req = head_valid && head_ready && head_is_store && !head_store_ok;
    assign store_commit_tag = head;

    wire head_can_commit = head_valid && head_ready && (!head_is_store || head_store_ok);
    wire slot1_can_commit = head_can_commit &&
                            valid[head_p1] &&
                            ready[head_p1] &&
                            !is_store[head_p1];

    assign commit_en_0       = head_can_commit;
    assign commit_tag_0      = head;
    assign commit_rd_0       = rd[head];
    assign commit_value_0    = rvalue[head];
    assign commit_wen_0      = wen[head];
    assign commit_is_store_0 = is_store[head];
    assign commit_pc_0       = pc[head];

    assign commit_en_1       = slot1_can_commit;
    assign commit_tag_1      = head_p1;
    assign commit_rd_1       = rd[head_p1];
    assign commit_value_1    = rvalue[head_p1];
    assign commit_wen_1      = wen[head_p1];
    assign commit_is_store_1 = is_store[head_p1];
    assign commit_pc_1       = pc[head_p1];

    wire [1:0] alloc_cnt  = {1'b0, alloc_0} + {1'b0, alloc_1};
    wire [1:0] commit_cnt = {1'b0, commit_en_0} + {1'b0, commit_en_1};

    integer i;
    always @(posedge clk) begin
        if (!rst || flush) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 1'b0;
                ready[i] <= 1'b0;
                pc[i] <= 32'b0;
                inst[i] <= 32'b0;
                rd[i] <= 5'b0;
                wen[i] <= 1'b0;
                rvalue[i] <= 32'b0;
                is_store[i] <= 1'b0;
                is_load[i] <= 1'b0;
                store_committed[i] <= 1'b0;
            end
            head <= 5'b0;
            tail <= 5'b0;
            count <= {(`ROB_IDX_WIDTH+1){1'b0}};
        end else begin
            if (wb_en_0 && valid[wb_tag_0] && !is_store[wb_tag_0]) begin
                rvalue[wb_tag_0] <= wb_value_0;
                ready[wb_tag_0] <= 1'b1;
            end
            if (wb_en_1 && valid[wb_tag_1] && !is_store[wb_tag_1]) begin
                rvalue[wb_tag_1] <= wb_value_1;
                ready[wb_tag_1] <= 1'b1;
            end

            if (store_done && valid[store_done_tag] && is_store[store_done_tag])
                store_committed[store_done_tag] <= 1'b1;

            if (commit_en_0)
                valid[head] <= 1'b0;
            if (commit_en_1)
                valid[head_p1] <= 1'b0;

            if (commit_en_1)
                head <= head + 5'd2;
            else if (commit_en_0)
                head <= head + 5'd1;

            if (alloc_0) begin
                valid[tail] <= 1'b1;
                ready[tail] <= alloc_is_store_0;
                pc[tail] <= alloc_pc_0;
                inst[tail] <= alloc_inst_0;
                rd[tail] <= alloc_rd_0;
                wen[tail] <= alloc_wen_0 && (alloc_rd_0 != 5'b0);
                rvalue[tail] <= 32'b0;
                is_store[tail] <= alloc_is_store_0;
                is_load[tail] <= alloc_is_load_0;
                store_committed[tail] <= 1'b0;
            end

            if (alloc_1) begin
                valid[tail_p1] <= 1'b1;
                ready[tail_p1] <= alloc_is_store_1;
                pc[tail_p1] <= alloc_pc_1;
                inst[tail_p1] <= alloc_inst_1;
                rd[tail_p1] <= alloc_rd_1;
                wen[tail_p1] <= alloc_wen_1 && (alloc_rd_1 != 5'b0);
                rvalue[tail_p1] <= 32'b0;
                is_store[tail_p1] <= alloc_is_store_1;
                is_load[tail_p1] <= alloc_is_load_1;
                store_committed[tail_p1] <= 1'b0;
            end

            if (alloc_1)
                tail <= tail + 5'd2;
            else if (alloc_0)
                tail <= tail + 5'd1;

            count <= count + {4'b0, alloc_cnt} - {4'b0, commit_cnt};
        end
    end
endmodule
