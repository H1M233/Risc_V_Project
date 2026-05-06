`include "rv32I.vh"

// 实现：
// load_miss: 暂停 3 个周期，向 DRAM 请求数据 -> 根据 plur 选择路并更新 plur -> 等待数据 -> 转发并更新 DCACHE
// load_hit: 暂停 1 个周期，计算命中 -> 直接从 DCACHE 传出数据
// store_miss: 暂停 1 个周期，直接写入 DRAM（暂停是为了避免store and use）
// store_hit: 暂停 1 个周期，写入 DRAM -> 根据计算的路更新 DCACHE

module dcache#(
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = 24,
    parameter WAYS          = 2     // DCACHE 使用 2 路足够
)(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req_load,
    input               cpu_req_store,
    input      [1:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [31:0]   cpu_wdata,
    output reg [31:0]   cpu_rdata,
    output              stall,

    // external DROM side
    output reg          mem_en,
    output reg [31:0]   mem_addr,
    output reg [3:0]    mem_we,
    output reg          mem_wen,
    output reg [31:0]   mem_wdata,
    input      [31:0]   mem_rdata
);
    localparam LINE_NUM = 2 ** INDEX_WIDTH;

    // ============================================================
    //
    // 命中计数器
    // reg [31:0] dcache_hit;
    // reg [31:0] dcache_miss;
    // always@(posedge clk) begin
    //     if(!rst) begin
    //         dcache_hit  <= 32'b0;
    //         dcache_miss <= 32'b0;
    //     end
    //     else begin
    //         dcache_hit  <= (state == LOAD_HIT_OUTPUT & state == STORE_HIT) ? dcache_hit + 1'b1 : dcache_hit;
    //         dcache_miss <= (state == LOAD_MISS_OUTPUT && state == STORE_MISS) ? dcache_miss + 1'b1 : dcache_miss;
    //     end
    // end
    //
    // ============================================================

    // 存储结构：
    (* ram_style = "block" *) reg [31:0] data_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0] tag_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg valid_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg plru_state [0:LINE_NUM - 1];                // 每组的访问历史（用于选择替换哪一路）

    // 提取索引
    reg [INDEX_WIDTH - 1:0] index;
    reg [TAG_WIDTH - 1:0]   tag;

    always @(posedge clk) begin
        index   <= cpu_addr[INDEX_WIDTH + 1:2];
        tag     <= cpu_addr[31:INDEX_WIDTH + 2];
    end

    // 命中检测
    wire [WAYS - 1:0] hit_way;
    wire hit = |hit_way;
    genvar w0;
    generate
        for(w0 = 0; w0 < WAYS; w0 = w0 + 1) begin : hit_gen
            assign hit_way[w0] = valid_array[w0][index] && (tag_array[w0][index] == tag);
        end
    endgenerate
    
    // DCACHE 输出缓存
    reg [31:0] cache_rdata_reg [0:1];
    always @(posedge clk) begin
        cache_rdata_reg[0] <= data_array[0][index];
        cache_rdata_reg[1] <= data_array[1][index];
    end

    // 状态
    reg [2:0] state;
    localparam QUERY_AND_LOAD = 3'd0;
    localparam HIT_BRANCH = 3'd1;
    localparam LOAD_HIT_OUTPUT = 3'd2;
    localparam LOAD_MISS_WAIT_1 = 3'd3;
    localparam LOAD_MISS_WAIT_2 = 3'd4;
    localparam LOAD_MISS_OUTPUT = 3'd5;
    localparam STORE_HIT = 3'd6;
    localparam STORE_MISS = 3'd7;

    // 数据传递寄存器
    wire cpu_req = (cpu_req_load | cpu_req_store);
    reg cpu_req_load_reg;
    reg cpu_req_store_reg;
    reg finished;
    reg [31:0] cpu_wdata_reg, cpu_wdata_reg_reg;
    reg [31:0] cpu_addr_reg, cpu_addr_reg_reg;
    reg [1:0]  cpu_mask_reg, cpu_mask_reg_reg;
    reg [INDEX_WIDTH - 1:0] index_reg;
    reg [TAG_WIDTH - 1:0]   tag_reg;
    reg hit_way_idx;
    
    // load_miss 寄存器
    reg miss_way;
    reg [INDEX_WIDTH - 1:0]  miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    reg [31:0] miss_addr;
    reg [1:0] miss_mask;

    // 冻结流水线条件
    assign stall = cpu_req & !finished;

    integer i, w;
    always @(posedge clk) begin
        if(!rst) begin
            state       <= QUERY_AND_LOAD;
            cpu_rdata   <= 32'b0;
            finished    <= 1'b0;

            mem_en      <= 1'b0;
            mem_addr    <= 32'b0;
            mem_wdata   <= 32'b0;
            mem_we      <= 4'b0;
            mem_wen     <= 1'b0;

            // 重置寄存器
            for (w = 0; w < WAYS; w = w + 1) begin
                for (i = 0; i < LINE_NUM; i = i + 1) begin
                    valid_array[w][i] <= 1'b0;
                end
            end
            for (i = 0; i < LINE_NUM; i = i + 1) plru_state[i] <= 1'b0;
        end
        else begin  
            // 传输 DRAM
            mem_en      <= (state == QUERY_AND_LOAD) & cpu_req | state == HIT_BRANCH | state == LOAD_MISS_WAIT_1;
            mem_addr    <= (cpu_req) ? cpu_addr : 32'b0;
            mem_wdata   <= store_merge(32'b0, cpu_wdata, cpu_addr[1:0], cpu_mask);
            mem_we      <= (cpu_req_store) ? unmask(cpu_mask, cpu_addr[1:0]) : 4'b0;
            mem_wen     <= cpu_req_store & state == QUERY_AND_LOAD;

            // 状态传递
            cpu_req_load_reg    <= cpu_req_load;
            cpu_req_store_reg   <= cpu_req_store;
            cpu_wdata_reg       <= cpu_wdata;
            cpu_addr_reg        <= cpu_addr;
            cpu_mask_reg        <= cpu_mask;
            cpu_wdata_reg_reg   <= cpu_wdata_reg;
            cpu_addr_reg_reg    <= cpu_addr_reg;
            cpu_mask_reg_reg    <= cpu_mask_reg;
            index_reg           <= index;
            tag_reg             <= tag;

            // casez (hit_way)
            //     2'b?1: hit_way_idx <= 1'b0;
            //     2'b10: hit_way_idx <= 1'b1;
            //     default: hit_way_idx <= 1'b0;
            // endcase 
            hit_way_idx <= ~hit_way[0];     // 由于只有两路直接优化判断 way0 是否命中，已有 hit 在外层做判断

            case(state)
                QUERY_AND_LOAD: begin
                    // 状态判断
                    if (cpu_req_load | cpu_req_store) begin
                        state <= HIT_BRANCH;
                        finished <= 1'b0;
                    end
                end

                HIT_BRANCH: begin
                    if (cpu_req_load_reg) begin
                        if (hit) begin
                            state <= LOAD_HIT_OUTPUT;
                            finished <= 1'b1;
                        end
                        else begin
                            state <= LOAD_MISS_WAIT_1;
                            finished <= 1'b0;
                        end
                    end
                    else if (cpu_req_store_reg) begin
                        if (hit) begin
                            state <= STORE_HIT;
                            finished <= 1'b1;
                        end
                        else begin
                            state <= STORE_MISS;
                            finished <= 1'b1;
                        end
                    end
                end

                LOAD_HIT_OUTPUT: begin
                    cpu_rdata <= load_shift(cache_rdata_reg[hit_way_idx], cpu_addr_reg_reg[1:0], cpu_mask_reg_reg);
                    finished <= 1'b0;
                    state <= QUERY_AND_LOAD;
                end

                LOAD_MISS_WAIT_1: begin
                    miss_way                <= plru_state[index_reg];
                    miss_index              <= index_reg;   
                    miss_tag                <= tag_reg;
                    miss_addr               <= cpu_addr_reg_reg;
                    miss_mask               <= cpu_mask_reg_reg;

                    plru_state[index_reg]   <= ~plru_state[index_reg];
                    state                   <= LOAD_MISS_OUTPUT;
                    finished                <= 1'b1;
                end

                LOAD_MISS_WAIT_2: begin
                    // 等待接收数据
                    state       <= LOAD_MISS_OUTPUT;
                    finished    <= 1'b1;
                end

                LOAD_MISS_OUTPUT: begin
                    cpu_rdata <= load_shift(mem_rdata, miss_addr[1:0], miss_mask);
                    valid_array[miss_way][miss_index] <= 1'b1;
                    tag_array[miss_way][miss_index]   <= miss_tag;
                    data_array[miss_way][miss_index]  <= mem_rdata;
                    state <= QUERY_AND_LOAD;
                    finished <= 1'b0;
                end

                STORE_HIT: begin
                    data_array[hit_way_idx][index_reg] <= store_merge(
                        cache_rdata_reg[hit_way_idx],
                        cpu_wdata_reg_reg,
                        cpu_addr_reg_reg[1:0],
                        cpu_mask_reg_reg
                    );
                    state <= QUERY_AND_LOAD;
                    finished <= 1'b0;
                end

                STORE_MISS: begin
                    // BRAM 存储也需要停顿 可引入 store_buffer 解决
                    state <= QUERY_AND_LOAD;
                    finished <= 1'b0;
                end

            default: begin
                state <= QUERY_AND_LOAD;
                finished <= 1'b0;
            end
            endcase
        end
    end

    // 函数：
    // 将 mask 转为按位
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
                    endcase
                end
                2'b01: begin
                    case (addr_low[1])
                        1'b0: unmask = 4'b0011;
                        1'b1: unmask = 4'b1100;
                    endcase
                end
                2'b10: unmask = 4'b1111;
            endcase
        end
    endfunction


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