`include "rv32I.vh"
module bpu_controller #(
    // 分支预测
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024,

    // RAS
    parameter RAS_DEPTH = 8,
    parameter PTR_WIDTH = $clog2(RAS_DEPTH)
)(
    input               clk,
    input               rst,
    
    // from if
    input      [31:0]   pc_addr,            // if阶段指令地址
    input      [31:0]   pc_inst,            // if取得的指令

    // to pc & id
    output reg [31:0]   pred_pc,            // 向if输出预测的地址
    output reg          pred_taken,         // 从PHT中读取的计数器高位值

    // from ex
    input               update_btb_en,      // ex阶段返回的BTB更新使能
    input               update_gshare_en,   // ex阶段返回的PHT更新使能
    input      [31:0]   update_pc,          // ex阶段返回更新的指令地址
    input      [31:0]   update_target,      // ex阶段返回的实际跳转地址
    input               actual_taken,       // ex阶段判断跳转为真
    input               pred_mispredict,    // ex阶段判断预测错误

    // from hazard
    input               hazard_en,

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
    output reg [31:0]               btb_query_pc,
    input                           btb_hit,
    input      [31:0]               btb_target_pc,

    // btb - 更新
    output reg                      btb_update_en,
    output reg [31:0]               btb_update_pc,
    output reg [31:0]               btb_update_target
);
    // 取指得出rd和rs1的地址
    wire    [4:0]   rd_addr     = pc_inst[11:7];
    wire    [4:0]   rs1_addr    = pc_inst[19:15];

    // 处理TYPE_B
    wire            is_b_type   = (pc_inst[6:0] == `TYPE_B);
    wire    [31:0]  b_imm       = {{20{pc_inst[31]}}, pc_inst[7], pc_inst[30:25], pc_inst[11:8], 1'b0};

    // 处理JALR
    wire            is_JALR     = (pc_inst[6:0] == `JALR);
    wire    [31:0]  JALR_imm    = {{20{pc_inst[31]}}, pc_inst[31:20]};
    wire            is_ret_JALR = (is_JALR && rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm == 0);
    wire            is_ras_pop  = (is_ret_JALR && !ras_isempty);

    // 处理JAL
    wire            is_JAL      = (pc_inst[6:0] == `JAL);
    wire    [31:0]  JAL_imm     = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};
    wire            is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);
    wire            is_ras_push = (is_ret_JAL && !ras_isfull);

    wire    [31:0]  imm         = (is_JAL) ? JAL_imm : (is_b_type) ? b_imm : 32'b0;
    wire    [31:0]  pc_add_4    = pc_addr + 32'h4;
    wire    [31:0]  pc_add_imm  = pc_addr + imm;

    reg     [31:0]  pred_next_pc;
    reg             prev_JAL, prev_JALR, prev_JALR_ret;

    // Gshare索引：取PC中间位与BHR异或
    wire [BHR_WIDTH - 1:0]  pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ gshare_ghr;
    wire [BHR_WIDTH - 1:0]  update_pht_index    = update_pc[BHR_WIDTH + 1:2] ^ gshare_ghr_d2;

    // 预测结果
    always@(*) begin
        if(prev_JALR_ret) begin
            pred_taken  = 1'b1;
            pred_pc     = ras_pop_addr;
        end
        else if(gshare_prev_b && gshare_pred_taken) begin
            pred_taken  = 1'b1;
            pred_pc     = pred_next_pc;
        end
        else if(prev_JALR && btb_hit) begin
            pred_taken  = 1'b1;
            pred_pc     = btb_target_pc;
        end
        else if(prev_JAL) begin
            pred_taken  = 1'b1;
            pred_pc     = pred_next_pc;
        end
        else begin
            pred_taken  = 1'b0;
            pred_pc     = pc_add_4;
        end
    end

    // 查询
    always@(posedge clk) begin
        if(!rst || pred_mispredict || pred_taken) begin
            // TYPE_B
            gshare_prev_b       <= 0;
            pred_next_pc        <= 0;
            gshare_pht_index    <= 0;

            // JALR
            prev_JAL            <= 0;
            prev_JALR_ret       <= 0;
            ras_pop_en          <= 0;
            btb_query_pc        <= 0;

            // JAL
            prev_JAL            <= 0;
            ras_push_en         <= 0;
            ras_push_addr       <= 0;
        end
        else if(hazard_en) begin
            // hazard发生时暂停
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

    // 更新
    always@(posedge clk) begin
        if(!rst) begin
            // BTB更新
            btb_update_en               <= 0;
            btb_update_pc               <= 0;
            btb_update_target           <= 0;

            // Gshare更新
            gshare_update_en            <= 0;
            gshare_update_pht_index     <= 0;
            gshare_actual_taken         <= 0;
            gshare_pred_mispredict      <= 0;
        end
        else begin
            // BTB更新
            btb_update_en               <= update_btb_en;
            btb_update_pc               <= update_pc;
            btb_update_target           <= update_target;
            
            // Gshare更新
            gshare_update_en            <= update_gshare_en;
            gshare_update_pht_index     <= update_pht_index;
            gshare_actual_taken         <= actual_taken;
            gshare_pred_mispredict      <= pred_mispredict;
        end
    end
endmodule