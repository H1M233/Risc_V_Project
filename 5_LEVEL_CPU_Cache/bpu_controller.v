`include "rv32I.vh"

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
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024,

    // BTB
    parameter BTB_INDEX_WIDTH = 4,

    // RAS
    parameter RAS_DEPTH = 8,
    parameter PTR_WIDTH = $clog2(RAS_DEPTH)
)(
    input                           clk,
    input                           rst,
    
    // from if1
    input      [31:0]               pc_addr,            // if1 阶段指令地址

    // from if2
    input      [31:0]               pc_inst,            // if2 取得的指令

    // to pc & id
    output reg [31:0]               pred_pc,            // 向 if 输出预测的地址
    output reg                      pred_taken,         // 从 PHT 中读取的计数器高位值

    // from ex
    input                           update_btb_en,      // ex 阶段返回的 BTB 更新使能
    input                           update_gshare_en,   // ex 阶段返回的 PHT 更新使能
    input      [31:0]               update_pc,          // ex 阶段返回更新的指令地址
    input      [31:0]               update_target,      // ex 阶段返回的实际跳转地址
    input                           actual_taken,       // ex 阶段判断跳转为真
    input                           pred_mispredict,    // ex 阶段判断预测错误

    input                           pipe_flush,
    input                           pipe_hold,

    // Gshare - 查询
    output reg [BHR_WIDTH - 1:0]    gshare_pht_index,
    output reg                      gshare_prev_b,
    input                           gshare_pred_taken,
    input      [BHR_WIDTH - 1:0]    gshare_ghr,
    input      [BHR_WIDTH - 1:0]    gshare_ghr_d2,

    // Gshare - 更新
    output reg                      gshare_update_en,
    output reg [BHR_WIDTH - 1:0]    gshare_update_pht_index,
    output reg                      gshare_actual_taken,
    output reg                      gshare_pred_mispredict,

    // ras - to bpu_controller
    output reg                      ras_push_en,
    output reg                      ras_pop_en,
    output reg [31:0]               ras_push_addr,

    // ras - from bpu_controller
    input      [31:0]               ras_pop_addr,
    input                           ras_isempty,
    input                           ras_isfull,

    // btb - 查询
    output reg [BTB_INDEX_WIDTH - 1:0]          btb_query_index,
    output reg [31 - BTB_INDEX_WIDTH - 2:0]     btb_query_tag,
    input                                       btb_hit,
    input      [31:0]                           btb_target_pc,

    // btb - 更新
    output reg                                  btb_update_en,
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
    wire            is_JALR     = (pc_inst[6:0] == `JALR);
    wire    [31:0]  JALR_imm    = {{20{pc_inst[31]}}, pc_inst[31:20]};
    wire            is_ret_JALR = (is_JALR && rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm == 0);
    wire            is_ras_pop  = (is_ret_JALR && !ras_isempty);

    // 处理 JAL
    wire            is_JAL      = (pc_inst[6:0] == `JAL);
    wire    [31:0]  JAL_imm     = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};
    wire            is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);
    wire            is_ras_push = (is_ret_JAL && !ras_isfull);

    reg     [31:0]  pc_reg, pc_add_4_reg;
    wire    [31:0]  pc_add_4    = pc_reg + 32'h4;
    wire    [31:0]  pc_add_JAL  = pc_reg + JAL_imm;
    wire    [31:0]  pc_add_B    = pc_reg + B_imm;

    // Gshare索引：取PC中间位与BHR异或
    wire [BHR_WIDTH - 1:0]  pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ gshare_ghr;
    wire [BHR_WIDTH - 1:0]  update_pht_index    = update_pc[BHR_WIDTH + 1:2] ^ gshare_ghr_d2;

    // BTB索引和tag（tag取pc高位，用于区分映射到同一索引的不同地址）
    wire [BTB_INDEX_WIDTH - 1:0]        btb_query_index_w   = pc_addr[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_query_tag_w     = pc_addr[31:BTB_INDEX_WIDTH + 2];
    wire [BTB_INDEX_WIDTH - 1:0]        btb_update_index_w  = update_pc[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_w    = update_pc[31:BTB_INDEX_WIDTH + 2];

    // 查询
    always@(posedge clk) begin
        if (!rst) begin
            // PC
            pc_reg              <= 0;

            // TYPE_B
            gshare_pht_index    <= 0;

            // JALR
            btb_query_index     <= 0;
            btb_query_tag       <= 0;
        end
        if (pipe_flush) begin       // 冲刷查询入口 避免下一个错误地址进入
            // PC
            pc_reg              <= 0;

            // TYPE_B
            gshare_pht_index    <= 0;

            // JALR
            btb_query_index     <= 0;
            btb_query_tag       <= 0;
        end
        else if (!pipe_hold) begin
            // PC
            pc_reg              <= pc_addr;

            // TYPE_B
            gshare_pht_index    <= pht_index;

            // JALR
            btb_query_index     <= btb_query_index_w;
            btb_query_tag       <= btb_query_tag_w;
        end
    end
    
    // 预测结果
    always @(posedge clk) begin
        if (!rst) begin
            pred_taken      <= 0;
            pred_pc         <= 0;
        end
        else if (pipe_flush) begin     // ex 确认错误再归零
            pred_taken      <= 0;
            pred_pc         <= 0;
        end
        else if (!pipe_hold) begin
            if (is_ras_pop) begin
                pred_taken  <= 1'b1;
                pred_pc     <= ras_pop_addr;
            end
            else if (is_B_type) begin
                pred_taken  <= gshare_pred_taken;
                pred_pc     <= pc_add_B;
            end
            else if (is_JALR) begin
                pred_taken  <= btb_hit;
                pred_pc     <= btb_target_pc;
            end
            else if (is_JAL) begin
                pred_taken  <= 1'b1;
                pred_pc     <= pc_add_JAL;
            end
            else begin
                pred_taken  <= 1'b0;
                pred_pc     <= pc_add_4_reg;
            end
        end
    end
    always @(posedge clk) begin
        if (!rst) begin
            // RAS
            ras_pop_en      <= 0;
            ras_push_en     <= 0;
            ras_push_addr   <= 0;

            // Gshare
            gshare_prev_b   <= 0;
        end
        if (pipe_flush) begin
            // RAS - 弹栈入栈只能一个周期
            ras_pop_en      <= 0;
            ras_push_en     <= 0;
        end
        else if (!pipe_hold) begin
            // RAS
            ras_pop_en      <= is_ras_pop;
            ras_push_en     <= is_ras_push;
            ras_push_addr   <= pc_add_4;

            // Gshare
            gshare_prev_b   <= is_B_type;
        end
    end

    // 更新
    always@(posedge clk) begin
        if(!rst) begin
            // BTB更新
            btb_update_en               <= 0;
            btb_update_index            <= 0;
            btb_update_tag              <= 0;
            btb_update_target           <= 0;

            // Gshare更新
            gshare_update_en            <= 0;
            gshare_update_pht_index     <= 0;
            gshare_actual_taken         <= 0;
            gshare_pred_mispredict      <= 0;
        end
        else begin
            // BTB更新
            btb_update_en <= update_btb_en;
            if (update_btb_en) begin
                btb_update_index            <= btb_update_index_w;
                btb_update_tag              <= btb_update_tag_w;
                btb_update_target           <= update_target;
            end
            
            // Gshare更新
            gshare_update_en <= update_gshare_en;
            if (update_gshare_en) begin
                gshare_update_pht_index     <= update_pht_index;
                gshare_actual_taken         <= actual_taken;
                gshare_pred_mispredict      <= pred_mispredict;
            end
        end
    end
endmodule