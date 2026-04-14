`include "rv32I.vh"

module pc(
    input clk,
    input rst_n,
    input jump_en,              // 来自控制单元的跳转使能信号
    input [31:0] jump_addr_i,   // 来自控制单元的跳转地址输入
    input hazard_en,             // 来自控制单元的冒险使能信号

    output reg [31:0] pc_addr_o // 传递给if模块的pc地址输出
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            pc_addr_o <= 32'h8000_0000; // 复位时pc地址初始化为0
        end
        else if(jump_en) begin
            pc_addr_o <= jump_addr_i; // 跳转使能时更新pc地址为输入的跳转地址
        end
        else if(hazard_en) begin
            pc_addr_o <= pc_addr_o; // 冒险使能时保持pc地址不变
        end
        else begin
            pc_addr_o <= pc_addr_o + 4; // 正常情况下pc地址递增4，指向下一条指令
        end
    end
endmodule