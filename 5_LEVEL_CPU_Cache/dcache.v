`include "rv32I.vh"

module dcache#(
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = 24,
    parameter WAYS          = 4
)(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req,
    input               cpu_wen,
    input      [1:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [31:0]   cpu_wdata,
    output reg [31:0]   cpu_rdata,
    output              stall,

    // external DROM side
    output reg [31:0]   mem_addr,
    output reg          mem_wen,
    output reg [1:0]    mem_mask,
    output reg [31:0]   mem_wdata,
    input      [31:0]   mem_rdata
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    // ============================================================
    //
    // 命中计数器
    reg [31:0] dcache_hit;
    reg [31:0] dcache_miss;
    always@(posedge clk) begin
        if(!rst) begin
            dcache_hit  <= 32'b0;
            dcache_miss <= 32'b0;
        end
        else begin
            if(state == S_QUERY)
            dcache_hit  <= (state == S_OUTPUT && state == S_CHECK) ? dcache_hit + 1'b1 : dcache_hit;
            dcache_miss <= (state == S_WAIT && store_miss) ? dcache_miss + 1'b1 : dcache_miss;
        end
    end
    //
    // ============================================================

    // 状态
    localparam S_QUERY  = 3'd0;
    localparam S_CHECK  = 3'd1;
    localparam S_WAIT   = 3'd2;
    localparam S_REFILL = 3'd3;
    localparam S_OUTPUT = 3'd4;
    reg [2:0] state;

    // 提取索引和 tag
    wire [INDEX_WIDTH - 1:0] index = cpu_addr[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   tag   = cpu_addr[31:INDEX_WIDTH + 2];

    // 存储结构：
    (* ram_style = "block" *) reg [31:0] data_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0]   tag_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg                     valid_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg                    dirty_array [0:WAYS - 1][0:LINE_NUM - 1];  // 写回用，目前写透暂可不深究

    // ==================== PLRU 替换策略 ====================
    // 每组的访问历史（用于选择替换哪一路）
    // 用 4×4 矩阵跟踪每对 way 的访问顺序（简化版：只用 3 位状态）
    reg [2:0] plru_state [0:LINE_NUM - 1];  // 3 位足够编码 4 路的 PLRU 树

    // 命中检测
    wire [WAYS - 1:0] hit_way;
    genvar way;
    generate
        for(way = 0; way < WAYS; way = way + 1) begin : hit_gen
            assign hit_way[way] = valid_array[way][index] && (tag_array[way][index] == tag);
        end
    endgenerate

    wire hit = |hit_way;
    wire miss = !hit;

    // 优先选择低路
    reg [1:0] hit_way_idx;
    always @(*) begin
        casez (hit_way)
            4'b???1: hit_way_idx = 2'd0;
            4'b??10: hit_way_idx = 2'd1;
            4'b?100: hit_way_idx = 2'd2;
            4'b1000: hit_way_idx = 2'd3;
            default: hit_way_idx = 2'd0;
        endcase
    end

    // 选择替换的路
    reg [1:0] replace_way;
    always @(*) begin
        if (plru_state[index][2] == 1'b0) begin
            if (plru_state[index][0] == 1'b0)
                replace_way = 2'd2;
            else
                replace_way = 2'd3;
        end
        else begin
            if (plru_state[index][1] == 1'b0)
                replace_way = 2'd0;
            else
                replace_way = 2'd1;
        end
    end

    // PLRU 更新
    wire        update_plru   = (state == S_QUERY && hit && cpu_req);
    wire [1:0]  accessed_way  = hit_way_idx;

    // 判断类型
    wire load_req = (cpu_req && !cpu_wen);
    wire store_req = (cpu_req && cpu_wen);
    wire load_hit = (load_req && hit);
    wire load_miss = (load_req && !hit);
    wire store_hit = (store_req & hit);
    wire store_miss = (store_req && !hit);

    // 冻结流水线
    assign stall = (load_req & (state != S_OUTPUT) & (state != S_REFILL)) | (store_hit & (state == S_QUERY));


    // 读数据输出
    reg [31:0] cache_rdata_reg;
    always @(posedge clk) begin
        case (hit_way_idx)
            2'd0: cache_rdata_reg <= data_array[0][index];
            2'd1: cache_rdata_reg <= data_array[1][index];
            2'd2: cache_rdata_reg <= data_array[2][index];
            2'd3: cache_rdata_reg <= data_array[3][index];
            default: cache_rdata_reg = 32'b0;
        endcase
    end

    always @(*) begin
        if (state == S_OUTPUT)
            cpu_rdata = load_shift(cache_rdata_reg, cpu_addr[1:0], cpu_mask);
        else if (state == S_REFILL)
            // 旁路：填充时直接把 DROM 数据返回 CPU
            cpu_rdata = load_shift(mem_rdata, cpu_addr[1:0], cpu_mask);
        else
            cpu_rdata = 32'b0;
    end

    // DRAM接口
    always @(*) begin
        mem_addr = cpu_addr;
        mem_wdata = cpu_wdata;
        mem_mask = (store_req) ? cpu_mask : 2'b10;
        mem_wen = cpu_wen;
    end

    // 填充状态保存
    reg [31:0]             miss_addr;
    reg [INDEX_WIDTH-1:0]  miss_index;
    reg [TAG_WIDTH-1:0]    miss_tag;
    reg [1:0]              miss_way;

    // 主状态机
    integer i, w;
    always @(posedge clk) begin
        if (!rst) begin
            state      <= S_QUERY;
            miss_addr  <= 0;
            miss_index <= 0;
            miss_tag   <= 0;
            miss_way   <= 0;

            for (w = 0; w < WAYS; w = w + 1) begin
                for (i = 0; i < LINE_NUM; i = i + 1) begin
                    valid_array[w][i] <= 1'b0;
                    dirty_array[w][i] <= 1'b0;
                end
            end

            for (i = 0; i < LINE_NUM; i = i + 1) plru_state[i] <= 3'b0;
        end
        else begin
            case (state)
                S_QUERY: begin
                    if(store_hit) begin
                        state       <= S_CHECK;
                    end
                    else if (load_miss) begin
                        // load miss：启动填充
                        miss_addr   <= cpu_addr;
                        miss_index  <= index;
                        miss_tag    <= tag;
                        miss_way    <= replace_way;
                        state       <= S_WAIT;
                    end
                    else if(load_hit) begin
                        state       <= S_OUTPUT;
                    end
                    else begin
                        // store_miss 不缓存
                    end
                end
                S_CHECK: begin
                    // store hit：穿透写 DROM 的同时更新 Cache
                    data_array[hit_way_idx][index] <= store_merge(
                        cache_rdata_reg,
                        cpu_wdata,
                        cpu_addr[1:0],
                        cpu_mask
                    );
                    state <= S_QUERY;
                end

                S_REFILL: begin
                    // 填充完成，写入 cache
                    valid_array[miss_way][miss_index] <= 1'b1;
                    tag_array[miss_way][miss_index]   <= miss_tag;
                    data_array[miss_way][miss_index]  <= mem_rdata;
                    state <= S_QUERY;
                end

                S_OUTPUT: begin
                    state <= S_QUERY;
                end

                S_WAIT: begin
                    state <= S_REFILL;
                end

                default: state <= S_QUERY;
            endcase

            // PLRU 更新
            if (update_plru) begin
                case (accessed_way)
                    2'd0: begin
                        plru_state[index][2] <= 1'b0;
                        plru_state[index][1] <= 1'b0;
                    end
                    2'd1: begin
                        plru_state[index][2] <= 1'b0;
                        plru_state[index][1] <= 1'b1;
                    end
                    2'd2: begin
                        plru_state[index][2] <= 1'b1;
                        plru_state[index][0] <= 1'b0;
                    end
                    2'd3: begin
                        plru_state[index][2] <= 1'b1;
                        plru_state[index][0] <= 1'b1;
                    end
                endcase
            end
        end
    end

    // 函数：
    // 把完整 word 根据 addr[1:0] 和 mask 移到低位
    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            case(mask)
                // byte
                2'b00: begin
                    case(addr_low)
                        2'b00: load_shift = {24'b0, word[7:0]};
                        2'b01: load_shift = {24'b0, word[15:8]};
                        2'b10: load_shift = {24'b0, word[23:16]};
                        2'b11: load_shift = {24'b0, word[31:24]};
                    endcase
                end

                // half word
                2'b01: begin
                    if(addr_low[1])
                        load_shift = {16'b0, word[31:16]};
                    else
                        load_shift = {16'b0, word[15:0]};
                end

                // word
                2'b10: begin
                    load_shift = word;
                end

                default: begin
                    load_shift = word;
                end
            endcase
        end
    endfunction

    // store hit 时更新 cache 里的旧 word
    function [31:0] store_merge;
        input [31:0] old_word;
        input [31:0] wdata;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            store_merge = old_word;

            case(mask)
                // SB
                2'b00: begin
                    case(addr_low)
                        2'b00: store_merge[7:0]   = wdata[7:0];
                        2'b01: store_merge[15:8]  = wdata[7:0];
                        2'b10: store_merge[23:16] = wdata[7:0];
                        2'b11: store_merge[31:24] = wdata[7:0];
                    endcase
                end

                // SH
                2'b01: begin
                    if(addr_low[1])
                        store_merge[31:16] = wdata[15:0];
                    else
                        store_merge[15:0]  = wdata[15:0];
                end

                // SW
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