`include "rv32I.vh"

module icache #(
    parameter INDEX_WIDTH   = 6,        // 索引宽度
    parameter TAG_WIDTH     = 24,       // tag 宽度
    parameter WAYS          = 4         // 路数
)(
    input               clk,
    input               rst,

    // CPU / IF side
    input      [31:0]   cpu_pc,
    output reg [31:0]   cpu_inst,
    input               pipe_hold,

    // IROM side
    output     [31:0]   mem_addr,
    input      [31:0]   mem_inst
);
    localparam LINE_NUM    = 2 ** INDEX_WIDTH;  // 组数

    // 提取索引和 tag
    wire [INDEX_WIDTH - 1:0] index  = cpu_pc[INDEX_WIDTH + 1:2];
    wire [TAG_WIDTH - 1:0]   tag    = cpu_pc[31:INDEX_WIDTH + 2];

    // 存储结构：
    (* ram_style = "block" *) reg [31:0] data_array [0:WAYS - 1][0:LINE_NUM - 1];
    reg [TAG_WIDTH - 1:0]   tag_array   [0:WAYS - 1][0:LINE_NUM - 1];
    reg                     valid_array [0:WAYS - 1][0:LINE_NUM - 1];

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
        // PLRU 树的叶节点选择
        // plru_state[2]: way0/1 vs way2/3 的选择
        // plru_state[1]: way0 vs way1
        // plru_state[0]: way2 vs way3
        if (plru_state[index][2] == 1'b0) begin
            // 左侧 (way0/1) 更近被使用，选右侧 (way2/3)
            if (plru_state[index][0] == 1'b0)
                replace_way = 2'd2;
            else
                replace_way = 2'd3;
        end else begin
            // 右侧 (way2/3) 更近被使用，选左侧 (way0/1)
            if (plru_state[index][1] == 1'b0)
                replace_way = 2'd0;
            else
                replace_way = 2'd1;
        end
    end

    // PLRU更新
    wire        update_plru     = hit;
    wire [1:0]  accessed_way    = hit_way_idx;

    assign mem_addr = cpu_pc;

   // 主状态机
    integer i, w;
    always @(posedge clk) begin
        if (!rst) begin
            cpu_inst        <= 0;

            // 清除所有 valid
            for (w = 0; w < WAYS; w = w + 1) begin
                for (i = 0; i < LINE_NUM; i = i + 1) begin
                    valid_array[w][i] <= 1'b0;
                end
            end

            // 初始化 PLRU 状态
            for (i = 0; i < LINE_NUM; i = i + 1) plru_state[i] <= 3'b0;
        end 
        else begin
            if (pipe_hold) begin
                cpu_inst <= cpu_inst;
            end
            else begin
                if (hit) begin
                    cpu_inst                        <= data_array[hit_way_idx][index];
                end
                if (miss) begin
                    cpu_inst                        <= mem_inst;
                    valid_array[replace_way][index] <= 1'b1;
                    tag_array[replace_way][index]   <= tag;
                    data_array[replace_way][index]  <= mem_inst;
                end
            end

            // PLRU 更新（独立于状态机）
            if (update_plru) begin
                // 基于访问的路更新 PLRU 树
                case (accessed_way)
                    2'd0: begin
                        plru_state[index][2] <= 1'b0;  // 左侧被使用
                        plru_state[index][1] <= 1'b0;  // way0 被使用
                    end
                    2'd1: begin
                        plru_state[index][2] <= 1'b0;
                        plru_state[index][1] <= 1'b1;  // way1 被使用
                    end
                    2'd2: begin
                        plru_state[index][2] <= 1'b1;  // 右侧被使用
                        plru_state[index][0] <= 1'b0;  // way2 被使用
                    end
                    2'd3: begin
                        plru_state[index][2] <= 1'b1;
                        plru_state[index][0] <= 1'b1;  // way3 被使用
                    end
                endcase
            end
        end
    end
endmodule