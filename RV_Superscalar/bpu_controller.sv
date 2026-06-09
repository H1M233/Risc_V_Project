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
    parameter BHR_WIDTH = 10,
    parameter PHT_IDX_WIDTH = 12,

    // BTB
    parameter BTB_INDEX_WIDTH = 4,

    // RAS
    parameter RAS_DEPTH = 8
)(
    input                           clk,
    input                           rst,
    
    // from if1
    input logic [31:0]              slot0_pc_addr,
    input logic [31:0]              slot1_pc_addr,

    // from if2
    input      [31:0]               slot0_pc_addr_if2,
    input      [31:0]               slot1_pc_addr_if2,
    input      [31:0]               slot0_pc_inst,
    input      [31:0]               slot1_pc_inst,

    // to pc & id
    output logic [31:0]             pred_pc,            // 向 if 输出预测的地址
    output logic                    pred_taken,         // 从 PHT 中读取的计数器高位值
    output logic                    slot0_pred_taken,
    output logic                    slot1_pred_taken,
    output logic [31:0]             slot0_pred_pc,
    output logic [31:0]             slot1_pred_pc,
    output logic [3:0]              ras_snapshot,
    output logic                    slot0_is_ret,
    output logic                    slot1_is_ret,
    
    // from ex
    input                           update_gshare_en,   // ex 阶段返回的 PHT 更新使能
    input                           actual_taken,       // ex 阶段判断跳转为真
    input                           update_btb_en,      // ex 阶段返回的 BTB 更新使能
    input      [31:0]               btb_update_pc,      // ex 阶段返回更新 BTB 的指令地址
    input      [31:0]               update_target,      // ex 阶段返回的实际跳转地址
    input      [31:0]               gshare_update_pc,   // ex 阶段返回更新的指令地址

    (* max_fanout = 20 *)
    input                           pipe_hold,
    (* max_fanout = 30 *)
    input                           pipe_flush,

    // Gshare - 查询
    output     [BHR_WIDTH - 1:0]    gshare_pht_index,
    output reg                      gshare_prev_b,
    input                           gshare_pred_taken,
    input      [BHR_WIDTH - 1:0]    gshare_ghr,
    input      [BHR_WIDTH - 1:0]    gshare_ghr_update,

    // Gshare - 更新
    output                          gshare_update_en,
    output     [BHR_WIDTH - 1:0]    gshare_update_pht_index,
    output                          gshare_actual_taken,

    // ras - from bpu_controller
    (* max_fanout = 30 *)
    output reg                      ras_push_en,
    output reg                      ras_pop_en,
    output reg [31:0]               ras_push_addr,

    // ras - to bpu_controller
    input      [31:0]               ras_pop_addr,
    input                           ras_isempty,
    input                           ras_isfull,
    input      [3:0]                ras_ptr,

    // btb - 查询
    (* max_fanout = 20 *)
    output reg [BTB_INDEX_WIDTH - 1:0]          slot0_btb_query_index,
    output reg [BTB_INDEX_WIDTH - 1:0]          slot1_btb_query_index,
    output reg [31 - BTB_INDEX_WIDTH - 2:0]     slot0_btb_query_tag,
    output reg [31 - BTB_INDEX_WIDTH - 2:0]     slot1_btb_query_tag,
    input                                       slot0_btb_hit,
    input                                       slot1_btb_hit,
    input      [31:0]                           slot0_btb_target_pc,
    input      [31:0]                           slot1_btb_target_pc,

    // btb - 更新
    output                                      btb_update_en,
    (* max_fanout = 20 *)
    output     [BTB_INDEX_WIDTH - 1:0]          btb_update_index,
    output     [31 - BTB_INDEX_WIDTH - 2:0]     btb_update_tag,
    output     [31:0]                           btb_update_target
);
    // 只对 slot0 进行预测 slot1 仍然接管 JAL 和 call & ret 操作
    // call:
    // slot0 call, slot1 none -> 接收 slot0 & 冲刷 slot1
    // slot0 none, slot1 call -> 接收 slot1
    // slot0 call, slot1 call -> 接收 slot0 & 冲刷 slot1
    // ret:
    // slot0  ret, slot1 none -> 弹栈 & 冲刷 slot1
    // slot0 none, slot1  ret -> 弹栈
    // slot0  ret, slot1  ret -> 弹栈 & 冲刷 slot1
    //
    // 发生 pred_taken -> 冲刷 slot1


    // 取出 rd 和 rs1 的地址
    wire    [4:0]   slot0_rd_addr   = slot0_pc_inst[11:7];
    wire    [4:0]   slot0_rs1_addr  = slot0_pc_inst[19:15];

    wire    [4:0]   slot1_rd_addr   = slot1_pc_inst[11:7];
    wire    [4:0]   slot1_rs1_addr  = slot1_pc_inst[19:15];

    // 处理 TYPE_B
    wire            slot0_is_B   = (slot0_pc_inst[6:0] == `TYPE_B);
    wire    [31:0]  B_imm       = {{20{slot0_pc_inst[31]}}, slot0_pc_inst[7], slot0_pc_inst[30:25], slot0_pc_inst[11:8], 1'b0};

    // 处理 JALR
    wire            slot0_is_JALR   = (slot0_pc_inst[6:0] == `JALR);
    wire            slot1_is_JALR   = (slot1_pc_inst[6:0] == `JALR);

    wire            slot0_check_ret = (slot0_rd_addr == 5'b0 && slot0_rs1_addr == 5'b00001 && slot0_pc_inst[31:20] == 12'b0);
    wire            slot1_check_ret = (slot1_rd_addr == 5'b0 && slot1_rs1_addr == 5'b00001 && slot1_pc_inst[31:20] == 12'b0);

    assign          slot0_is_ret    = (slot0_is_JALR && slot0_check_ret);
    assign          slot1_is_ret    = (slot1_is_JALR && slot1_check_ret);
    wire            is_ret          = slot0_is_ret || (!slot0_sel_pred_taken && slot1_is_ret);

    wire            slot0_is_btb_JALR = (slot0_is_JALR && !slot0_check_ret);
    wire            slot1_is_btb_JALR = (!slot0_sel_pred_taken && slot1_is_JALR && !slot1_check_ret);
    wire            slot0_ras_can_pop = (slot0_is_ret && !ras_isempty);
    wire            slot1_ras_can_pop = (!slot0_sel_pred_taken && slot1_is_ret && !ras_isempty);
    wire            ras_can_pop     = (is_ret && !ras_isempty);

    // 处理 JAL
    wire            slot0_is_JAL    = (slot0_pc_inst[6:0] == `JAL);
    wire            slot1_is_JAL    = (slot1_pc_inst[6:0] == `JAL);

    wire    [31:0]  slot0_JAL_imm   = {{12{slot0_pc_inst[31]}}, slot0_pc_inst[19:12], slot0_pc_inst[20], slot0_pc_inst[30:21], 1'b0};
    wire    [31:0]  slot1_JAL_imm   = {{12{slot1_pc_inst[31]}}, slot1_pc_inst[19:12], slot1_pc_inst[20], slot1_pc_inst[30:21], 1'b0};

    wire            slot0_is_call   = (slot0_is_JAL && slot0_rd_addr == 5'b00001);
    wire            slot1_is_call   = (slot1_is_JAL && slot1_rd_addr == 5'b00001);
    wire            is_call         = slot0_is_call || (!slot0_sel_pred_taken && slot1_is_call);

    wire            is_ras_push     = (is_call && !ras_isfull);

    // 地址计算
    wire    [31:0]  pc_add_slot0_4      = slot0_pc_addr_if2 + 32'h4;
    wire    [31:0]  pc_add_slot1_4      = slot1_pc_addr_if2 + 32'h4;
    wire    [31:0]  pc_add_4            = (slot0_is_call) ? pc_add_slot0_4 : pc_add_slot1_4;

    wire    [31:0]  pc_add_slot0_JAL    = slot0_pc_addr_if2 + slot0_JAL_imm;
    wire    [31:0]  pc_add_slot1_JAL    = slot1_pc_addr_if2 + slot1_JAL_imm;

    wire    [31:0]  pc_add_B            = slot0_pc_addr_if2 + B_imm;

    // Gshare索引：取PC中间位与BHR异或
    wire [PHT_IDX_WIDTH - 1:0]  pht_index           = slot0_pc_addr[PHT_IDX_WIDTH + 1:2] ^ {{(PHT_IDX_WIDTH - BHR_WIDTH){1'b0}}, gshare_ghr};
    wire [PHT_IDX_WIDTH - 1:0]  update_pht_index    = gshare_update_pc[PHT_IDX_WIDTH + 1:2] ^ {{(PHT_IDX_WIDTH - BHR_WIDTH){1'b0}}, gshare_ghr_update};

    // BTB索引和tag（tag取pc高位，用于区分映射到同一索引的不同地址）
    wire [BTB_INDEX_WIDTH - 1:0]        slot0_btb_query_index_w   = slot0_pc_addr[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   slot0_btb_query_tag_w     = slot0_pc_addr[31:BTB_INDEX_WIDTH + 2];
    wire [BTB_INDEX_WIDTH - 1:0]        slot1_btb_query_index_w   = slot1_pc_addr[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   slot1_btb_query_tag_w     = slot1_pc_addr[31:BTB_INDEX_WIDTH + 2];
    wire [BTB_INDEX_WIDTH - 1:0]        btb_update_index_w  = btb_update_pc[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_w    = btb_update_pc[31:BTB_INDEX_WIDTH + 2];

    // 查询
    (* max_fanout = 30 *)
    assign gshare_pht_index = (pipe_flush) ? 0 : pht_index;     // 预测跳转后屏蔽查询入口
    always_ff @(posedge clk) begin
        if (!rst) begin
            // RAS
            ras_push_addr   <= 0;

            // BTB
            slot0_btb_query_index <= 0;
            slot1_btb_query_index <= 0;
            slot0_btb_query_tag   <= 0;
            slot1_btb_query_tag   <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else begin
            // RAS
            ras_push_addr   <= pc_add_4;

            // BTB
            slot0_btb_query_index <= slot0_btb_query_index_w;
            slot1_btb_query_index <= slot1_btb_query_index_w;
            slot0_btb_query_tag   <= slot0_btb_query_tag_w;
            slot1_btb_query_tag   <= slot1_btb_query_tag_w;
        end
    end

    // 查询更新使能 - 受冲刷影响
    always_ff @(posedge clk) begin
        if (!rst) begin
            // RAS
            ras_pop_en      <= 0;
            ras_push_en     <= 0;

            // GSHARE
            gshare_prev_b   <= 0;
        end
        else if (pipe_hold) begin
            // ..
        end
        else if (pipe_flush) begin
            // RAS
            ras_pop_en      <= 0;
            ras_push_en     <= 0;
            // GSHARE
            gshare_prev_b   <= 0;
        end
        else begin
            // RAS
            ras_pop_en      <= ras_can_pop;
            ras_push_en     <= is_ras_push;

            // GSHARE
            gshare_prev_b   <= slot0_is_B;
        end
    end
    
    // 预测结果
    logic slot0_sel_pred_taken;
    logic [31:0] slot0_sel_pred_pc;
    always_comb begin
        unique case (1'b1)
            slot0_ras_can_pop: begin
                slot0_sel_pred_taken = 1'b1;
                slot0_sel_pred_pc    = ras_pop_addr;
            end
            slot0_is_btb_JALR: begin
                slot0_sel_pred_taken = slot0_btb_hit;
                slot0_sel_pred_pc    = slot0_btb_target_pc;
            end
            slot0_is_B: begin
                slot0_sel_pred_taken = gshare_pred_taken;
                slot0_sel_pred_pc    = pc_add_B;
            end
            slot0_is_JAL: begin
                slot0_sel_pred_taken = 1'b1;
                slot0_sel_pred_pc    = pc_add_slot0_JAL;
            end
            default: begin
                slot0_sel_pred_taken = 1'b0;
                slot0_sel_pred_pc    = 32'b0;
            end
        endcase
    end
    logic slot1_sel_pred_taken;
    logic [31:0] slot1_sel_pred_pc;
    always_comb begin
        unique case (1'b1)
            slot1_is_btb_JALR: begin
                slot1_sel_pred_taken = slot1_btb_hit;
                slot1_sel_pred_pc    = slot1_btb_target_pc;
            end
            slot1_ras_can_pop: begin
                slot1_sel_pred_taken = 1'b1;
                slot1_sel_pred_pc    = ras_pop_addr;
            end
            slot1_is_JAL: begin
                slot1_sel_pred_taken = 1'b1;
                slot1_sel_pred_pc    = pc_add_slot1_JAL;
            end
            default: begin
                slot1_sel_pred_taken = 1'b0;
                slot1_sel_pred_pc    = 32'b0;
            end
        endcase
    end

    logic sel_pred_taken;
    logic [31:0] sel_pred_pc;
    assign sel_pred_taken = slot0_sel_pred_taken | slot1_sel_pred_taken;
    assign sel_pred_pc = (slot0_sel_pred_taken) ? slot0_sel_pred_pc : slot1_sel_pred_pc;
    
    always_ff @(posedge clk) begin
        if (!rst) begin
            pred_taken          <= 0;
            pred_pc             <= 0;
            slot0_pred_taken    <= 0;
            slot1_pred_taken    <= 0;
            slot0_pred_pc       <= 0;
            slot1_pred_pc       <= 0;
            ras_snapshot        <= 0;
        end
        else if (pipe_hold) begin   // 当暂停时预测器的结果需要保存
            // ...
        end
        else if (pipe_flush) begin
            pred_taken          <= 0;
            pred_pc             <= 0;
            slot0_pred_taken    <= 0;
            slot1_pred_taken    <= 0;
            slot0_pred_pc       <= 0;
            slot1_pred_pc       <= 0;
            ras_snapshot        <= 0;
        end
        else begin
            pred_taken          <= sel_pred_taken;
            pred_pc             <= sel_pred_pc;
            slot0_pred_taken    <= slot0_sel_pred_taken;
            slot1_pred_taken    <= slot1_sel_pred_taken;
            slot0_pred_pc       <= slot0_sel_pred_pc;
            slot1_pred_pc       <= slot1_sel_pred_pc;
            ras_snapshot        <= ras_ptr;
        end
    end

    // Gshare更新
    assign gshare_update_en         = update_gshare_en;
    assign gshare_update_pht_index  = update_pht_index;
    assign gshare_actual_taken      = actual_taken;
    
    // BTB更新
    assign btb_update_en            = update_btb_en;
    assign btb_update_index         = btb_update_index_w;
    assign btb_update_tag           = btb_update_tag_w;
    assign btb_update_target        = update_target;
endmodule