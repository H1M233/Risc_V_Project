`include "rv32I.svh"
`include "switch.svh"

module icache (
    input  logic            clk                 ,
    input  logic            rst                 ,
    input  logic            pipe_hold           ,
    input  logic            pipe_flush          ,

    // CPU side
    input  logic [31:0]     cpu_addr            ,
    input  logic            cpu_arvalid         ,
    output logic [31:0]     cpu_addr_r          ,
    output logic [31:0]     cpu_rdata           ,
    output logic            cpu_rvalid          ,
    output logic            cpu_stall           ,
    
    // Perip Bridge side
    output logic [31:0]     perip_addr          ,
    output logic            perip_arvalid       ,
    output logic            perip_ren           ,
    input  logic            perip_ready         ,
    input  logic [31:0]     perip_rdata         ,
    input  logic            perip_rvalid        
);
    localparam INDEX_WIDTH = `ICACHE_INDEX_WIDTH;
    localparam TAG_WIDTH   = 28 - INDEX_WIDTH;
    localparam LINE_NUM    = 2 ** INDEX_WIDTH;
    
    typedef enum {IDLE, REQUEST_n_FILL, LINE_WB} state_t;
    state_t                     state;
    
    logic [INDEX_WIDTH - 1:0]   miss_index;
    logic [TAG_WIDTH - 1:0]     miss_tag;
    logic                       miss_way;
    logic [1:0]                 miss_word_sel;
    logic [1:0]                 fill_word_sel;
    logic                       requset_arvalid;
    `ifdef ENABLE_C
    logic                       align2x_low_valid;
    logic [15:0]                align2x_low_rdata;
    logic                       align2x_high_valid;
    logic [15:0]                align2x_high_rdata;
    `endif

    // 两路 I-cache
    (* ram_style = "distributed" *) logic [127:0]       data_w0     [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) logic [127:0]       data_w1     [0:LINE_NUM - 1];

    // [TAG_WIDTH]: Valid,  [TAG_WIDTH - 1:0]: Tag
    (* ram_style = "distributed" *) logic [TAG_WIDTH:0] tagv_w0     [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) logic [TAG_WIDTH:0] tagv_w1     [0:LINE_NUM - 1];
    (* ram_style = "distributed" *) logic               replace_way [0:LINE_NUM - 1];

    // 初始化
    initial begin
        for (int i = 0; i < LINE_NUM; i++)  begin
            data_w0[i]      = 0;
            data_w1[i]      = 0;
            tagv_w0[i]      = 0;
            tagv_w1[i]      = 0;
            replace_way[i]  = 0;
        end
    end

    // 地址解码
    `ifdef ENABLE_C
    logic [31:0] cpu_pc_add2_r;
    always_ff @(posedge clk) begin
        if (rst) begin
            cpu_pc_add2_r <= 0;
        end else begin
            cpu_pc_add2_r <= cpu_addr + 2'd2;
        end
    end
    wire [31:0]              query_pc        = (align2x_low_valid && align2x_line) ? cpu_pc_add2_r : cpu_addr;
    wire                     align2x_line    = cpu_addr[3:1] == 3'b111;
    wire [2:0]               query_half_word = query_pc[3:1];                 // 支持 2 字节对齐
    `else
    wire [31:0]              query_pc        = cpu_addr;
    wire [1:0]               query_word      = query_pc[3:2];
    `endif
    wire [INDEX_WIDTH - 1:0] query_index     = query_pc[INDEX_WIDTH + 3:4];
    wire [TAG_WIDTH - 1:0]   query_tag       = query_pc[31:INDEX_WIDTH + 4];
    
    // 命中判断
    wire hit_way0    = tagv_w0[query_index] == {1'b1, query_tag};
    wire hit_way1    = tagv_w1[query_index] == {1'b1, query_tag};
    wire icache_hit  = hit_way0 | hit_way1;
    wire icache_miss = ~icache_hit;

    // 读数据
    wire         replace_way_rdata  = replace_way[query_index];
    wire [127:0] data_w0_rdata      = data_w0[query_index];
    wire [127:0] data_w1_rdata      = data_w1[query_index];
    `ifdef ENABLE_C
    wire [31:0]  data_rdata         = (hit_way1) ?  data_w1_rdata[query_half_word*16 +: 32] :  // 支持 2 字节对齐
                                                    data_w0_rdata[query_half_word*16 +: 32];
    wire [31:0]  data_xline_rdata   = {align2x_high_rdata, align2x_low_rdata};
    `else
    wire [31:0]  data_rdata         = (hit_way1) ?  data_w1_rdata[query_word*32 +: 32] :
                                                    data_w0_rdata[query_word*32 +: 32];
    `endif

    // IROM 请求
    wire [31:0] request_addr = {miss_tag, miss_index, miss_word_sel, 2'b0};
    assign perip_addr = (requset_arvalid) ? request_addr : 32'b0;

    // 写入行缓存
    logic [127:0] line_buffer;
    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            line_buffer                         <= 0;
        end else if (perip_rvalid) begin
            line_buffer[fill_word_sel*32 +: 32] <= perip_rdata;
        end
    end
    
    // 写入
    always_ff @(posedge clk) begin
        if (state == LINE_WB) begin
            replace_way[miss_index] <= ~miss_way;
            
            if (miss_way) begin
                data_w1[miss_index] <= line_buffer;
                tagv_w1[miss_index] <= {1'b1, miss_tag};
            end else begin
                data_w0[miss_index] <= line_buffer;
                tagv_w0[miss_index] <= {1'b1, miss_tag};
            end
        end
    end

    // 状态机
    assign perip_arvalid = requset_arvalid;
    assign perip_ren     = state == REQUEST_n_FILL;
    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            state               <= IDLE;
            miss_index          <= 0;
            miss_tag            <= 0;
            miss_way            <= 0;
            miss_word_sel       <= 0;
            fill_word_sel       <= 0;
            requset_arvalid     <= 0;
            `ifdef ENABLE_C
            align2x_low_valid   <= 0;
            align2x_low_rdata   <= 0;
            align2x_high_valid  <= 0;
            align2x_high_rdata  <= 0;
            `endif
        end else begin
            case (state)
                IDLE : begin
                    if (icache_miss) begin
                        state           <= REQUEST_n_FILL;
                        miss_index      <= query_index;
                        miss_tag        <= query_tag;
                        miss_way        <= replace_way_rdata;
                        requset_arvalid <= 1'b1;
                    end

                `ifdef ENABLE_C
                    if (align2x_line) begin
                        if (icache_hit) begin
                            if (align2x_low_valid) begin
                                align2x_high_valid <= 1'b1;
                                align2x_high_rdata <= data_rdata[15:0];
                            end else if (~align2x_high_valid) begin
                                align2x_low_valid <= 1'b1;
                                align2x_low_rdata <= data_rdata[15:0];
                            end
                        end
                    end else begin
                        align2x_low_valid   <= 0;
                        align2x_low_rdata   <= 0;
                        align2x_high_valid  <= 0;
                        align2x_high_rdata  <= 0;
                    end
                `endif
                end

                REQUEST_n_FILL : begin
                    // 发送地址
                    if (perip_ready) begin
                        if (miss_word_sel == 2'd3) begin    // 发送完毕
                            requset_arvalid     <= 1'b0;
                            miss_word_sel       <= 0;
                        end else if (requset_arvalid) begin
                            miss_word_sel       <= miss_word_sel + 1'b1;
                        end
                    end

                    // 填充数据
                    if (perip_rvalid) begin
                        if (fill_word_sel == 2'd3) begin    // 填充完毕
                            state               <= LINE_WB;
                            fill_word_sel       <= 1'b0;
                        end else begin
                            fill_word_sel       <= fill_word_sel +1'b1;
                        end
                    end
                end

                LINE_WB : begin
                    state               <= IDLE;
                    miss_index          <= 0;
                    miss_tag            <= 0;
                    miss_way            <= 0;
                end

                default : state <= IDLE;
            endcase
        end
    end

    // CPU 输出
    `ifdef ENABLE_C
    assign cpu_stall = state != IDLE | icache_miss | (align2x_line & ~(align2x_low_valid & align2x_high_valid));
    `else
    assign cpu_stall = state != IDLE | icache_miss;
    `endif

    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            cpu_addr_r  <= 32'b0;
            cpu_rdata   <= `NOP;
            cpu_rvalid  <= 1'b0;
        end else if (pipe_hold) begin
            // ...
        `ifdef ENABLE_C
        end else if (state == IDLE & icache_hit & ~align2x_line) begin
            cpu_addr_r  <= cpu_addr;
            cpu_rdata   <= data_rdata;
            cpu_rvalid  <= 1'b1;
        end else if (align2x_line & align2x_low_valid & align2x_high_valid) begin
            cpu_addr_r  <= cpu_addr;
            cpu_rdata   <= data_xline_rdata;
            cpu_rvalid  <= 1'b1;
        `else
        end else if (state == IDLE & icache_hit) begin
            cpu_addr_r  <= cpu_addr;
            cpu_rdata   <= data_rdata;
            cpu_rvalid  <= 1'b1;
        `endif
        end else begin
            cpu_addr_r  <= 32'b0;
            cpu_rdata   <= `NOP;
            cpu_rvalid  <= 1'b0;
        end
    end
endmodule