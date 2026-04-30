`include "rv32I.vh"

module dcache#(
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = 24,
    parameter WAYS          = 4
)(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req_load,
    input               cpu_req_store,
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
    // reg [31:0] dcache_hit;
    // reg [31:0] dcache_miss;
    // always@(posedge clk) begin
    //     if(!rst) begin
    //         dcache_hit  <= 32'b0;
    //         dcache_miss <= 32'b0;
    //     end
    //     else begin
    //         if(state == S_QUERY)
    //         dcache_hit  <= (state == S_OUTPUT && state == S_CHECK) ? dcache_hit + 1'b1 : dcache_hit;
    //         dcache_miss <= (state == S_WAIT && store_miss) ? dcache_miss + 1'b1 : dcache_miss;
    //     end
    // end
    //
    // ============================================================

    // 存储结构：
    (* ram_style = "block" *) reg [31:0] data_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0]   tag_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg                     valid_array[0:WAYS - 1][0:LINE_NUM - 1];
    reg [2:0]               plru_state [0:LINE_NUM - 1];  // 每组的访问历史（用于选择替换哪一路）

    // 冻结流水线条件
    // assign stall = (cpu_req_load & !(load_hit | load_miss_reg_reg)) | (cpu_req_store & !store_req);

    // 命中检测
    wire [WAYS - 1:0]   hit_way;
    genvar w0;
    generate
        for(w0 = 0; w0 < WAYS; w0 = w0 + 1) begin : hit_gen
            assign hit_way[w0] = valid_array[w0][index] && (tag_array[w0][index] == tag);
        end
    endgenerate
    
    // 读数据输出
    reg [31:0] cache_rdata_reg [0:3];
    genvar w1;
    generate
        for(w1 = 0; w1 < WAYS; w1 = w1 + 1) begin
            always @(posedge clk) begin
                cache_rdata_reg[w1] <= data_array[w1][index];
            end
        end
    endgenerate

    // 状态
    reg [2:0] state;
    localparam QUERY_AND_LOAD = 3'd0;
    localparam LOAD_HIT_OUTPUT = 3'd1;
    localparam LOAD_MISS_WAIT_1 = 3'd2;
    localparam LOAD_MISS_WAIT_2 = 3'd3;
    localparam LOAD_MISS_OUTPUT = 3'd4;
    localparam STORE_HIT    = 3'd5;
    localparam STORE_MISS = 3'd6;

    // ===================================
    // DRAM 穿透与 DCACHE 查询 - EX 阶段输入
    // ===================================
    reg load_req;
    reg store_req;
    wire hit = |hit_way;
    reg hit_reg;
    reg cpu_req_reg;
    reg [31:0] cpu_wdata_reg;
    reg [31:0] cpu_addr_reg;
    reg [1:0] cpu_mask_reg;

    wire [INDEX_WIDTH - 1:0] index = cpu_addr[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   tag = cpu_addr[31:INDEX_WIDTH + 2];
    reg [INDEX_WIDTH - 1:0] index_reg;
    reg [TAG_WIDTH - 1:0] tag_reg;

    wire cpu_req = (cpu_req_load | cpu_req_store);
    reg finished;
    assign stall = cpu_req & !finished;

    reg [1:0] hit_way_idx;      // 优先选择低路

    always @(posedge clk) begin
        if(!rst) begin
            state <= 1'b0;
        end
        else begin
            case(state)
                QUERY_AND_LOAD: begin
                    if(cpu_req) begin
                        // 清空状态
                        cpu_rdata       <= 32'b0;

                        // 传输给 DRAM
                        mem_addr        <= cpu_addr;
                        mem_wdata       <= cpu_wdata;
                        mem_mask        <= (cpu_req_store) ? cpu_mask : 2'b10;   // 读出所有内容;
                        mem_wen         <= cpu_wen;

                        // 判断命中并传递数据
                        load_req        <= cpu_req_load;
                        store_req       <= cpu_req_store;
                        hit_reg         <= hit;

                        // 状态判断
                        if (cpu_req_load) begin
                            if (hit) begin
                                state <= LOAD_HIT_OUTPUT;
                                finished <= 1'b1;
                            end
                            else begin
                                state <= LOAD_MISS_WAIT_1;
                                finished <= 1'b0;
                            end
                        end
                        else begin
                            if (hit) begin
                                state <= STORE_HIT;
                                finished <= 1'b1;
                            end
                            else begin
                                state <= STORE_MISS;
                                finished <= 1'b1;
                            end
                        end

                        cpu_req_reg     <= (cpu_req_load | cpu_req_store);
                        cpu_wdata_reg   <= cpu_wdata;
                        cpu_addr_reg    <= cpu_addr;
                        cpu_mask_reg    <= cpu_mask;

                        index_reg       <= index;
                        tag_reg         <= tag;

                        casez (hit_way)
                            4'b???1: hit_way_idx <= 2'd0;
                            4'b??10: hit_way_idx <= 2'd1;
                            4'b?100: hit_way_idx <= 2'd2;
                            4'b1000: hit_way_idx <= 2'd3;
                            default: hit_way_idx <= 2'd0;
                        endcase

                    end
                end

                LOAD_HIT_OUTPUT: begin
                    cpu_rdata <= load_shift(cache_rdata_reg[hit_way_idx], cpu_addr_reg[1:0], cpu_mask_reg);
                    finished <= 1'b0;
                    state <= QUERY_AND_LOAD;
                end

                LOAD_MISS_WAIT_1: begin
                    miss_way    <= hit_way_idx;
                    miss_index  <= index_reg;
                    miss_tag    <= tag_reg;
                    miss_addr   <= cpu_addr_reg;
                    miss_mask   <= cpu_mask_reg;
                    state       <= LOAD_MISS_WAIT_2;
                end

                LOAD_MISS_WAIT_2: begin
                    // 纯等
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
                        cpu_wdata_reg,
                        cpu_addr_reg[1:0],
                        cpu_mask_reg
                    );
                    state <= QUERY_AND_LOAD;
                    finished <= 1'b0;
                end

                STORE_MISS: begin
                    // BRAM 存储也需要停顿
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

    // ================================
    // 判断命中 - MEM 阶段
    // ================================
    
    // PLRU 更新
    reg        update_plru;
    reg [1:0]  accessed_way;
    wire        load_hit  = (load_req & hit);
    wire        load_miss = (load_req & !hit);
    reg         load_hit_reg;
    reg         load_miss_reg;
    reg         load_miss_reg_reg;
    reg         load_req_reg;

    reg [1:0]   miss_way;
    reg [INDEX_WIDTH - 1:0]  miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    reg [31:0] miss_addr;
    reg [1:0] miss_mask;

    // always @(posedge clk) begin
    //     if(!rst) begin
    //         update_plru     <= 0;
    //         accessed_way    <= 0;
    //         load_hit_reg    <= 0;
    //         load_miss_reg   <= 0;
    //         load_miss_reg_reg<= 0;
    //         load_req_reg    <= 0;

    //         miss_way        <= 0;
    //         miss_index      <= 0;
    //         miss_tag        <= 0;
    //         miss_addr       <= 0;
    //         miss_mask       <= 0;

    //     end
    //     else begin
    //         update_plru     <= (hit && (cpu_req_reg));
    //         accessed_way    <= hit_way_idx;
    //         load_hit_reg    <= load_hit;
    //         load_miss_reg   <= load_miss;
    //         load_miss_reg_reg<= load_miss_reg;
    //         load_req_reg    <= load_req;
            
    //         if(load_miss) begin
    //             miss_way    <= hit_way_idx;
    //             miss_index  <= index_reg;
    //             miss_tag    <= tag_reg;
    //             miss_addr   <= cpu_addr_reg;
    //             miss_mask   <= cpu_mask_reg;
    //         end

    //         if(store_req & hit) begin       // store_hit
    //             data_array[hit_way_idx][index_reg] <= store_merge(
    //                 cache_rdata_reg[hit_way_idx],
    //                 cpu_wdata_reg,
    //                 cpu_addr_reg[1:0],
    //                 cpu_mask_reg
    //             );
    //         end
    //     end
    // end

    // // 输出读回
    // always@(posedge clk) begin
    //     if(!rst) begin
    //         cpu_rdata <= 32'b0;
    //     end
    //     else begin
    //         if(load_hit) begin 
    //             cpu_rdata <= load_shift(cache_rdata_reg[hit_way_idx], cpu_addr_reg[1:0], cpu_mask_reg);
    //         end
    //         else if(load_miss_reg_reg) begin
    //             cpu_rdata <= load_shift(mem_rdata, miss_addr[1:0], miss_mask);
    //         end
    //         else begin
    //             cpu_rdata <= 32'b0;
    //         end
    //     end
    // end

    // // load_miss:
    // always@(posedge clk) begin
    //     if(!rst) begin
    //         // 1
    //     end
    //     else begin
    //         if(load_miss_reg) begin
    //             valid_array[miss_way][miss_index] <= 1'b1;
    //             tag_array[miss_way][miss_index]   <= miss_tag;
    //             data_array[miss_way][miss_index]  <= mem_rdata;
    //         end
    //     end
    // end

    // 主状态机
    integer i, w;
    always @(posedge clk) begin
        if (!rst) begin
            for (w = 0; w < WAYS; w = w + 1) begin
                for (i = 0; i < LINE_NUM; i = i + 1) begin
                    valid_array[w][i] <= 1'b0;
                end
            end

            for (i = 0; i < LINE_NUM; i = i + 1) plru_state[i] <= 3'b0;
        end
        else begin
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