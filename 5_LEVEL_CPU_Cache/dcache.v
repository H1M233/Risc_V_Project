`include "rv32I.vh"
`include "switch.vh"

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
    input      [2:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [3:0]    cpu_addr_offset,
    (* max_fanout = 20 *)
    input      [31:0]   cpu_wdata,
    input               cpu_is_signed,
    output reg [31:0]   cpu_rdata,
    (* max_fanout = 20 *)
    output              stall,

    // external DROM side
    output reg [31:0]   mem_addr,
    output reg [3:0]    mem_we,
    output reg          mem_wen,
    output reg [31:0]   mem_wdata,
    input      [31:0]   mem_rdata,

    output reg          mem_ack
);
    `ifdef ENABLE_DCACHE
    localparam LINE_NUM = 2 ** INDEX_WIDTH;
    `define ARRAY_ADDR(index, way) ((index) * WAYS + way)

    // 存储结构：
    localparam ARRAY_DEPTH = LINE_NUM * WAYS;   // vivado 不会推断二维数组为 memory
    (* ram_style = "block" *) reg [31:0] data_array[0:ARRAY_DEPTH - 1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH:0] tagv_array[0:ARRAY_DEPTH - 1];
    reg plru_state [0:LINE_NUM - 1];                // 每组的访问历史（用于选择替换哪一路）


    // 提取索引
    (* max_fanout = 30 *) reg [INDEX_WIDTH - 1:0] index;
    (* max_fanout = 30 *) reg [TAG_WIDTH - 1:0] tag;

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
            wire [TAG_WIDTH:0] tagv_hit_way = tagv_array[`ARRAY_ADDR(index, w0)];
            wire [TAG_WIDTH - 1:0] tag_hit_way = tagv_hit_way[TAG_WIDTH - 1:0];
            wire valid_hit_way = tagv_hit_way[TAG_WIDTH];

            assign hit_way[w0] = valid_hit_way && (tag_hit_way == tag);
        end
    endgenerate
    
    // DCACHE 输出缓存
    reg [31:0] cache_rdata_reg [0:1];
    wire [INDEX_WIDTH - 1:0] pred_index = cpu_addr[INDEX_WIDTH + 1:2];
    always @(posedge clk) begin
        cache_rdata_reg[0] <= data_array[`ARRAY_ADDR(pred_index, 0)];
        cache_rdata_reg[1] <= data_array[`ARRAY_ADDR(pred_index, 1)];
    end

    // 状态
    reg [2:0] state;
    localparam QUERY_AND_LOAD = 3'd0;
    localparam HIT_BRANCH = 3'd1;
    localparam LOAD_HIT_OUTPUT = 3'd2;
    localparam LOAD_MISS_WAIT = 3'd3;
    localparam LOAD_MISS_OUTPUT = 3'd4;

    // 数据传递寄存器
    reg cpu_req_load_reg;
    reg cpu_req_store_reg;
    (* max_fanout = 20 *)
    reg [31:0] cpu_wdata_reg, cpu_wdata_reg_reg;
    reg [1:0] cpu_addr_low_r, cpu_addr_low_r2;
    reg [1:0]  cpu_mask_r, cpu_mask_r2;
    reg [INDEX_WIDTH - 1:0] index_reg;
    reg [TAG_WIDTH - 1:0]   tag_reg;
    reg hit_way_idx;
    
    // load_miss 寄存器
    reg miss_way;
    reg [INDEX_WIDTH - 1:0]  miss_index;
    reg [TAG_WIDTH - 1:0] miss_tag;
    reg [1:0] miss_addr_low;
    reg [1:0] miss_mask;

    // 冻结流水线条件
    assign stall = (cpu_req_load & state == QUERY_AND_LOAD) | (cpu_req_load_reg & !hit) | (cpu_req_store & state == QUERY_AND_LOAD);

    wire [1:0] cpu_addr_low = cpu_addr[1:0];
    reg store_hit;

    // LUT as Logic
    integer i;
    initial begin
        for (i = 0; i < ARRAY_DEPTH; i = i + 1) begin
            tagv_array[i] = 0;
        end
        for (i = 0; i < LINE_NUM; i = i + 1) plru_state[i] = 1'b0;
    end
    always @(posedge clk) begin
        if (!rst) begin
            state       <= QUERY_AND_LOAD;
            cpu_rdata   <= 32'b0;

            mem_addr    <= 32'b0;
            mem_wdata   <= 32'b0;
            mem_we      <= 4'b0;
            mem_wen     <= 1'b0;
            mem_ack     <= 1'b0;
            store_hit   <= 1'b0;
        end
        else begin  
            // 传输 DRAM
            mem_addr    <= cpu_addr;
            mem_wdata   <= store_merge(32'b0, cpu_wdata, cpu_addr_low, cpu_mask);
            mem_we      <= (cpu_req_store & state == QUERY_AND_LOAD) ? unmask(cpu_mask, cpu_addr_low) : 4'b0;
            mem_wen     <= cpu_req_store & state == QUERY_AND_LOAD;

            // 状态传递
            cpu_req_load_reg    <= cpu_req_load;
            cpu_req_store_reg   <= cpu_req_store;
            cpu_wdata_reg       <= cpu_wdata;
            cpu_addr_low_r      <= cpu_addr_low;
            cpu_mask_r          <= cpu_mask;
            cpu_wdata_reg_reg   <= cpu_wdata_reg;
            cpu_addr_low_r2     <= cpu_addr_low_r;
            cpu_mask_r2         <= cpu_mask_r;
            index_reg           <= index;
            tag_reg             <= tag;

            mem_ack             <= (state == LOAD_HIT_OUTPUT | state == LOAD_MISS_OUTPUT);

            hit_way_idx         <= ~hit_way[0];     // 由于只有两路直接优化判断 way0 是否命中，已有 hit 在外层做判断

            case(state)
                QUERY_AND_LOAD: begin
                    store_hit <= 1'b0;
                    // 状态判断
                    if (cpu_req_load | cpu_req_store) begin
                        state <= HIT_BRANCH;
                    end
                end

                HIT_BRANCH: begin
                    if (cpu_req_load_reg) begin
                        if (hit) begin
                            cpu_rdata <= load_shift(cache_rdata_reg[hit_way_idx], cpu_addr_low_r, cpu_mask_r);
                            state <= QUERY_AND_LOAD;
                        end
                        else begin
                            state <= LOAD_MISS_WAIT;
                        end
                    end
                    else if (cpu_req_store_reg) begin
                        state <= QUERY_AND_LOAD;
                        store_hit   <= hit;
                    end
                end

                LOAD_HIT_OUTPUT: begin
                    cpu_rdata <= load_shift(cache_rdata_reg[hit_way_idx], cpu_addr_low_r2, cpu_mask_r2);
                    state <= QUERY_AND_LOAD;
                end

                LOAD_MISS_WAIT: begin
                    miss_way                <= plru_state[index_reg];
                    miss_index              <= index_reg;   
                    miss_tag                <= tag_reg;
                    miss_addr_low           <= cpu_addr_low_r2;
                    miss_mask               <= cpu_mask_r2;

                    plru_state[index_reg]   <= ~plru_state[index_reg];
                    state                   <= LOAD_MISS_OUTPUT;
                end

                LOAD_MISS_OUTPUT: begin
                    cpu_rdata <= load_shift(mem_rdata, miss_addr_low, miss_mask);
                    state <= QUERY_AND_LOAD;
                end
            default: begin
                state <= QUERY_AND_LOAD;
            end
            endcase
        end
    end

    // LUT as Memory
    always @(posedge clk) begin
        if (state == LOAD_MISS_OUTPUT) begin
            data_array[`ARRAY_ADDR(miss_index, miss_way)] <= mem_rdata;
            tagv_array[`ARRAY_ADDR(miss_index, miss_way)] <= {1'b1, miss_tag};
        end
        else if (store_hit) begin
            data_array[`ARRAY_ADDR(index_reg, hit_way_idx)] <= store_merge(
                cache_rdata_reg[hit_way_idx],
                cpu_wdata_reg_reg,
                cpu_addr_low_r2,
                cpu_mask_r2
            );
        end
    end
    `else
        reg [2:0] mask_r, mask_r2, mask_r3;
        reg [3:0] addr_offset_r, addr_offset_r2, addr_offset_r3;
        reg is_signed_r, is_signed_r2, is_signed_r3;
        reg [31:0] cpu_waddr_r, cpu_wdata_r;
        always @(posedge clk) begin
            mask_r          <= cpu_mask;
            mask_r2         <= mask_r;
            mask_r3         <= mask_r2;
            addr_offset_r   <= cpu_addr_offset;
            addr_offset_r2  <= addr_offset_r;
            addr_offset_r3  <= addr_offset_r2;
            is_signed_r     <= cpu_is_signed;
            is_signed_r2    <= is_signed_r;
            is_signed_r3    <= is_signed_r2;
            cpu_waddr_r     <= cpu_addr;
            cpu_wdata_r     <= cpu_wdata;

            mem_ack     <= 1'b1;
            mem_addr    <= cpu_addr;
            mem_we      <= (cpu_req_store) ? toWe(cpu_mask, cpu_addr_offset) : 4'b0;
            mem_wen     <= (cpu_req_store);
            mem_wdata   <= store_merge(cpu_wdata, cpu_mask, cpu_addr_offset);
        end
        always @(*) begin
            cpu_rdata = load_shift(mem_rdata, mask_r3, addr_offset_r3, is_signed_r3);
        end

        assign stall = 1'b0;
    `endif

    // 函数：
    function [3:0] toWe;
        input [2:0] mask;
        input [3:0] addr_offset;
        begin 
            toWe =  ({4{mask[0] & addr_offset[0]}} & 4'b0001) |
                    ({4{mask[0] & addr_offset[1]}} & 4'b0010) |
                    ({4{mask[0] & addr_offset[2]}} & 4'b0100) |
                    ({4{mask[0] & addr_offset[3]}} & 4'b1000) |
                    ({4{mask[1] & addr_offset[0]}} & 4'b0011) |
                    ({4{mask[1] & addr_offset[2]}} & 4'b1100) |
                    ({4{mask[2] & addr_offset[0]}} & 4'b1111) |
                    4'b0;
        end
    endfunction

    function [31:0] load_shift;
        input [31:0] word;
        input [2:0]  mask;
        input [3:0]  addr_offset;
        input        is_signed;
        begin 
            load_shift =    ({32{mask[0] & addr_offset[0]}} & {{24{word[7] & is_signed}}, word[7:0]}) |
                            ({32{mask[0] & addr_offset[1]}} & {{24{word[15] & is_signed}}, word[15:8]}) |
                            ({32{mask[0] & addr_offset[2]}} & {{24{word[23] & is_signed}}, word[23:16]}) |
                            ({32{mask[0] & addr_offset[3]}} & {{24{word[31] & is_signed}}, word[31:24]}) |
                            ({32{mask[1] & addr_offset[0]}} & {{16{word[15] & is_signed}}, word[15:0]}) |
                            ({32{mask[1] & addr_offset[2]}} & {{16{word[31] & is_signed}}, word[31:16]}) |
                            ({32{mask[2] & addr_offset[0]}} & word) |
                            32'b0;
        end
    endfunction

    function [31:0] store_merge;
        input [31:0] word;
        input [2:0]  mask;
        input [3:0]  addr_offset;
        begin 
            store_merge =   ({32{mask[0] & addr_offset[0]}} & {24'b0, word[7:0]}) |
                            ({32{mask[0] & addr_offset[1]}} & {16'b0, word[7:0], 8'b0}) |
                            ({32{mask[0] & addr_offset[2]}} & {8'b0, word[7:0], 16'b0}) |
                            ({32{mask[0] & addr_offset[3]}} & {word[7:0], 24'b0}) |
                            ({32{mask[1] & addr_offset[0]}} & {16'b0, word[15:0]}) |
                            ({32{mask[1] & addr_offset[2]}} & {word[15:0], 16'b0}) |
                            ({32{mask[2] & addr_offset[0]}} & word) |
                            32'b0;
        end
    endfunction
endmodule