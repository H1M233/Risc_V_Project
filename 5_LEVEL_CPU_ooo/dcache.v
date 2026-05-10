`include "rv32I.vh"

module dcache#(
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = 24,
    parameter WAYS          = 2
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

    output reg          mem_ack
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    (* ram_style = "block" *) reg [31:0] data_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0] tag_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg valid_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg plru_state [0:LINE_NUM - 1];

    reg        req_valid_q;
    reg        req_load_q;
    reg        req_store_q;
    reg [31:0] req_addr_q;
    reg [31:0] req_wdata_q;
    reg [1:0]  req_mask_q;
    reg [INDEX_WIDTH - 1:0] req_index_q;
    reg [TAG_WIDTH - 1:0]   req_tag_q;

    localparam IDLE       = 3'd0;
    localparam LOOKUP     = 3'd1;
    localparam LOAD_MISS  = 3'd2;
    localparam LOAD_WAIT  = 3'd3;
    localparam LOAD_RESP  = 3'd4;
    localparam STORE_RESP = 3'd5;

    reg [2:0] state;

    assign stall = (state != IDLE);

    wire [WAYS - 1:0] hit_way;
    genvar w0;
    generate
        for (w0 = 0; w0 < WAYS; w0 = w0 + 1) begin : hit_gen
            assign hit_way[w0] = req_valid_q &&
                                 valid_array[w0][req_index_q] &&
                                 (tag_array[w0][req_index_q] == req_tag_q);
        end
    endgenerate

    wire hit = |hit_way;
    wire hit_way_idx = hit_way[0] ? 1'b0 :
                       hit_way[1] ? 1'b1 : 1'b0;
    wire miss_way_idx = plru_state[req_index_q];
    wire [31:0] hit_word = data_array[hit_way_idx][req_index_q];

    integer i, w;
    always @(posedge clk) begin
        if (!rst) begin
            state       <= IDLE;
            req_valid_q <= 1'b0;
            req_load_q  <= 1'b0;
            req_store_q <= 1'b0;
            req_addr_q  <= 32'b0;
            req_wdata_q <= 32'b0;
            req_mask_q  <= 2'b0;
            req_index_q <= {INDEX_WIDTH{1'b0}};
            req_tag_q   <= {TAG_WIDTH{1'b0}};
            cpu_rdata   <= 32'b0;
            mem_addr    <= 32'b0;
            mem_we      <= 4'b0;
            mem_wen     <= 1'b0;
            mem_wdata   <= 32'b0;
            mem_ack     <= 1'b0;

            for (w = 0; w < WAYS; w = w + 1) begin
                for (i = 0; i < LINE_NUM; i = i + 1) begin
                    data_array[w][i] <= 32'b0;
                    tag_array[w][i] <= {TAG_WIDTH{1'b0}};
                    valid_array[w][i] <= 1'b0;
                end
            end
            for (i = 0; i < LINE_NUM; i = i + 1)
                plru_state[i] <= 1'b0;
        end else begin
            mem_ack <= 1'b0;
            mem_we  <= 4'b0;
            mem_wen <= 1'b0;

            case (state)
                IDLE: begin
                    mem_addr  <= 32'b0;
                    mem_wdata <= 32'b0;
                    if (cpu_req_load || cpu_req_store) begin
                        req_valid_q <= 1'b1;
                        req_load_q  <= cpu_req_load;
                        req_store_q <= cpu_req_store;
                        req_addr_q  <= cpu_addr;
                        req_wdata_q <= cpu_wdata;
                        req_mask_q  <= cpu_mask;
                        req_index_q <= cpu_addr[INDEX_WIDTH + 1:2];
                        req_tag_q   <= cpu_addr[31:INDEX_WIDTH + 2];
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (req_load_q) begin
                        if (hit) begin
                            cpu_rdata <= load_shift(hit_word, req_addr_q[1:0], req_mask_q);
                            mem_ack <= 1'b1;
                            req_valid_q <= 1'b0;
                            plru_state[req_index_q] <= ~hit_way_idx;
                            state <= IDLE;
                        end else begin
                            mem_addr <= req_addr_q;
                            state <= LOAD_MISS;
                        end
                    end else if (req_store_q) begin
                        mem_addr  <= req_addr_q;
                        mem_wdata <= store_merge(32'b0, req_wdata_q, req_addr_q[1:0], req_mask_q);
                        mem_we    <= unmask(req_mask_q, req_addr_q[1:0]);
                        mem_wen   <= 1'b1;
                        if (hit) begin
                            data_array[hit_way_idx][req_index_q] <= store_merge(
                                hit_word,
                                req_wdata_q,
                                req_addr_q[1:0],
                                req_mask_q
                            );
                            plru_state[req_index_q] <= ~hit_way_idx;
                        end
                        state <= STORE_RESP;
                    end else begin
                        req_valid_q <= 1'b0;
                        state <= IDLE;
                    end
                end

                LOAD_MISS: begin
                    mem_addr <= req_addr_q;
                    state <= LOAD_WAIT;
                end

                LOAD_WAIT: begin
                    mem_addr <= req_addr_q;
                    state <= LOAD_RESP;
                end

                LOAD_RESP: begin
                    mem_addr <= req_addr_q;
                    cpu_rdata <= load_shift(mem_rdata, req_addr_q[1:0], req_mask_q);
                    valid_array[miss_way_idx][req_index_q] <= 1'b1;
                    tag_array[miss_way_idx][req_index_q] <= req_tag_q;
                    data_array[miss_way_idx][req_index_q] <= mem_rdata;
                    plru_state[req_index_q] <= ~miss_way_idx;
                    mem_ack <= 1'b1;
                    req_valid_q <= 1'b0;
                    state <= IDLE;
                end

                STORE_RESP: begin
                    mem_addr  <= req_addr_q;
                    mem_wdata <= store_merge(32'b0, req_wdata_q, req_addr_q[1:0], req_mask_q);
                    mem_ack   <= 1'b1;
                    req_valid_q <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    req_valid_q <= 1'b0;
                    mem_addr <= 32'b0;
                    mem_wdata <= 32'b0;
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
                2'b10: unmask = 4'b1111;
                default: unmask = 4'b0000;
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
                2'b10: load_shift = word;
                default: load_shift = word;
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
                2'b10: store_merge = wdata;
                default: store_merge = old_word;
            endcase
        end
    endfunction
endmodule