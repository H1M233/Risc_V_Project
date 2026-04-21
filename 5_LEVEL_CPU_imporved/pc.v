`include "rv32I.vh"

module pc(
    input               clk,
    input               rst,

    // from hazard
    input               hazard_en,      // 来自控制单元的冒险使能信号

    // from jump
    input      [31:0]   jump_addr_i,    // 来自控制单元的跳转地址输入
    input               jump_en,        // 来自控制单元的跳转使能信号

    // to if & IROM
    output reg [31:0]   pc_addr_o,      // 传递给if模块的pc地址输出

    // from Gshare
    input      [31:0]   pred_pc,
    input               pred_taken

);
    always @(posedge clk or negedge rst) begin
        if      (!rst)          pc_addr_o   <= 32'h8000_0000;   // 复位时pc地址初始化为0
        else if (jump_en)       pc_addr_o   <= jump_addr_i;     // 跳转使能时更新pc地址为输入的跳转地址
        else if (hazard_en)     pc_addr_o   <= pc_addr_o;       // 冒险使能时保持pc地址不变
        else if (pred_taken)    pc_addr_o   <= pred_pc;         // 如果预测跳转，则跳转到目标地址
        else                    pc_addr_o   <= pc_addr_o + 4;   // 正常情况下pc地址递增4，指向下一条指令
    end
endmodule