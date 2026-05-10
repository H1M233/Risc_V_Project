`include "ooo_defs.vh"

module lsu_ooo (
    input               clk,
    input               rst,

    input               mem_push_0,
    input  [4:0]        push_rd_0,
    input               push_wen_0,
    input  [4:0]        push_rob_tag_0,
    input               push_is_load_0,
    input               push_is_store_0,
    input  [31:0]       push_rs1_val_0,
    input               push_rs1_ready_0,
    input  [4:0]        push_rs1_tag_0,
    input  [31:0]       push_rs2_val_0,
    input               push_rs2_ready_0,
    input  [4:0]        push_rs2_tag_0,
    input  [31:0]       push_imm_0,
    input  [1:0]        push_mem_size_0,
    input               push_mem_unsigned_0,

    input               mem_push_1,
    input  [4:0]        push_rd_1,
    input               push_wen_1,
    input  [4:0]        push_rob_tag_1,
    input               push_is_load_1,
    input               push_is_store_1,
    input  [31:0]       push_rs1_val_1,
    input               push_rs1_ready_1,
    input  [4:0]        push_rs1_tag_1,
    input  [31:0]       push_rs2_val_1,
    input               push_rs2_ready_1,
    input  [4:0]        push_rs2_tag_1,
    input  [31:0]       push_imm_1,
    input  [1:0]        push_mem_size_1,
    input               push_mem_unsigned_1,

    input               cdb_valid_0,
    input  [4:0]        cdb_tag_0,
    input  [31:0]       cdb_value_0,
    input               cdb_valid_1,
    input  [4:0]        cdb_tag_1,
    input  [31:0]       cdb_value_1,

    output reg          dcache_req_load,
    output reg          dcache_req_store,
    output reg [1:0]    dcache_mask,
    output reg [31:0]   dcache_addr,
    output reg [31:0]   dcache_wdata,
    input      [31:0]   dcache_rdata,
    input               dcache_stall,
    input               dcache_ack,

    output              load_wb_valid,
    output [4:0]        load_wb_tag,
    output [31:0]       load_wb_value,
    input               load_wb_grant,

    input               store_commit_req,
    input  [4:0]        store_commit_rob_tag,

    output reg          store_done,
    output reg [4:0]    store_done_tag,

    output [4:0]        free_count,
    input               flush
);

    localparam DEPTH = `LSQ_SIZE;
    localparam [4:0] DEPTH_COUNT = `LSQ_SIZE;

    reg         vld      [0:DEPTH-1];
    reg         is_ld    [0:DEPTH-1];
    reg         is_st    [0:DEPTH-1];
    reg  [4:0]  rob      [0:DEPTH-1];
    reg  [4:0]  rd_r     [0:DEPTH-1];
    reg         wen_r    [0:DEPTH-1];
    reg  [31:0] addr     [0:DEPTH-1];
    reg  [31:0] data     [0:DEPTH-1];
    reg  [1:0]  msz      [0:DEPTH-1];
    reg         musig    [0:DEPTH-1];
    reg         addr_rdy [0:DEPTH-1];
    reg         data_rdy [0:DEPTH-1];
    reg  [4:0]  r1_tag   [0:DEPTH-1];
    reg  [4:0]  r2_tag   [0:DEPTH-1];

    reg [2:0] head;
    reg [2:0] tail;
    reg [3:0] count;

    assign free_count = DEPTH_COUNT - {1'b0, count};

    reg        load_wb_pending;
    reg [4:0]  load_wb_tag_p;
    reg [31:0] load_wb_val_p;

    assign load_wb_valid = load_wb_pending;
    assign load_wb_tag = load_wb_tag_p;
    assign load_wb_value = load_wb_val_p;

    localparam S_IDLE  = 2'd0;
    localparam S_LOAD  = 2'd1;
    localparam S_STORE = 2'd2;
    localparam S_WAIT  = 2'd3;
    reg [1:0] state;

    wire head_valid    = vld[head];
    wire head_is_load  = is_ld[head];
    wire head_is_store = is_st[head];
    wire head_addr_rdy = addr_rdy[head];
    wire head_data_rdy = data_rdy[head];

    function [31:0] load_ext;
        input [31:0] raw;
        input [1:0]  msize;
        input        munsig;
        begin
            case (msize)
                2'b00: load_ext = munsig ? {24'b0, raw[7:0]} :
                                      {{24{raw[7]}}, raw[7:0]};
                2'b01: load_ext = munsig ? {16'b0, raw[15:0]} :
                                      {{16{raw[15]}}, raw[15:0]};
                2'b10: load_ext = raw;
                default: load_ext = raw;
            endcase
        end
    endfunction

    wire pushA_valid = mem_push_0 || mem_push_1;
    wire pushB_valid = mem_push_0 && mem_push_1;

    wire [4:0]  pushA_rd       = mem_push_0 ? push_rd_0 : push_rd_1;
    wire        pushA_wen      = mem_push_0 ? push_wen_0 : push_wen_1;
    wire [4:0]  pushA_rob_tag  = mem_push_0 ? push_rob_tag_0 : push_rob_tag_1;
    wire        pushA_is_load  = mem_push_0 ? push_is_load_0 : push_is_load_1;
    wire        pushA_is_store = mem_push_0 ? push_is_store_0 : push_is_store_1;
    wire [31:0] pushA_rs1_val  = mem_push_0 ? push_rs1_val_0 : push_rs1_val_1;
    wire        pushA_rs1_ready= mem_push_0 ? push_rs1_ready_0 : push_rs1_ready_1;
    wire [4:0]  pushA_rs1_tag  = mem_push_0 ? push_rs1_tag_0 : push_rs1_tag_1;
    wire [31:0] pushA_rs2_val  = mem_push_0 ? push_rs2_val_0 : push_rs2_val_1;
    wire        pushA_rs2_ready= mem_push_0 ? push_rs2_ready_0 : push_rs2_ready_1;
    wire [4:0]  pushA_rs2_tag  = mem_push_0 ? push_rs2_tag_0 : push_rs2_tag_1;
    wire [31:0] pushA_imm      = mem_push_0 ? push_imm_0 : push_imm_1;
    wire [1:0]  pushA_msz      = mem_push_0 ? push_mem_size_0 : push_mem_size_1;
    wire        pushA_musig    = mem_push_0 ? push_mem_unsigned_0 : push_mem_unsigned_1;

    wire pushA_r1_cdb0 = !pushA_rs1_ready && cdb_valid_0 && (pushA_rs1_tag == cdb_tag_0);
    wire pushA_r1_cdb1 = !pushA_rs1_ready && cdb_valid_1 && (pushA_rs1_tag == cdb_tag_1);
    wire pushA_r2_cdb0 = pushA_is_store && !pushA_rs2_ready && cdb_valid_0 && (pushA_rs2_tag == cdb_tag_0);
    wire pushA_r2_cdb1 = pushA_is_store && !pushA_rs2_ready && cdb_valid_1 && (pushA_rs2_tag == cdb_tag_1);
    wire pushB_r1_cdb0 = !push_rs1_ready_1 && cdb_valid_0 && (push_rs1_tag_1 == cdb_tag_0);
    wire pushB_r1_cdb1 = !push_rs1_ready_1 && cdb_valid_1 && (push_rs1_tag_1 == cdb_tag_1);
    wire pushB_r2_cdb0 = push_is_store_1 && !push_rs2_ready_1 && cdb_valid_0 && (push_rs2_tag_1 == cdb_tag_0);
    wire pushB_r2_cdb1 = push_is_store_1 && !push_rs2_ready_1 && cdb_valid_1 && (push_rs2_tag_1 == cdb_tag_1);

    wire [2:0] tail_p1 = tail + 3'd1;
    wire [1:0] push_cnt = {1'b0, pushA_valid} + {1'b0, pushB_valid};
    wire       will_pop = (state == S_WAIT) && dcache_ack;

    integer i;
    always @(posedge clk) begin
        if (!rst || flush) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                vld[i] <= 1'b0;
                is_ld[i] <= 1'b0;
                is_st[i] <= 1'b0;
                addr_rdy[i] <= 1'b0;
                data_rdy[i] <= 1'b0;
            end
            head <= 3'b0;
            tail <= 3'b0;
            count <= 4'b0;
            state <= S_IDLE;
            dcache_req_load <= 1'b0;
            dcache_req_store <= 1'b0;
            dcache_mask <= 2'b0;
            dcache_addr <= 32'b0;
            dcache_wdata <= 32'b0;
            load_wb_pending <= 1'b0;
            load_wb_tag_p <= 5'b0;
            load_wb_val_p <= 32'b0;
            store_done <= 1'b0;
            store_done_tag <= 5'b0;
        end else begin
            store_done <= 1'b0;

            if (load_wb_pending && load_wb_grant)
                load_wb_pending <= 1'b0;

            for (i = 0; i < DEPTH; i = i + 1) begin
                if (vld[i] && !addr_rdy[i]) begin
                    if (cdb_valid_0 && (cdb_tag_0 == r1_tag[i])) begin
                        addr_rdy[i] <= 1'b1;
                        addr[i] <= cdb_value_0 + addr[i];
                    end else if (cdb_valid_1 && (cdb_tag_1 == r1_tag[i])) begin
                        addr_rdy[i] <= 1'b1;
                        addr[i] <= cdb_value_1 + addr[i];
                    end
                end
                if (vld[i] && is_st[i] && !data_rdy[i]) begin
                    if (cdb_valid_0 && (cdb_tag_0 == r2_tag[i])) begin
                        data_rdy[i] <= 1'b1;
                        data[i] <= cdb_value_0;
                    end else if (cdb_valid_1 && (cdb_tag_1 == r2_tag[i])) begin
                        data_rdy[i] <= 1'b1;
                        data[i] <= cdb_value_1;
                    end
                end
            end

            if (pushA_valid) begin
                vld[tail] <= 1'b1;
                is_ld[tail] <= pushA_is_load;
                is_st[tail] <= pushA_is_store;
                rob[tail] <= pushA_rob_tag;
                rd_r[tail] <= pushA_rd;
                wen_r[tail] <= pushA_wen && (pushA_rd != 5'b0);
                msz[tail] <= pushA_msz;
                musig[tail] <= pushA_musig;
                r1_tag[tail] <= pushA_rs1_tag;
                r2_tag[tail] <= pushA_rs2_tag;
                if (pushA_rs1_ready || pushA_r1_cdb0 || pushA_r1_cdb1) begin
                    addr_rdy[tail] <= 1'b1;
                    addr[tail] <= (pushA_r1_cdb0 ? cdb_value_0 :
                                   pushA_r1_cdb1 ? cdb_value_1 : pushA_rs1_val) + pushA_imm;
                end else begin
                    addr_rdy[tail] <= 1'b0;
                    addr[tail] <= pushA_imm;
                end
                if (pushA_is_store) begin
                    data_rdy[tail] <= pushA_rs2_ready || pushA_r2_cdb0 || pushA_r2_cdb1;
                    data[tail] <= pushA_r2_cdb0 ? cdb_value_0 :
                                  pushA_r2_cdb1 ? cdb_value_1 : pushA_rs2_val;
                end else begin
                    data_rdy[tail] <= 1'b1;
                    data[tail] <= 32'b0;
                end
            end

            if (pushB_valid) begin
                vld[tail_p1] <= 1'b1;
                is_ld[tail_p1] <= push_is_load_1;
                is_st[tail_p1] <= push_is_store_1;
                rob[tail_p1] <= push_rob_tag_1;
                rd_r[tail_p1] <= push_rd_1;
                wen_r[tail_p1] <= push_wen_1 && (push_rd_1 != 5'b0);
                msz[tail_p1] <= push_mem_size_1;
                musig[tail_p1] <= push_mem_unsigned_1;
                r1_tag[tail_p1] <= push_rs1_tag_1;
                r2_tag[tail_p1] <= push_rs2_tag_1;
                if (push_rs1_ready_1 || pushB_r1_cdb0 || pushB_r1_cdb1) begin
                    addr_rdy[tail_p1] <= 1'b1;
                    addr[tail_p1] <= (pushB_r1_cdb0 ? cdb_value_0 :
                                      pushB_r1_cdb1 ? cdb_value_1 : push_rs1_val_1) + push_imm_1;
                end else begin
                    addr_rdy[tail_p1] <= 1'b0;
                    addr[tail_p1] <= push_imm_1;
                end
                if (push_is_store_1) begin
                    data_rdy[tail_p1] <= push_rs2_ready_1 || pushB_r2_cdb0 || pushB_r2_cdb1;
                    data[tail_p1] <= pushB_r2_cdb0 ? cdb_value_0 :
                                      pushB_r2_cdb1 ? cdb_value_1 : push_rs2_val_1;
                end else begin
                    data_rdy[tail_p1] <= 1'b1;
                    data[tail_p1] <= 32'b0;
                end
            end

            if (push_cnt == 2'd2)
                tail <= tail + 3'd2;
            else if (push_cnt == 2'd1)
                tail <= tail + 3'd1;

            case (state)
                S_IDLE: begin
                    dcache_req_load <= 1'b0;
                    dcache_req_store <= 1'b0;
                    if (head_valid && head_is_load && head_addr_rdy && !load_wb_pending) begin
                        dcache_req_load <= 1'b1;
                        dcache_req_store <= 1'b0;
                        dcache_addr <= addr[head];
                        dcache_mask <= msz[head];
                        dcache_wdata <= 32'b0;
                        state <= S_LOAD;
                    end else if (head_valid && head_is_store &&
                                 store_commit_req && (rob[head] == store_commit_rob_tag) &&
                                 head_addr_rdy && head_data_rdy) begin
                        dcache_req_load <= 1'b0;
                        dcache_req_store <= 1'b1;
                        dcache_addr <= addr[head];
                        dcache_mask <= msz[head];
                        dcache_wdata <= data[head];
                        state <= S_STORE;
                    end
                end

                S_LOAD: begin
                    if (!dcache_stall) begin
                        dcache_req_load <= 1'b0;
                        state <= S_WAIT;
                    end
                end

                S_STORE: begin
                    if (!dcache_stall) begin
                        dcache_req_store <= 1'b0;
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    if (dcache_ack) begin
                        if (is_ld[head]) begin
                            load_wb_pending <= 1'b1;
                            load_wb_tag_p <= rob[head];
                            load_wb_val_p <= load_ext(dcache_rdata, msz[head], musig[head]);
                        end else begin
                            store_done <= 1'b1;
                            store_done_tag <= rob[head];
                        end
                        vld[head] <= 1'b0;
                        head <= head + 3'd1;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    dcache_req_load <= 1'b0;
                    dcache_req_store <= 1'b0;
                    state <= S_IDLE;
                end
            endcase

            count <= count + {2'b0, push_cnt} - {3'b0, will_pop};
        end
    end
endmodule
