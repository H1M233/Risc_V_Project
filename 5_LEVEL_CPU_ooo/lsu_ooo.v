`include "ooo_defs.vh"

module lsu_ooo #(
    parameter USE_STORE_BUFFER = 1,
    parameter USE_LOAD_STORE_FORWARD = 1,
    parameter STORE_BUFFER_DEPTH = 4
)(
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
    reg  [31:0] imm_save [0:DEPTH-1];
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

    localparam S_IDLE  = 3'd0;
    localparam S_LOAD  = 3'd1;
    localparam S_STORE = 3'd2;
    localparam S_WAIT  = 3'd3;
    localparam S_WB    = 3'd4;
    reg [2:0] state;
    reg       active_sbuf_store;

    localparam [2:0] SBUF_DEPTH_COUNT = STORE_BUFFER_DEPTH;
    reg        sb_v    [0:STORE_BUFFER_DEPTH-1];
    reg [4:0]  sb_rob  [0:STORE_BUFFER_DEPTH-1];
    reg [31:0] sb_addr [0:STORE_BUFFER_DEPTH-1];
    reg [31:0] sb_data [0:STORE_BUFFER_DEPTH-1];
    reg [1:0]  sb_mask [0:STORE_BUFFER_DEPTH-1];
    reg [1:0]  sb_head;
    reg [1:0]  sb_tail;
    reg [2:0]  sb_count;

    localparam [1:0] SBUF_LAST = SBUF_DEPTH_COUNT[1:0] - 2'd1;
    wire sbuf_empty = (sb_count == 3'b0);
    wire sbuf_full  = (sb_count == SBUF_DEPTH_COUNT);

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

    function [3:0] lane_mask;
        input [1:0] size;
        input [1:0] addr_low;
        begin
            case (size)
                2'b00: begin
                    case (addr_low)
                        2'b00: lane_mask = 4'b0001;
                        2'b01: lane_mask = 4'b0010;
                        2'b10: lane_mask = 4'b0100;
                        2'b11: lane_mask = 4'b1000;
                        default: lane_mask = 4'b0000;
                    endcase
                end
                2'b01: lane_mask = addr_low[1] ? 4'b1100 : 4'b0011;
                2'b10: lane_mask = 4'b1111;
                default: lane_mask = 4'b0000;
            endcase
        end
    endfunction

    function [31:0] store_align;
        input [31:0] wdata;
        input [1:0]  size;
        input [1:0]  addr_low;
        begin
            store_align = 32'b0;
            case (size)
                2'b00: begin
                    case (addr_low)
                        2'b00: store_align[7:0]   = wdata[7:0];
                        2'b01: store_align[15:8]  = wdata[7:0];
                        2'b10: store_align[23:16] = wdata[7:0];
                        2'b11: store_align[31:24] = wdata[7:0];
                        default: store_align = 32'b0;
                    endcase
                end
                2'b01: begin
                    if (addr_low[1])
                        store_align[31:16] = wdata[15:0];
                    else
                        store_align[15:0] = wdata[15:0];
                end
                2'b10: store_align = wdata;
                default: store_align = 32'b0;
            endcase
        end
    endfunction

    function [31:0] load_shift_raw;
        input [31:0] word;
        input [1:0]  size;
        input [1:0]  addr_low;
        begin
            case (size)
                2'b00: begin
                    case (addr_low)
                        2'b00: load_shift_raw = {24'b0, word[7:0]};
                        2'b01: load_shift_raw = {24'b0, word[15:8]};
                        2'b10: load_shift_raw = {24'b0, word[23:16]};
                        2'b11: load_shift_raw = {24'b0, word[31:24]};
                        default: load_shift_raw = 32'b0;
                    endcase
                end
                2'b01: load_shift_raw = addr_low[1] ? {16'b0, word[31:16]} :
                                                       {16'b0, word[15:0]};
                2'b10: load_shift_raw = word;
                default: load_shift_raw = word;
            endcase
        end
    endfunction

    reg        sb_forward_valid;
    reg [31:0] sb_forward_raw;
    reg [31:0] sb_forward_word;
    reg [31:0] sb_store_word;
    reg [3:0]  sb_forward_cover;
    reg [3:0]  sb_load_need;
    reg [3:0]  sb_store_lanes;
    reg [2:0]  sb_scan_ext;
    reg [1:0]  sb_scan_idx;
    integer sb_scan_i;
    always @(*) begin
        sb_forward_valid = 1'b0;
        sb_forward_raw = 32'b0;
        sb_forward_word = 32'b0;
        sb_store_word = 32'b0;
        sb_forward_cover = 4'b0000;
        sb_load_need = 4'b0000;
        sb_store_lanes = 4'b0000;
        sb_scan_ext = 3'b0;
        sb_scan_idx = 2'b0;

        if (USE_STORE_BUFFER && USE_LOAD_STORE_FORWARD &&
            head_valid && head_is_load && head_addr_rdy && !sbuf_empty) begin
            sb_load_need = lane_mask(msz[head], addr[head][1:0]);
            for (sb_scan_i = 0; sb_scan_i < STORE_BUFFER_DEPTH; sb_scan_i = sb_scan_i + 1) begin
                sb_scan_ext = {1'b0, sb_head} + sb_scan_i[2:0];
                if (sb_scan_ext >= SBUF_DEPTH_COUNT)
                    sb_scan_ext = sb_scan_ext - SBUF_DEPTH_COUNT;
                sb_scan_idx = sb_scan_ext[1:0];
                if ((sb_scan_i[2:0] < sb_count) && sb_v[sb_scan_idx] &&
                    (sb_addr[sb_scan_idx][31:2] == addr[head][31:2])) begin
                    sb_store_lanes = lane_mask(sb_mask[sb_scan_idx], sb_addr[sb_scan_idx][1:0]);
                    sb_store_word = store_align(sb_data[sb_scan_idx], sb_mask[sb_scan_idx], sb_addr[sb_scan_idx][1:0]);
                    if (sb_store_lanes[0]) sb_forward_word[7:0]   = sb_store_word[7:0];
                    if (sb_store_lanes[1]) sb_forward_word[15:8]  = sb_store_word[15:8];
                    if (sb_store_lanes[2]) sb_forward_word[23:16] = sb_store_word[23:16];
                    if (sb_store_lanes[3]) sb_forward_word[31:24] = sb_store_word[31:24];
                    sb_forward_cover = sb_forward_cover | sb_store_lanes;
                end
            end
            if ((sb_forward_cover & sb_load_need) == sb_load_need) begin
                sb_forward_valid = 1'b1;
                sb_forward_raw = load_shift_raw(sb_forward_word, msz[head], addr[head][1:0]);
            end
        end
    end

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
    wire       store_buf_enqueue = USE_STORE_BUFFER &&
                                   (state == S_IDLE) &&
                                   head_valid && head_is_store &&
                                   store_commit_req && (rob[head] == store_commit_rob_tag) &&
                                   head_addr_rdy && head_data_rdy && !sbuf_full;
    wire       will_pop = store_buf_enqueue ||
                          ((state == S_WAIT) && dcache_ack && !active_sbuf_store && !is_ld[head]) ||
                          ((state == S_WB) && load_wb_pending && load_wb_grant);

    integer i;
    always @(posedge clk) begin
        if (!rst || flush) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                vld[i] <= 1'b0;
                is_ld[i] <= 1'b0;
                is_st[i] <= 1'b0;
                imm_save[i] <= 32'b0;
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
            active_sbuf_store <= 1'b0;
            sb_head <= 2'b0;
            sb_tail <= 2'b0;
            sb_count <= 3'b0;
            for (i = 0; i < STORE_BUFFER_DEPTH; i = i + 1) begin
                sb_v[i] <= 1'b0;
                sb_rob[i] <= 5'b0;
                sb_addr[i] <= 32'b0;
                sb_data[i] <= 32'b0;
                sb_mask[i] <= 2'b0;
            end
        end else begin
            store_done <= 1'b0;

            for (i = 0; i < DEPTH; i = i + 1) begin
                if (vld[i] && !addr_rdy[i]) begin
                    if (cdb_valid_0 && (cdb_tag_0 == r1_tag[i])) begin
                        addr_rdy[i] <= 1'b1;
                        addr[i] <= cdb_value_0 + imm_save[i];
                    end else if (cdb_valid_1 && (cdb_tag_1 == r1_tag[i])) begin
                        addr_rdy[i] <= 1'b1;
                        addr[i] <= cdb_value_1 + imm_save[i];
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
                imm_save[tail] <= pushA_imm;
                r1_tag[tail] <= pushA_rs1_tag;
                r2_tag[tail] <= pushA_rs2_tag;
                if (pushA_rs1_ready || pushA_r1_cdb0 || pushA_r1_cdb1) begin
                    addr_rdy[tail] <= 1'b1;
                    addr[tail] <= (pushA_r1_cdb0 ? cdb_value_0 :
                                   pushA_r1_cdb1 ? cdb_value_1 : pushA_rs1_val) + pushA_imm;
                end else begin
                    addr_rdy[tail] <= 1'b0;
                    addr[tail] <= 32'b0;
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
                imm_save[tail_p1] <= push_imm_1;
                r1_tag[tail_p1] <= push_rs1_tag_1;
                r2_tag[tail_p1] <= push_rs2_tag_1;
                if (push_rs1_ready_1 || pushB_r1_cdb0 || pushB_r1_cdb1) begin
                    addr_rdy[tail_p1] <= 1'b1;
                    addr[tail_p1] <= (pushB_r1_cdb0 ? cdb_value_0 :
                                      pushB_r1_cdb1 ? cdb_value_1 : push_rs1_val_1) + push_imm_1;
                end else begin
                    addr_rdy[tail_p1] <= 1'b0;
                    addr[tail_p1] <= 32'b0;
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
                    active_sbuf_store <= 1'b0;
                    if (store_buf_enqueue) begin
                        sb_v[sb_tail] <= 1'b1;
                        sb_rob[sb_tail] <= rob[head];
                        sb_addr[sb_tail] <= addr[head];
                        sb_data[sb_tail] <= data[head];
                        sb_mask[sb_tail] <= msz[head];
                        if (sb_tail == SBUF_LAST)
                            sb_tail <= 2'b0;
                        else
                            sb_tail <= sb_tail + 2'd1;
                        sb_count <= sb_count + 3'd1;
                        store_done <= 1'b1;
                        store_done_tag <= rob[head];
                        vld[head] <= 1'b0;
                        head <= head + 3'd1;
                    end else if (sb_forward_valid && !load_wb_pending) begin
                        load_wb_pending <= 1'b1;
                        load_wb_tag_p <= rob[head];
                        load_wb_val_p <= load_ext(sb_forward_raw, msz[head], musig[head]);
                        state <= S_WB;
                    end else if (USE_STORE_BUFFER && !sbuf_empty) begin
                        dcache_req_load <= 1'b0;
                        dcache_req_store <= 1'b1;
                        dcache_addr <= sb_addr[sb_head];
                        dcache_mask <= sb_mask[sb_head];
                        dcache_wdata <= sb_data[sb_head];
                        active_sbuf_store <= 1'b1;
                        state <= S_STORE;
                    end else if (head_valid && head_is_load && head_addr_rdy && !load_wb_pending) begin
                        dcache_req_load <= 1'b1;
                        dcache_req_store <= 1'b0;
                        dcache_addr <= addr[head];
                        dcache_mask <= msz[head];
                        dcache_wdata <= 32'b0;
                        state <= S_LOAD;
                    end else if (!USE_STORE_BUFFER && head_valid && head_is_store &&
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
                    if (dcache_ack) begin
                        dcache_req_load <= 1'b0;
                        load_wb_pending <= 1'b1;
                        load_wb_tag_p <= rob[head];
                        load_wb_val_p <= load_ext(dcache_rdata, msz[head], musig[head]);
                        state <= S_WB;
                    end else if (!dcache_stall) begin
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
                        if (active_sbuf_store) begin
                            sb_v[sb_head] <= 1'b0;
                            if (sb_head == SBUF_LAST)
                                sb_head <= 2'b0;
                            else
                                sb_head <= sb_head + 2'd1;
                            sb_count <= sb_count - 3'd1;
                            active_sbuf_store <= 1'b0;
                            state <= S_IDLE;
                        end else if (is_ld[head]) begin
                            load_wb_pending <= 1'b1;
                            load_wb_tag_p <= rob[head];
                            load_wb_val_p <= load_ext(dcache_rdata, msz[head], musig[head]);
                            state <= S_WB;
                        end else begin
                            store_done <= 1'b1;
                            store_done_tag <= rob[head];
                            vld[head] <= 1'b0;
                            head <= head + 3'd1;
                            state <= S_IDLE;
                        end
                    end
                end

                S_WB: begin
                    if (load_wb_pending && load_wb_grant) begin
                        load_wb_pending <= 1'b0;
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
