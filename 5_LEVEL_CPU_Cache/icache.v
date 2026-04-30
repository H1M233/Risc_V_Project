`include "rv32I.vh"




// bypass



module icache #(
    parameter INDEX_WIDTH   = 6,        // 索引宽度
    parameter TAG_WIDTH     = 24,       // tag 宽度
    parameter WAYS          = 2         // 路数
)(
    input               clk,
    input               rst,

    // CPU / IF side
    input      [31:0]   cpu_addr,
    output     [31:0]   cpu_inst,
    input               pred_mispredict,
    output              dcache_stall,  

    // IROM side
    output reg [31:0]   mem_addr,
    input      [31:0]   mem_inst
);
    localparam LINE_NUM    = 2 ** INDEX_WIDTH;  // 组数

    // ============================================================
    //
    // 命中计数器
    // reg [31:0] icache_hit;
    // reg [31:0] icache_miss;
    // always@(posedge clk) begin
    //     if(!rst) begin
    //         icache_hit  <= 32'b0;
    //         icache_miss <= 32'b0;
    //     end
    //     else begin
    //         icache_hit  <= (state == S_QUERY && hit) ? icache_hit + 1'b1 : icache_hit;
    //         icache_miss <= (state == S_QUERY && miss) ? icache_miss + 1'b1 : icache_miss;
    //     end
    // end
    //
    // ============================================================
    
    // 状态
    reg [1:0] state;
    localparam S_QUERY  = 2'd0;
    localparam S_REFILL = 2'd1;
    localparam S_OUTPUT = 2'd2;

    // 提取索引和 tag
    wire [INDEX_WIDTH - 1:0] index  = cpu_addr[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   tag    = cpu_addr[31:INDEX_WIDTH + 2];

    // 存储结构：
    (* ram_style = "block" *) reg [31:0] data_array [0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0] tag_array   [0:WAYS - 1][0:LINE_NUM - 1];
    reg valid_array [0:WAYS - 1][0:LINE_NUM - 1];

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

    reg hit;
    reg hit_s

    // 优先选择低路
    reg hit_way_idx;

    // 流水线阶段
    reg         pipe_hit    [0:2];
    reg        pipe_way [0:2];
    reg [31:0] pipe_index [0:2];
    reg        pipe_valid [0:2];
    always @(posedge clk) begin
        if(!rst) begin
            pipe_valid[0] <= 1'b0;
            pipe_valid[1] <= 1'b0;
            pipe_valid[2] <= 1'b0;
        end
        else begin

            // Stage 0: 查询
            if(!dcache_stall | pred_mispredict) begin
                pipe_valid[0] <= !flush;
                mem_addr <= cpu_addr;
            end
            else begin
                pipe_valid[0] <= 1'b0;
            end

            pipe_hit[0] <= |hit_way;
            casez (hit_way)
                2'b?1: pipe_way[0] <= 1'b0;
                2'b10: pipe_way[0] <= 1'b1;
                default: pipe_way[0] <= 1'b0;
            endcase

            // 流水线传递
            pipe_valid[1] <= pipe_valid[0] && !flush;
            pipe_valid[2] <= pipe_valid[1] && !flush;

            // Stage 1: BRAM 输入数据
            

            // Stage 2: 等待 BRAM 数据

            // Stage 3: BRAM 数据到达，判断命中并输出
            if (pipe_valid[2]) begin
                if (hit) begin
                    cpu_inst <= data_array[hit_way_idx][index];
                end
                else begin
                    cpu_inst <= mem_inst;
                end
            end
        end
    end
endmodule