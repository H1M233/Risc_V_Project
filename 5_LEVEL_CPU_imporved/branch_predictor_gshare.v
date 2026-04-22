`include "rv32I.vh"
// Gshare分支预测实现
// 当if阶段读到跳转类指令时激活，if输入当前指令，并向pc返回预测跳转的结果，在下一个时钟执行
// 跳转指令经过两个时钟周期传输到ex时，根据计算结果，向预测模块返回实际跳转结果
// 若正确，在模块内更新权重
// 若错误，在ex执行正确结果，在模块内更新权重

module branch_predictor_gshare #(
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024
) (
    input               clk,
    input               rst,
    
    // from pc
    input      [31:0]   pc_addr,            // if阶段指令地址
    input      [31:0]   pc_inst,            // pc取得的指令

    // to pc & ex
    output reg [31:0]   pred_pc,            // 向if输出预测的地址
    output reg          pred_taken,         // 从PHT中读取的计数器高位值

    // from ex
    input               update_en,          // PHT计数器的更新使能
    input      [31:0]   update_pc,          // ex阶段返回更新的指令地址
    input               actual_taken,       // ex阶段判断跳转为真
    input               pred_mispredict,

    // from ras
    input               ras_isempty,
    input               ras_isfull,
    input      [31:0]   ras_pop_addr,

    // to ras
    output              ras_pop_en,
    output              ras_push_en,
    output     [31:0]   ras_push_addr
);

    reg     [BHR_WIDTH - 1:0]   bhr;                    // BHR分支历史寄存器：存储历史中跳转状态
    reg     [BHR_WIDTH - 1:0]   ghr;                    // GHR全局历史寄存器：用于投机更新

    // 延迟BHR以匹配流水线深度
    reg     [BHR_WIDTH - 1:0]   bhr_d1;                 // ID 阶段
    reg     [BHR_WIDTH - 1:0]   bhr_d2;                 // EX 阶段

    reg     [1:0]               pht[0:PHT_SIZE - 1];    // PHT2位饱和计数器

    // 预测逻辑：取PC中间位与BHR异或得到索引
    wire    [BHR_WIDTH - 1:0]   pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ ghr;
    wire    [BHR_WIDTH - 1:0]   update_pht_index    = update_pc[BHR_WIDTH + 1:2] ^ bhr_d2;

    wire    [31:0]  pc_add_4    = pc_addr + 32'h4;

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
        ras_pop_en  = 1'b0;
        ras_push_en = 1'b0;
        case(pc_inst[6:0])
            `JALR: begin
                ras_pop_en      = (is_ret_JALR && !ras_isempty);
                pred_taken      = (is_ret_JALR && !ras_isempty);
                pred_pc         = (is_ret_JALR && !ras_isempty) ? ras_pop_addr : 32'b0;
            end
            `JAL: begin
                ras_push_en     = (is_ret_JAL && !ras_isfull);
                ras_push_addr   = (is_ret_JAL && !ras_isfull) ? pc_add_4 : 32'b0;
                pred_taken      = 1'b1;
                pred_pc         = pc_addr + JAL_imm;
            end
            `TYPE_B: begin
                pred_taken      = pht[pht_index][1];     // 返回计数器中的高位（即为1则预测跳转）
                pred_pc         = (pred_taken && is_b_type) ? pc_addr + b_imm: pc_add_4;     
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
            bhr     <= 0;
            ghr     <= 0;
            bhr_d1  <= 0;
            bhr_d2  <= 0;
            for(i = 0; i < PHT_SIZE; i = i + 1) pht[i] <= 2'b01;
        end
        else begin
            // 流水线延迟
            bhr_d1  <= ghr;
            bhr_d2  <= bhr_d1;
            
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

                // BHR
                bhr <= {bhr[BHR_WIDTH - 2:0], actual_taken};
            end

            // GHR
            if      (update_en && pred_mispredict)      ghr <= {bhr_d2[BHR_WIDTH - 2:0], actual_taken};     // 预测错误回退GHR
            else if (is_b_type || is_JAL || is_JALR)    ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken};          // 预测投机更新GHR
            // 其他情况不更新GHR
        end
    end
endmodule