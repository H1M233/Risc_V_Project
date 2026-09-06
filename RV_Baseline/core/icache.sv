`include "rv32I.svh"
`include "switch.svh"

module icache (
    input  logic            clk                     ,
    input  logic            rst                     ,
    input  logic            pipe_hold               ,
    input  logic            pipe_flush              ,

    // CPU side
    input  logic [31:0]     cpu_req_addr            ,
    input  logic            cpu_req_prefetch        ,
    input  logic            cpu_req_update          ,
    output logic [255:0]    cpu_resp_line           ,
    output logic            cpu_resp_valid          ,
    
    // Perip Bridge side
    output logic [31:0]     perip_addr              ,
    output logic            perip_arvalid           ,
    output logic            perip_ren               ,
    input  logic            perip_ready             ,
    input  logic [31:0]     perip_rdata             ,
    input  logic            perip_rvalid            
);
    localparam INDEX_WIDTH = `ICACHE_INDEX_WIDTH;
    localparam TAG_WIDTH   = 28 - INDEX_WIDTH;
    localparam LINE_NUM    = 2 ** INDEX_WIDTH;
    
    typedef enum {IDLE, QUERY, REQUEST_n_FILL, LINE_WB} state_t;
    state_t                     state;
    
    logic [INDEX_WIDTH - 1:0]   miss_index;
    logic [TAG_WIDTH - 1:0]     miss_tag;
    logic                       miss_way;
    logic [2:0]                 miss_word_sel;
    logic [2:0]                 fill_word_sel;
    logic                       req_prefetch_r;
    logic                       perip_req_valid;

    // 两路 I-cache
    (* ram_style = "bram" *) logic [255:0]       data_w0     [0:LINE_NUM - 1];
    (* ram_style = "bram" *) logic [255:0]       data_w1     [0:LINE_NUM - 1];

    // [TAG_WIDTH]: Valid,  [TAG_WIDTH - 1:0]: Tag
    (* ram_style = "bram" *) logic [TAG_WIDTH:0] tagv_w0     [0:LINE_NUM - 1];
    (* ram_style = "bram" *) logic [TAG_WIDTH:0] tagv_w1     [0:LINE_NUM - 1];
    (* ram_style = "bram" *) logic               replace_way [0:LINE_NUM - 1];

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
    wire [INDEX_WIDTH - 1:0] query_index = cpu_req_addr[INDEX_WIDTH + 4:5];
    wire [TAG_WIDTH - 1:0]   query_tag   = cpu_req_addr[31:INDEX_WIDTH + 5];

    // 读数据
    logic               replace_way_rdata;
    logic [TAG_WIDTH:0] tagv_w0_rdata;
    logic [TAG_WIDTH:0] tagv_w1_rdata;
    logic [255:0]       data_w0_rdata;
    logic [255:0]       data_w1_rdata;
    logic [255:0]       data_rdata;
    always_ff @(posedge clk) begin
        tagv_w0_rdata       <= tagv_w0[query_index];
        tagv_w1_rdata       <= tagv_w1[query_index];
        replace_way_rdata   <= replace_way[query_index];
        data_w0_rdata       <= data_w0[query_index];
        data_w1_rdata       <= data_w1[query_index];
    end

    // 命中判断
    wire hit_way0    = tagv_w0_rdata == {1'b1, query_tag};
    wire hit_way1    = tagv_w1_rdata == {1'b1, query_tag};
    wire ICACHE_hit  = hit_way0 | hit_way1;
    wire ICACHE_miss = ~ICACHE_hit;
    assign data_rdata = (hit_way1) ? data_w1_rdata : data_w0_rdata;

    // 外设读请求
    wire [31:0] perip_req_addr  = {miss_tag, miss_index, miss_word_sel, 2'b0};
    assign perip_addr           = (perip_req_valid) ? perip_req_addr : 32'b0;
    assign perip_arvalid        = perip_req_valid;
    assign perip_ren            = state == REQUEST_n_FILL;

    // 写入行缓存
    logic [255:0] line_buffer;
    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            line_buffer                         <= 0;
        end else if (state == REQUEST_n_FILL & perip_rvalid) begin
            line_buffer[fill_word_sel*32 +: 32] <= perip_rdata;
        end
    end
    
    // 写入 I-Cache
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
    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            state               <= IDLE;
            miss_index          <= 0;
            miss_tag            <= 0;
            miss_way            <= 0;
            miss_word_sel       <= 0;
            fill_word_sel       <= 0;
            req_prefetch_r      <= 0;
            perip_req_valid     <= 0;
        end else begin
            req_prefetch_r      <= cpu_req_prefetch;

            case (state)
                IDLE : begin
                    if (req_prefetch_r | ~cpu_resp_valid) begin
                        state           <= QUERY;
                    end
                end
                
                QUERY : begin
                    if (ICACHE_miss) begin
                        state           <= REQUEST_n_FILL;
                        miss_index      <= query_index;
                        miss_tag        <= query_tag;
                        miss_way        <= replace_way_rdata;
                        perip_req_valid <= 1'b1;
                    end else if (cpu_req_update) begin
                        state           <= IDLE;
                    end
                end

                REQUEST_n_FILL : begin
                    // 发送地址
                    if (perip_ready) begin
                        if (miss_word_sel == 3'd7) begin    // 发送完毕
                            perip_req_valid     <= 1'b0;
                            miss_word_sel       <= 0;
                        end else if (perip_req_valid) begin
                            miss_word_sel       <= miss_word_sel + 1'b1;
                        end
                    end

                    // 填充数据
                    if (perip_rvalid) begin
                        if (fill_word_sel == 3'd7) begin    // 填充完毕
                            state               <= LINE_WB;
                            fill_word_sel       <= 1'b0;
                        end else begin
                            fill_word_sel       <= fill_word_sel + 1'b1;
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
    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            cpu_resp_line       <= 256'b0;
            cpu_resp_valid      <= 1'b0;
        end else if (pipe_hold) begin
            // ...
        end else if (cpu_req_update) begin
            if (state == LINE_WB) begin
                cpu_resp_line       <= line_buffer;
                cpu_resp_valid      <= 1'b1;
            end else if (state == QUERY & ICACHE_hit) begin
                cpu_resp_line       <= data_rdata;
                cpu_resp_valid      <= 1'b1;
            end else begin
                cpu_resp_line       <= 256'b0;
                cpu_resp_valid      <= 1'b0;
            end
        end
    end
endmodule