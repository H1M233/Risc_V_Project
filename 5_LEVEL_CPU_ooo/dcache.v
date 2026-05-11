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

    reg        req_load_q;
    reg        req_store_q;
    reg [31:0] req_addr_q;
    reg [31:0] req_wdata_q;
    reg [1:0]  req_mask_q;

    localparam IDLE       = 3'd0;
    localparam LOAD_WAIT0 = 3'd1;
    localparam LOAD_WAIT1 = 3'd2;
    localparam LOAD_WAIT2 = 3'd3;
    localparam LOAD_RESP  = 3'd4;
    localparam STORE_HOLD = 3'd5;
    localparam STORE_ACK  = 3'd6;

    reg [2:0] state;

    assign stall = (state != IDLE);

    always @(posedge clk) begin
        if (!rst) begin
            state       <= IDLE;
            cpu_rdata   <= 32'b0;
            mem_addr    <= 32'b0;
            mem_we      <= 4'b0000;
            mem_wen     <= 1'b0;
            mem_wdata   <= 32'b0;
            mem_ack     <= 1'b0;
            req_load_q  <= 1'b0;
            req_store_q <= 1'b0;
            req_addr_q  <= 32'b0;
            req_wdata_q <= 32'b0;
            req_mask_q  <= 2'b0;
        end else begin
            mem_ack <= 1'b0;

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
                        if (cpu_req_load) begin
                            mem_addr  <= cpu_addr;
                            mem_wdata <= 32'b0;
                            state <= LOAD_WAIT0;
                        end else begin
                            mem_addr  <= cpu_addr;
                            mem_wdata <= store_merge(32'b0, cpu_wdata, cpu_addr[1:0], cpu_mask);
                            mem_we    <= 4'b0000;
                            mem_wen   <= 1'b0;
                            state <= STORE_HOLD;
                        end
                    end
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
                    state <= LOAD_RESP;
                end

                LOAD_RESP: begin
                    mem_we    <= 4'b0000;
                    mem_wen   <= 1'b0;
                    mem_addr  <= req_addr_q;
                    cpu_rdata <= load_shift(mem_rdata, req_addr_q[1:0], req_mask_q);
                    mem_ack   <= 1'b1;
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
