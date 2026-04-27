`include "rv32I.vh"

// Gshare模块：
// 输入提前算好的 pht_index 返回最高位结果
// 并输出 ghr 和 ghr_d2 以用于在控制器内提前运算
// 若收到更新使能信号 update_en 则将提前算好的 update_pht_index 内容权重加减1 并恢复 ghr 状态
// 若收到上一个指令为 B 类型的信号 prev_b 则移动 ghr -> ghr_d1 -> ghr_d2

module gshare #(
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024
) (
    input                           clk,
    input                           rst,
    
    // 查询
    input      [BHR_WIDTH - 1:0]    pht_index_i,            // 控制模块提前算好的预测索引
    input                           prev_b,                 // 控制模块返回上一个指令是否为 B 类型
    output                          pred_taken_o,           // 输出预测是否跳转
    output     [BHR_WIDTH - 1:0]    gshare_ghr_o,           // 输出 ghr 到控制模块以提前计算预测索引
    output     [BHR_WIDTH - 1:0]    gshare_ghr_d2_o,        // 输出 ghr_d2 到控制模块以提前计算更新索引

    // 更新
    input                           update_en_i,            // ex 阶段返回的 PHT 更新使能
    input      [BHR_WIDTH - 1:0]    update_pht_index_i,     // ex 阶段返回并在控制模块提前算好的更新的索引
    input                           actual_taken_i,         // ex 阶段判断跳转为真
    input                           pred_mispredict_i       // ex 阶段判断预测错误
);
    reg     [BHR_WIDTH - 1:0]   ghr;                        // GHR全局历史寄存器：用于投机更新
    reg     [BHR_WIDTH - 1:0]   ghr_d1;                     // ID阶段时的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d2;                     // EX阶段时的GHR
    reg     [1:0]               pht[0:PHT_SIZE - 1];        // PHT2位饱和计数器

    // 查询
    assign gshare_ghr_o     = ghr;
    assign gshare_ghr_d2_o  = ghr_d2;
    assign pred_taken_o     = pht[pht_index_i][1];

    // 更新
    integer i;
    always@(posedge clk) begin
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
            if(update_en_i) begin
                // PHT
                case(pht[update_pht_index_i])
                    2'b00:      pht[update_pht_index_i] <= (actual_taken_i) ? 2'b01 : 2'b00;
                    2'b01:      pht[update_pht_index_i] <= (actual_taken_i) ? 2'b10 : 2'b00;
                    2'b10:      pht[update_pht_index_i] <= (actual_taken_i) ? 2'b11 : 2'b01;
                    2'b11:      pht[update_pht_index_i] <= (actual_taken_i) ? 2'b11 : 2'b10;
                    default:    pht[update_pht_index_i] <= 2'b00;
                endcase
            end

            // GHR
            if      (update_en_i && pred_mispredict_i)  ghr <= {ghr_d2[BHR_WIDTH - 2:0], actual_taken_i};     // 预测错误回退GHR
            else if (prev_b)                            ghr <= {ghr[BHR_WIDTH - 2:0], pred_taken_o};          // 预测投机更新GHR
            // 其他情况不更新GHR
        end
    end
endmodule