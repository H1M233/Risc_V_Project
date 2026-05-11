`include "rv32I.vh"

module dcache#(
    parameter USE_FAST_DCACHE = 1,
    parameter USE_SIMPLE_DCACHE_FALLBACK = 0,
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = 24,
    parameter WAYS          = 2,
    parameter LINE_WORDS    = 1
)(
    input               clk,
    input               rst,

    input               cpu_req_load,
    input               cpu_req_store,
    input      [1:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [31:0]   cpu_wdata,
    output reg [31:0]   cpu_rdata,
    output              stall,

    output reg [31:0]   mem_addr,
    output reg [3:0]    mem_we,
    output reg          mem_wen,
    output reg [31:0]   mem_wdata,
    input      [31:0]   mem_rdata,

    output reg          mem_ack,
    output reg          perf_load_hit,
    output reg          perf_load_miss
);

    localparam SETS = (1 << INDEX_WIDTH);

    reg                 valid [0:SETS-1];
    reg [TAG_WIDTH-1:0] tag   [0:SETS-1];
    reg [31:0]          data  [0:SETS-1];

    reg        req_load_q;
    reg        req_store_q;
    reg [31:0] req_addr_q;
    reg [31:0] req_wdata_q;
    reg [1:0]  req_mask_q;

    wire [INDEX_WIDTH-1:0] req_index = req_addr_q[INDEX_WIDTH+1:2];
    wire [TAG_WIDTH-1:0]   req_tag   = req_addr_q[31:INDEX_WIDTH+2];

    wire req_test_dram  = (req_addr_q >= 32'h8000_0000) &&
                          (req_addr_q <  32'h8001_0000);
    wire req_board_dram = (req_addr_q >= 32'h8010_0000) &&
                          (req_addr_q <  32'h8014_0000);
    wire req_known_mmio = (req_addr_q[31:12] == 20'h80200);
    wire req_cacheable  = (req_test_dram || req_board_dram) && !req_known_mmio;
    wire req_hit = valid[req_index] && (tag[req_index] == req_tag);
    wire hit = req_cacheable && req_hit;

    localparam IDLE            = 4'd0;
    localparam LOOKUP          = 4'd1;
    localparam LOAD_HIT_RESP   = 4'd2;
    localparam LOAD_WAIT0      = 4'd3;
    localparam LOAD_WAIT1      = 4'd4;
    localparam LOAD_WAIT2      = 4'd5;
    localparam LOAD_MISS_RESP  = 4'd6;
    localparam STORE_HOLD      = 4'd7;
    localparam STORE_ACK       = 4'd8;

    reg [3:0] state;

    assign stall = (state != IDLE);

    integer i;
    always @(posedge clk) begin
        if (!rst) begin
            state       <= IDLE;
            cpu_rdata   <= 32'b0;
            mem_addr    <= 32'b0;
            mem_we      <= 4'b0000;
            mem_wen     <= 1'b0;
            mem_wdata   <= 32'b0;
            mem_ack     <= 1'b0;
            perf_load_hit  <= 1'b0;
            perf_load_miss <= 1'b0;
            req_load_q  <= 1'b0;
            req_store_q <= 1'b0;
            req_addr_q  <= 32'b0;
            req_wdata_q <= 32'b0;
            req_mask_q  <= 2'b0;
            for (i = 0; i < SETS; i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i]   <= {TAG_WIDTH{1'b0}};
                data[i]  <= 32'b0;
            end
        end else begin
            mem_ack <= 1'b0;
            perf_load_hit  <= 1'b0;
            perf_load_miss <= 1'b0;

            case (state)
                IDLE: begin
                    mem_we  <= 4'b0000;
                    mem_wen <= 1'b0;
                    if (cpu_req_load || cpu_req_store) begin
                        req_load_q  <= cpu_req_load;
                        req_store_q <= cpu_req_store;
                        req_addr_q  <= cpu_addr;
                        req_wdata_q <= cpu_wdata;
                        req_mask_q  <= cpu_mask;
                        mem_addr    <= cpu_addr;
                        mem_wdata   <= cpu_req_store ? store_merge(32'b0, cpu_wdata, cpu_addr[1:0], cpu_mask) : 32'b0;
                        if (USE_FAST_DCACHE && !USE_SIMPLE_DCACHE_FALLBACK)
                            state <= LOOKUP;
                        else if (cpu_req_load)
                            state <= LOAD_WAIT0;
                        else
                            state <= STORE_HOLD;
                    end
                end

                LOOKUP: begin
                    mem_we  <= 4'b0000;
                    mem_wen <= 1'b0;
                    if (!req_cacheable) begin
                        if (req_load_q) begin
                            mem_addr <= req_addr_q;
                            state <= LOAD_WAIT0;
                        end else begin
                            state <= STORE_HOLD;
                        end
                    end else if (req_load_q && req_hit) begin
                        cpu_rdata <= load_shift(data[req_index], req_addr_q[1:0], req_mask_q);
                        perf_load_hit <= 1'b1;
                        state <= LOAD_HIT_RESP;
                    end else if (req_load_q) begin
                        mem_addr <= req_addr_q;
                        perf_load_miss <= 1'b1;
                        state <= LOAD_WAIT0;
                    end else begin
                        mem_addr  <= req_addr_q;
                        mem_wdata <= store_merge(32'b0, req_wdata_q, req_addr_q[1:0], req_mask_q);
                        if (req_hit)
                            data[req_index] <= store_merge(data[req_index], req_wdata_q, req_addr_q[1:0], req_mask_q);
                        state <= STORE_HOLD;
                    end
                end

                LOAD_HIT_RESP: begin
                    mem_we  <= 4'b0000;
                    mem_wen <= 1'b0;
                    mem_ack <= 1'b1;
                    state <= IDLE;
                end

                LOAD_WAIT0: begin
                    mem_we   <= 4'b0000;
                    mem_wen  <= 1'b0;
                    mem_addr <= req_addr_q;
                    state <= LOAD_WAIT1;
                end

                LOAD_WAIT1: begin
                    mem_we   <= 4'b0000;
                    mem_wen  <= 1'b0;
                    mem_addr <= req_addr_q;
                    state <= LOAD_WAIT2;
                end

                LOAD_WAIT2: begin
                    mem_we   <= 4'b0000;
                    mem_wen  <= 1'b0;
                    mem_addr <= req_addr_q;
                    state <= LOAD_MISS_RESP;
                end

                LOAD_MISS_RESP: begin
                    mem_we    <= 4'b0000;
                    mem_wen   <= 1'b0;
                    mem_addr  <= req_addr_q;
                    cpu_rdata <= load_shift(mem_rdata, req_addr_q[1:0], req_mask_q);
                    if (USE_FAST_DCACHE && !USE_SIMPLE_DCACHE_FALLBACK && req_cacheable) begin
                        valid[req_index] <= 1'b1;
                        tag[req_index]   <= req_tag;
                        data[req_index]  <= mem_rdata;
                    end
                    mem_ack <= 1'b1;
                    state <= IDLE;
                end

                STORE_HOLD: begin
                    mem_addr  <= req_addr_q;
                    mem_wdata <= store_merge(32'b0, req_wdata_q, req_addr_q[1:0], req_mask_q);
                    mem_we    <= unmask(req_mask_q, req_addr_q[1:0]);
                    mem_wen   <= 1'b1;
                    state <= STORE_ACK;
                end

                STORE_ACK: begin
                    mem_we    <= 4'b0000;
                    mem_wen   <= 1'b0;
                    mem_addr  <= req_addr_q;
                    mem_wdata <= store_merge(32'b0, req_wdata_q, req_addr_q[1:0], req_mask_q);
                    mem_ack   <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    mem_we  <= 4'b0000;
                    mem_wen <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

    function [3:0] unmask;
        input [1:0] mask;
        input [1:0] addr_low;
        begin
            case (mask)
                2'b00: begin
                    case (addr_low)
                        2'b00: unmask = 4'b0001;
                        2'b01: unmask = 4'b0010;
                        2'b10: unmask = 4'b0100;
                        2'b11: unmask = 4'b1000;
                        default: unmask = 4'b0000;
                    endcase
                end
                2'b01: begin
                    case (addr_low[1])
                        1'b0: unmask = 4'b0011;
                        1'b1: unmask = 4'b1100;
                        default: unmask = 4'b0000;
                    endcase
                end
                2'b10: begin
                    unmask = 4'b1111;
                end
                default: begin
                    unmask = 4'b0000;
                end
            endcase
        end
    endfunction

    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            case (mask)
                2'b00: begin
                    case (addr_low)
                        2'b00: load_shift = {24'b0, word[7:0]};
                        2'b01: load_shift = {24'b0, word[15:8]};
                        2'b10: load_shift = {24'b0, word[23:16]};
                        2'b11: load_shift = {24'b0, word[31:24]};
                        default: load_shift = 32'b0;
                    endcase
                end
                2'b01: begin
                    case (addr_low[1])
                        1'b0: load_shift = {16'b0, word[15:0]};
                        1'b1: load_shift = {16'b0, word[31:16]};
                        default: load_shift = 32'b0;
                    endcase
                end
                2'b10: begin
                    load_shift = word;
                end
                default: begin
                    load_shift = word;
                end
            endcase
        end
    endfunction

    function [31:0] store_merge;
        input [31:0] old_word;
        input [31:0] wdata;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            store_merge = old_word;
            case (mask)
                2'b00: begin
                    case (addr_low)
                        2'b00: store_merge[7:0]   = wdata[7:0];
                        2'b01: store_merge[15:8]  = wdata[7:0];
                        2'b10: store_merge[23:16] = wdata[7:0];
                        2'b11: store_merge[31:24] = wdata[7:0];
                        default: store_merge = old_word;
                    endcase
                end
                2'b01: begin
                    case (addr_low[1])
                        1'b0: store_merge[15:0]  = wdata[15:0];
                        1'b1: store_merge[31:16] = wdata[15:0];
                        default: store_merge = old_word;
                    endcase
                end
                2'b10: begin
                    store_merge = wdata;
                end
                default: begin
                    store_merge = old_word;
                end
            endcase
        end
    endfunction
endmodule
