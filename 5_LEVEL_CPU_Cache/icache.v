`include "rv32I.vh"

module icache(
    input               clk,
    input               rst,

    // CPU / IF side
    input      [31:0]   cpu_addr,
    output     [31:0]   cpu_inst,
    output              stall,

    // IROM side
    output     [31:0]   mem_addr,
    input      [31:0]   mem_inst
);
    localparam INDEX_WIDTH = 6;
    localparam TAG_WIDTH   = 24;
    localparam LINE_NUM    = 64;

    localparam S_IDLE      = 1'b0;
    localparam S_REFILL    = 1'b1;

    reg state;

    wire [INDEX_WIDTH-1:0] index = cpu_addr[INDEX_WIDTH+1:2];
    wire [TAG_WIDTH-1:0]   tag   = cpu_addr[31:INDEX_WIDTH+2];

    reg [31:0]             data_array  [0:LINE_NUM-1];
    reg [TAG_WIDTH-1:0]    tag_array   [0:LINE_NUM-1];
    reg                    valid_array [0:LINE_NUM-1];

    reg [31:0]             miss_addr;
    reg [INDEX_WIDTH-1:0]  miss_index;
    reg [TAG_WIDTH-1:0]    miss_tag;

    wire hit  = valid_array[index] && (tag_array[index] == tag);
    wire miss = !hit;

    assign stall = rst && ((state == S_REFILL) || ((state == S_IDLE) && miss));

    assign mem_addr = (state == S_REFILL) ? miss_addr : {cpu_addr[31:2], 2'b00};

    assign cpu_inst = hit ? data_array[index] : `NOP;

    integer i;

    always @(posedge clk) begin
        if(!rst) begin
            state     <= S_IDLE;
            miss_addr <= 32'b0;
            miss_index <= {INDEX_WIDTH{1'b0}};
            miss_tag   <= {TAG_WIDTH{1'b0}};

            for(i = 0; i < LINE_NUM; i = i + 1) begin
                valid_array[i] <= 1'b0;
            end
        end
        else begin
            case(state)
                S_IDLE: begin
                    if(miss) begin
                        miss_addr  <= {cpu_addr[31:2], 2'b00};
                        miss_index <= index;
                        miss_tag   <= tag;
                        state      <= S_REFILL;
                    end
                end

                S_REFILL: begin
                    valid_array[miss_index] <= 1'b1;
                    tag_array[miss_index]   <= miss_tag;
                    data_array[miss_index]  <= mem_inst;
                    state                   <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule