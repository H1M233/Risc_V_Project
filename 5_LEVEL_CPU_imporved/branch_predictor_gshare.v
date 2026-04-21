`include "rv32I.vh"
// Gshare分支预测实现
// 当if阶段读到跳转类指令时激活，pc输入当前指令，并向pc返回预测跳转的结果，在下一个时钟执行
// 跳转指令经过两个时钟周期传输到ex时，根据计算结果，向预测模块返回实际跳转结果
// 若正确，在模块内增加权重
// 若错误，在ex执行正确结果，在模块内减少权重

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
    input      [31:0]   actual_target_pc,   // ex阶段判断跳转目标地址
    input               pred_mispredict
);

    reg     [BHR_WIDTH - 1:0]   bhr;                    // BHR分支历史寄存器：存储历史中跳转状态
    reg     [1:0]               pht[0:PHT_SIZE - 1];    // PHT2位饱和计数器

    // 延迟BHR以匹配流水线深度
    reg     [BHR_WIDTH - 1:0]   bhr_d1;  // ID 阶段
    reg     [BHR_WIDTH - 1:0]   bhr_d2;  // EX 阶段

    // 添加GHR（全局历史寄存器）用于投机更新
    reg     [BHR_WIDTH - 1:0]   ghr;  // 投机更新的历史寄存器

    // 预测逻辑：取PC中间位与BHR异或得到索引
    wire    [BHR_WIDTH - 1:0]   pht_index           = pc_addr[BHR_WIDTH + 1:2] ^ ghr;
    wire    [BHR_WIDTH - 1:0]   update_pht_index    = update_pc[BHR_WIDTH + 1:2] ^ bhr_d2;

    // 处理JAL
    wire            is_JAL = (pc_inst[6:0] == `JAL);
    wire    [31:0]  JAL_imm = {{12{pc_inst[31]}}, pc_inst[19:12], pc_inst[20], pc_inst[30:21], 1'b0};

    // 处理TYPE_B
    wire            is_b_type = (pc_inst[6:0] == `TYPE_B);
    wire    [31:0]  b_imm = {{20{pc_inst[31]}}, pc_inst[7], pc_inst[30:25], pc_inst[11:8], 1'b0};

    always@(*) begin
        case(pc_inst[6:0])
            `JAL: begin
                pred_taken = 1'b1;
                pred_pc = pc_addr + JAL_imm;
            end
            `TYPE_B: begin
                pred_taken = pht[pht_index][1];     // 返回计数器中的高位（即为1则预测跳转）
                pred_pc = (pred_taken && is_b_type) ? pc_addr + b_imm: pc_addr + 32'h4;      
            end
            default: begin
                pred_taken = 1'b0;
                pred_pc = 32'b0;
            end
        endcase
    end

    integer i;
    always@(posedge clk or negedge rst) begin
        if(!rst) begin
            bhr     <= 0;
            ghr     <= 0;
            bhr_d1  <= 0;
            bhr_d2  <= 0;
            for(i = 0; i < PHT_SIZE; i = i + 1) begin
                pht[i] <= 2'b01;
            end
        end
        else begin
            bhr_d1  <= ghr;
            bhr_d2  <= bhr_d1;

            if(update_en) begin
                // 更新PHT
                case(pht[update_pht_index])
                    2'b00:      pht[update_pht_index] <= actual_taken ? 2'b01 : 2'b00;
                    2'b01:      pht[update_pht_index] <= actual_taken ? 2'b10 : 2'b00;
                    2'b10:      pht[update_pht_index] <= actual_taken ? 2'b11 : 2'b01;
                    2'b11:      pht[update_pht_index] <= actual_taken ? 2'b11 : 2'b10;
                    default:    pht[update_pht_index] <= 2'b00;
                endcase

                // 更新BHR
                bhr <= {bhr[BHR_WIDTH - 2:0], actual_taken};

                // 处理GHR
                if(pred_mispredict) begin
                    ghr <= {bhr_d2[BHR_WIDTH - 2:0], actual_taken};
                end
            end
            else if (is_b_type) begin
                ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken};
            end
        end
    end
endmodule