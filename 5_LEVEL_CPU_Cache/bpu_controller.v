`include "rv32I.vh"

// 预测器控制模块
// 用来让预测分为两个阶段进行：
// clock 1: 从 if 判断为需要预测的类型，在这个周期内完成对 RAS、BTB、Gshare 查询所需信号以及更新内容的计算，在下一个周期赋值
// clock 2: 从 RAS、BTB、Gshare 返回查询信号，判断是否需要并输出预测跳转地址
// 数据冒险、I-cache block、D-cache stall 发生时 hazard_en 的暂停对预测器同样生效，以避免预测错位
module bpu_controller #(
    // 分支预测
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024,

    // RAS
    parameter RAS_DEPTH = 8,
    parameter PTR_WIDTH = $clog2(RAS_DEPTH)
)(
    input                           clk,
    input                           rst,
    
    // from if
    input      [31:0]               pc_addr,
    input      [31:0]               pc_inst,

    // to pc & id
    output reg [31:0]               pred_pc,
    output reg                      pred_taken,

    // from ex
    input                           update_btb_en,
    input                           update_gshare_en,
    input      [31:0]               update_pc,
    input      [31:0]               update_target,
    input                           actual_taken,
    input                           pred_mispredict,

    // from hazard / cache stall
    input                           hazard_en,

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

    // RAS - to ras
    output reg                      ras_push_en,
    output reg                      ras_pop_en,
    output reg [31:0]               ras_push_addr,

    // RAS - from ras
    input      [31:0]               ras_pop_addr,
    input                           ras_isempty,
    input                           ras_isfull,

    // BTB - 查询
    output reg [31:0]               btb_query_pc,
    input                           btb_hit,
    input      [31:0]               btb_target_pc,

    // BTB - 更新
    output reg                      btb_update_en,
    output reg [31:0]               btb_update_pc,
    output reg [31:0]               btb_update_target
);
    // 取出 rd 和 rs1 的地址
    wire [4:0]   rd_addr     = pc_inst[11:7];
    wire [4:0]   rs1_addr    = pc_inst[19:15];

    // TYPE_B
    wire         is_b_type   = (pc_inst[6:0] == `TYPE_B);
    wire [31:0] b_imm       = {{20{pc_inst[31]}}, pc_inst[7], pc_inst[30:25], pc_inst[11:8], 1'b0};

    // JALR
    wire         is_JALR     = (pc_inst[6:0] == `JALR);
    wire [31:0] JALR_imm    = {{20{pc_inst[31]}}, pc_inst[31:20]};
    wire         is_ret_JALR = (is_JALR && rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm == 0);
    wire         is_ras_pop  = (is_ret_JALR && !ras_isempty);

    // JAL
    wire         is_JAL      = (pc_inst[6:0] == `JAL);
    wire [31:0] JAL_imm     = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};
    wire         is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);
    wire         is_ras_push = (is_ret_JAL && !ras_isfull);

    // 综合计算以减少资源占用
    wire [31:0] imm          = (is_JAL) ? JAL_imm :
                               (is_b_type) ? b_imm :
                               32'b0;

    wire [31:0] pc_add_4     = pc_addr + 32'h4;
    wire [31:0] pc_add_imm   = pc_addr + imm;

    // 存储预测结果至第二个预测周期
    reg [31:0]  pred_next_pc;
    reg         prev_JAL;
    reg         prev_JALR;
    reg         prev_JALR_ret;

    // Gshare 索引：取 PC 中间位与 BHR 异或
    wire [BHR_WIDTH - 1:0] pht_index        = pc_addr[BHR_WIDTH + 1:2] ^ gshare_ghr;
    wire [BHR_WIDTH - 1:0] update_pht_index = update_pc[BHR_WIDTH + 1:2] ^ gshare_ghr_d2;

    // ============================================================
    // 预测结果组合逻辑
    // ============================================================
    always @(*) begin
        if(prev_JALR_ret) begin
            pred_taken = 1'b1;
            pred_pc    = ras_pop_addr;
        end
        else if(gshare_prev_b && gshare_pred_taken) begin
            pred_taken = 1'b1;
            pred_pc    = pred_next_pc;
        end
        else if(prev_JALR && btb_hit) begin
            pred_taken = 1'b1;
            pred_pc    = btb_target_pc;
        end
        else if(prev_JAL) begin
            pred_taken = 1'b1;
            pred_pc    = pred_next_pc;
        end
        else begin
            pred_taken = 1'b0;
            pred_pc    = pc_add_4;
        end
    end

    // ============================================================
    // 查询阶段寄存
    //
    // 关键优先级：
    // reset / mispredict > hazard_en > pred_taken > normal
    //
    // hazard_en 现在不仅表示 load-use hazard，
    // 还包括 dcache_stall 和 icache_block。
    // stall 时必须保持上一拍 BPU 查询状态，不能因为 pred_taken 把它清掉。
    // ============================================================
    always @(posedge clk) begin
        if(!rst || pred_mispredict) begin
            // TYPE_B
            gshare_prev_b       <= 1'b0;
            pred_next_pc        <= 32'b0;
            gshare_pht_index    <= {BHR_WIDTH{1'b0}};

            // JALR
            prev_JALR           <= 1'b0;
            prev_JALR_ret       <= 1'b0;
            ras_pop_en          <= 1'b0;
            btb_query_pc        <= 32'b0;

            // JAL
            prev_JAL            <= 1'b0;
            ras_push_en         <= 1'b0;
            ras_push_addr       <= 32'b0;
        end
        else if(hazard_en) begin
            // stall 时保持所有查询相关寄存器不变
            gshare_prev_b       <= gshare_prev_b;
            pred_next_pc        <= pred_next_pc;
            gshare_pht_index    <= gshare_pht_index;

            prev_JALR           <= prev_JALR;
            prev_JALR_ret       <= prev_JALR_ret;
            ras_pop_en          <= ras_pop_en;
            btb_query_pc        <= btb_query_pc;

            prev_JAL            <= prev_JAL;
            ras_push_en         <= ras_push_en;
            ras_push_addr       <= ras_push_addr;
        end
        else if(pred_taken) begin
            // 预测跳转已被 PC/IF_ID 接收后，清掉上一拍预测状态
            gshare_prev_b       <= 1'b0;
            pred_next_pc        <= 32'b0;
            gshare_pht_index    <= {BHR_WIDTH{1'b0}};

            prev_JALR           <= 1'b0;
            prev_JALR_ret       <= 1'b0;
            ras_pop_en          <= 1'b0;
            btb_query_pc        <= 32'b0;

            prev_JAL            <= 1'b0;
            ras_push_en         <= 1'b0;
            ras_push_addr       <= 32'b0;
        end
        else begin
            // TYPE_B
            gshare_prev_b       <= is_b_type;
            pred_next_pc        <= pc_add_imm;
            gshare_pht_index    <= pht_index;

            // JALR
            prev_JALR           <= is_JALR;
            prev_JALR_ret       <= is_ras_pop;
            ras_pop_en          <= is_ras_pop;
            btb_query_pc        <= pc_addr;

            // JAL
            prev_JAL            <= is_JAL;
            ras_push_en         <= is_ras_push;
            ras_push_addr       <= pc_add_4;
        end
    end

    // ============================================================
    // 更新阶段
    // ============================================================
    always @(posedge clk) begin
        if(!rst) begin
            // BTB 更新
            btb_update_en           <= 1'b0;
            btb_update_pc           <= 32'b0;
            btb_update_target       <= 32'b0;

            // Gshare 更新
            gshare_update_en        <= 1'b0;
            gshare_update_pht_index <= {BHR_WIDTH{1'b0}};
            gshare_actual_taken     <= 1'b0;
            gshare_pred_mispredict  <= 1'b0;
        end
        else begin
            // BTB 更新
            btb_update_en           <= update_btb_en;
            btb_update_pc           <= update_pc;
            btb_update_target       <= update_target;
            
            // Gshare 更新
            gshare_update_en        <= update_gshare_en;
            gshare_update_pht_index <= update_pht_index;
            gshare_actual_taken     <= actual_taken;
            gshare_pred_mispredict  <= pred_mispredict;
        end
    end

endmodule