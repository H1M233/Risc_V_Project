`include "rv32I.vh"
// Gshare分支预测实现
// 当if阶段读到跳转类指令时激活，if输入当前指令，并向pc返回预测跳转的结果，在下一个时钟执行
// 跳转指令经过两个时钟周期传输到ex时，根据计算结果，向预测模块返回实际跳转结果
// 若正确，在模块内更新权重
// 若错误，在ex冲刷流水线并执行正确结果，在模块内更新权重

module gshare #(
    parameter BHR_WIDTH = 10,
    parameter PHT_SIZE  = 1024
) (
    input                           clk,
    input                           rst,
    
    // 查询
    input      [BHR_WIDTH - 1:0]    pht_index_i,
    input                           prev_b,
    output                          pred_taken_o,
    output     [BHR_WIDTH - 1:0]    gshare_ghr_o,
    output     [BHR_WIDTH - 1:0]    gshare_ghr_d2_o,

    // 更新
    input                           update_en_i,          // ex阶段返回的PHT更新使能
    input      [BHR_WIDTH - 1:0]    update_pht_index_i,          // ex阶段返回更新的指令地址
    input                           actual_taken_i,       // ex阶段判断跳转为真
    input                           pred_mispredict_i     // ex阶段判断预测错误
);
    reg     [BHR_WIDTH - 1:0]   ghr;                    // GHR全局历史寄存器：用于投机更新
    reg     [BHR_WIDTH - 1:0]   ghr_d1;                 // ID阶段时的GHR
    reg     [BHR_WIDTH - 1:0]   ghr_d2;                 // EX阶段时的GHR
    reg     [1:0]               pht[0:PHT_SIZE - 1];    // PHT2位饱和计数器

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