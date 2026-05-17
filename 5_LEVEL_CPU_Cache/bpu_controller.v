`include "rv32I.vh"
`include "switch.vh"

// 预测器控制模块
// 用来让预测分为两个阶段进行：
// clock 1: 从 if 判断为需要预测的类型 在这个周期内完成对 RAS BTB Gshare 查询所需信号以及更新内容的计算 在下一个周期赋值
// clock 2: 从 RAS BTB Gshare 返回查询信号 判断是否需要并输出预测跳转地址
// clock 2: 在 clock 2 的同时 if 的指令被正常传输到 id 下一条指令正常出现在 if:
// clock 2: 若预测无需跳转 则直接让流水线进行下去
// clock 2: 若预测需要跳转 在if_id 产生气泡冲刷掉 if 此时的错误指令 并收回对 if 处指令的预测
// 数据冒险发生时 hazard_en 的暂停对预测器同样生效 以避免预测错位
module bpu_controller #(
    // 分支预测
    parameter BHR_WIDTH = 16,

    // BTB
    parameter BTB_INDEX_WIDTH = 4,

    // RAS
    parameter RAS_DEPTH = 8
)(
    input                           clk,
    input                           rst,
    
    // from if1
    input      [31:0]               pc_addr,            // if1 阶段指令地址

    // from if2
    input      [31:0]               pc_inst,            // if2 取得的指令

    // to pc & id
    (* max_fanout = 30 *)
    output reg [31:0]               pred_pc,            // 向 if 输出预测的地址
    (* max_fanout = 30 *)
    output reg                      pred_taken,         // 从 PHT 中读取的计数器高位值

    // from ex
    input                           update_btb_en,      // ex 阶段返回的 BTB 更新使能
    input                           update_gshare_en,   // ex 阶段返回的 PHT 更新使能
    input      [31:0]               update_pc,          // ex 阶段返回更新的指令地址
    input      [31:0]               update_target,      // ex 阶段返回的实际跳转地址
    input                           actual_taken,       // ex 阶段判断跳转为真

    (* max_fanout = 20 *)
    input                           pipe_hold,
    (* max_fanout = 30 *)
    input                           pred_flush_en_r,

    // Gshare - 查询
    output     [BHR_WIDTH - 1:0]    gshare_pht_index,
    output reg                      gshare_prev_b,
    input                           gshare_pred_taken,
    input      [BHR_WIDTH - 1:0]    gshare_ghr,
    input      [BHR_WIDTH - 1:0]    gshare_ghr_update,

    // Gshare - 更新
    output reg                      gshare_update_en,
    output reg [BHR_WIDTH - 1:0]    gshare_update_pht_index,
    output reg                      gshare_actual_taken,

    // ras - to bpu_controller
    (* max_fanout = 30 *)
    output reg                      ras_push_en,
    output reg                      ras_pop_en,
    output reg [31:0]               ras_push_addr,

    // ras - from bpu_controller
    input      [31:0]               ras_pop_addr,
    input                           ras_isempty,
    input                           ras_isfull,

    // btb - 查询
    (* max_fanout = 20 *)
    output reg [BTB_INDEX_WIDTH - 1:0]          btb_query_index,
    output reg [31 - BTB_INDEX_WIDTH - 2:0]     btb_query_tag,
    input                                       btb_hit,
    input      [31:0]                           btb_target_pc,

    // btb - 更新
    output reg                                  btb_update_en,
    (* max_fanout = 20 *)
    output reg [BTB_INDEX_WIDTH - 1:0]          btb_update_index,
    output reg [31 - BTB_INDEX_WIDTH - 2:0]     btb_update_tag,
    output reg [31:0]                           btb_update_target
);
    // 取出 rd 和 rs1 的地址
    wire    [4:0]   rd_addr     = pc_inst[11:7];
    wire    [4:0]   rs1_addr    = pc_inst[19:15];

    // 处理 TYPE_B
    wire            is_B_type   = (pc_inst[6:0] == `TYPE_B);
    wire    [31:0]  B_imm       = {{20{pc_inst[31]}}, pc_inst[7], pc_inst[30:25], pc_inst[11:8], 1'b0};

    // 处理 JALR
    (* max_fanout = 20 *)
    wire            is_JALR     = (pc_inst[6:0] == `JALR);
    wire    [31:0]  JALR_imm    = {{20{pc_inst[31]}}, pc_inst[31:20]};
    wire            is_ret_JALR = (is_JALR && rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm == 0);
    (* max_fanout = 20 *)
    wire            is_ras_pop  = (is_ret_JALR && !ras_isempty);

    // 处理 JAL
    wire            is_JAL      = (pc_inst[6:0] == `JAL);
    wire    [31:0]  JAL_imm     = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};
    wire            is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);
    wire            is_ras_push = (is_ret_JAL && !ras_isfull);

    (* max_fanout = 20 *)
    reg     [31:0]  pc_reg;
    wire    [31:0]  pc_add_4    = pc_reg + 32'h4;
    wire    [31:0]  pc_add_JAL  = pc_reg + JAL_imm;
    wire    [31:0]  pc_add_B    = pc_reg + B_imm;

    // 更新状态寄存
    reg update_btb_en_r;
    reg update_gshare_en_r;
    reg [31:0] update_pc_r;
    reg [31:0] update_target_r;
    reg actual_taken_r;

    // Gshare索引：取PC中间位与BHR异或
    wire [BHR_WIDTH - 1:0]  pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ gshare_ghr;
    wire [BHR_WIDTH - 1:0]  update_pht_index    = update_pc_r[BHR_WIDTH + 1:2] ^ gshare_ghr_update;

    // BTB索引和tag（tag取pc高位，用于区分映射到同一索引的不同地址）
    wire [BTB_INDEX_WIDTH - 1:0]        btb_query_index_w   = pc_addr[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_query_tag_w     = pc_addr[31:BTB_INDEX_WIDTH + 2];
    wire [BTB_INDEX_WIDTH - 1:0]        btb_update_index_w  = update_pc_r[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_w    = update_pc_r[31:BTB_INDEX_WIDTH + 2];

    // 查询
    (* max_fanout = 30 *)
    assign gshare_pht_index = (pred_taken) ? 0 : pht_index;     // 预测跳转后屏蔽查询入口
    always@(posedge clk) begin
        if (!rst) begin
            // PC
            pc_reg          <= 0;

            // RAS
            ras_pop_en      <= 0;
            ras_push_en     <= 0;
            ras_push_addr   <= 0;

            // BTB
            btb_query_index <= 0;
            btb_query_tag   <= 0;
        end
        else if (!pipe_hold) begin
            // PC
            pc_reg          <= pc_addr;

            // RAS
            ras_pop_en      <= is_ras_pop & !pred_taken;
            ras_push_en     <= is_ras_push & !pred_taken;
            ras_push_addr   <= pc_add_4;

            // BTB
            btb_query_index <= btb_query_index_w;
            btb_query_tag   <= btb_query_tag_w;
        end
    end

    // Gshare
    always @(posedge clk) begin
        if (!rst) begin
            gshare_prev_b   <= 0;
        end
        else begin
            gshare_prev_b   <= is_B_type & !pred_flush_en_r;
        end
    end
    
    // 预测结果
    `ifdef USE_CASE
        reg sel_pred_taken;
        reg [31:0] sel_pred_pc;
        always @(*) begin
            case (1'b1)
                is_ras_pop: begin
                    sel_pred_taken  = 1'b1;
                    sel_pred_pc     = ras_pop_addr;
                end
                is_B_type: begin
                    sel_pred_taken  = gshare_pred_taken;
                    sel_pred_pc     = pc_add_B;
                end
                is_JALR: begin
                    sel_pred_taken  = btb_hit;
                    sel_pred_pc     = btb_target_pc;
                end
                is_JAL: begin
                    sel_pred_taken  = 1'b1;
                    sel_pred_pc     = pc_add_JAL;
                end
                default: begin
                    sel_pred_taken  = 1'b0;
                    sel_pred_pc     = pc_add_4;
                end
            endcase
        end
    `else
        wire sel_pred_taken     =   (is_ras_pop) |
                                    (is_B_type & gshare_pred_taken) |
                                    (is_JALR & btb_hit) |
                                    (is_JAL);
        wire [31:0] sel_pred_pc =   ({32{is_ras_pop}} & ras_pop_addr) |
                                    ({32{is_B_type}}  & pc_add_B) |
                                    ({32{is_JALR}}    & btb_target_pc) |
                                    ({32{is_JAL}}     & pc_add_JAL);
    `endif

    always @(posedge clk) begin
        if (!rst) begin
            pred_taken  <= 0;
            pred_pc     <= 0;
        end
        else if (!pipe_hold) begin  // 当暂停时预测器的结果需要保存
            pred_taken  <= sel_pred_taken & !pred_taken & !pred_flush_en_r; // 避免重复预测 & 错误预测冲刷
            pred_pc     <= sel_pred_pc;
        end
    end

    // 更新寄存打拍
    always @(posedge clk) begin
        update_btb_en_r     <= update_btb_en;
        update_gshare_en_r  <= update_gshare_en;
        update_pc_r         <= update_pc;
        update_target_r     <= update_target;
        actual_taken_r      <= actual_taken;
    end

    // 更新
    always @(*) begin
        // Gshare更新
        gshare_update_en         = update_gshare_en_r;
        gshare_update_pht_index  = update_pht_index;
        gshare_actual_taken      = actual_taken_r;
    end

    always@(posedge clk) begin
        if(!rst) begin
            btb_update_en               <= 0;
            btb_update_index            <= 0;
            btb_update_tag              <= 0;
            btb_update_target           <= 0;
        end
        else begin
            // BTB更新
            btb_update_en               <= update_btb_en_r;
            btb_update_index            <= btb_update_index_w;
            btb_update_tag              <= btb_update_tag_w;
            btb_update_target           <= update_target_r;
        end
    end
endmodule