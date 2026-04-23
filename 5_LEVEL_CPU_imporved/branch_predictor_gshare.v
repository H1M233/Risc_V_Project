`include "rv32I.vh"
// Gshare分支预测实现
// 当if阶段读到跳转类指令时激活，if输入当前指令，并向pc返回预测跳转的结果，在下一个时钟执行
// 跳转指令经过两个时钟周期传输到ex时，根据计算结果，向预测模块返回实际跳转结果
// 若正确，在模块内更新权重
// 若错误，在ex冲刷流水线并执行正确结果，在模块内更新权重

module branch_predictor_gshare #(
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024
) (
    input               clk,
    input               rst,
    
    // from pc
    input      [31:0]   pc_addr,            // if阶段指令地址
    input      [31:0]   pc_inst,            // pc取得的指令

    // to pc & if
    output reg [31:0]   pred_pc,            // 向if输出预测的地址
    output reg          pred_taken,         // 从PHT中读取的计数器高位值

    // from ex
    input               update_en,          // ex阶段返回的PHT更新使能
    input      [31:0]   update_pc,          // ex阶段返回更新的指令地址
    input               actual_taken,       // ex阶段判断跳转为真
    input               pred_mispredict,    // ex阶段判断预测错误

    // from ras
    input               ras_isempty,
    input               ras_isfull,
    input      [31:0]   ras_pop_addr,

    // to ras
    output reg          ras_pop_en,
    output reg          ras_push_en,
    output reg [31:0]   ras_push_addr,

    // to btb
    output reg [31:0]   btb_query_pc,

    // from btb
    input               btb_hit,
    input      [31:0]   btb_target_pc
);

    reg     [BHR_WIDTH - 1:0]   ghr;                    // GHR全局历史寄存器：用于投机更新
    reg     [BHR_WIDTH - 1:0]   ghr_d1;                 // ID阶段时的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d2;                 // EX阶段时的GHR

    reg     [1:0]               pht[0:PHT_SIZE - 1];    // PHT2位饱和计数器

    // 预测逻辑：取PC中间位与BHR异或得到索引
    wire    [BHR_WIDTH - 1:0]   pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ ghr;
    wire    [BHR_WIDTH - 1:0]   update_pht_index    = update_pc[BHR_WIDTH + 1:2] ^ ghr_d2;

    // 取指得出rd和rs1的地址
    wire    [4:0]   rd_addr     = pc_inst[11:7];
    wire    [4:0]   rs1_addr    = pc_inst[19:15];

    // 处理JALR
    wire            is_JALR     = (pc_inst[6:0] == `JALR);
    wire    [31:0]  JALR_imm    = {{20{pc_inst[31]}}, pc_inst[31:20]};
    wire            is_ret_JALR = (is_JALR && rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm == 0);

    // 处理JAL
    wire            is_JAL      = (pc_inst[6:0] == `JAL);
    wire    [31:0]  JAL_imm     = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};
    wire            is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);

    // 处理TYPE_B
    wire            is_b_type   = (pc_inst[6:0] == `TYPE_B);
    wire    [31:0]  b_imm       = {{20{pc_inst[31]}}, pc_inst[7], pc_inst[30:25], pc_inst[11:8], 1'b0};

    // 计算预测地址并输出
    always@(*) begin
        ras_pop_en      = 1'b0;
        ras_push_en     = 1'b0;
        ras_push_addr   = 32'b0;
        btb_query_pc    = 32'b0;
        case(pc_inst[6:0])
            `JALR: begin    // 当为ret时直接弹栈直接当预测地址，否则使用BTB
                if(is_ret_JALR && !ras_isempty) begin   // 为ret且栈非空
                    ras_pop_en      = 1'b1;
                    pred_taken      = 1'b1;
                    pred_pc         = ras_pop_addr;
                end
                else if(is_ret_JALR && ras_isempty) begin   // 貌似不会发生，但是写一下
                    pred_taken      = 1'b0;
                    pred_pc         = 32'b0;
                end
                else begin                              // 非ret：使用btb预测
                    btb_query_pc    = pc_addr;
                    pred_taken      = btb_hit;
                    pred_pc         = (btb_hit) ? btb_target_pc : 32'b0;
                end
            end
            `JAL: begin     // 无需预测直接跳转并压栈
                ras_push_en     = (is_ret_JAL && !ras_isfull);
                ras_push_addr   = (is_ret_JAL && !ras_isfull) ? pc_addr + 32'h4 : 32'b0;
                pred_taken      = 1'b1;
                pred_pc         = pc_addr + JAL_imm;
            end
            `TYPE_B: begin  // 根据PHT预测跳转
                pred_taken      = pht[pht_index][1];     // 返回计数器中的高位（即为1则预测跳转）
                pred_pc         = (pred_taken && is_b_type) ? pc_addr + b_imm: pc_addr + 32'h4;     
            end
            default: begin
                pred_taken      = 1'b0;
                pred_pc         = 32'b0;
            end
        endcase
    end

    // PHT和BHR更新
    integer i;
    always@(posedge clk or negedge rst) begin
        if(!rst) begin
            // 复位
            ghr     <= 0;
            ghr_d1  <= 0;
            ghr_d2  <= 0;
            for(i = 0; i < PHT_SIZE; i = i + 1) pht[i] <= 2'b01;
        end
        else begin
            // 流水线延迟
            ghr_d1  <= ghr;
            ghr_d2  <= ghr_d1;
            
            // 更新
            if(update_en) begin
                // PHT
                case(pht[update_pht_index])
                    2'b00:      pht[update_pht_index] <= (actual_taken) ? 2'b01 : 2'b00;
                    2'b01:      pht[update_pht_index] <= (actual_taken) ? 2'b10 : 2'b00;
                    2'b10:      pht[update_pht_index] <= (actual_taken) ? 2'b11 : 2'b01;
                    2'b11:      pht[update_pht_index] <= (actual_taken) ? 2'b11 : 2'b10;
                    default:    pht[update_pht_index] <= 2'b00;
                endcase
            end

            // GHR
            if      (update_en && pred_mispredict)  ghr <= {ghr_d2[BHR_WIDTH - 2:0], actual_taken};     // 预测错误回退GHR
            else if (is_b_type)                     ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken};          // 预测投机更新GHR
            // 其他情况不更新GHR
        end
    end
endmodule