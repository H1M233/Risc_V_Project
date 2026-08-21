`include "rv32I.svh"

module ras #(
    parameter DEPTH = 16
)(
    input  logic            clk,
    input  logic            rst,

    // from bpu
    input  logic            push_en_i,      // 压栈使能
    input  logic            pop_en_i,       // 弹栈使能
    input  logic [31:0]     push_pc_i,      // 压栈地址
    input  logic            rollback_en_i,
    input  logic [4:0]      rollback_ptr_i,

    // to bpu
    output logic [31:0]     pop_pc_o,       // 弹栈地址
    output logic            isempty_o,      // 为空
    output logic            isfull_o,       // 为满
    output logic [4:0]      ptr_o
);
    logic [31:0] stack_mem [DEPTH - 1:0];
    logic [4:0]  ptr;

    // 初始化
    initial begin
        for (int i = 0; i < DEPTH; i++)
            stack_mem[i] = 32'b0;
    end

    wire able_to_push = push_en_i && ptr != DEPTH;
    wire able_to_pop  = pop_en_i && ptr;

    always_comb begin
        isempty_o    = (ptr == 0);
        isfull_o     = (ptr == DEPTH);
        ptr_o        = ptr;
        pop_pc_o     = (ptr) ? stack_mem[ptr - 1] : stack_mem[0];      // 始终输出栈顶
    end

    // 压栈
    always_ff @(posedge clk) begin
        if (able_to_push)
            stack_mem[ptr] <= push_pc_i;
    end

    // 指针控制
    always_ff @(posedge clk) begin
        if (rst)
            ptr <= 0;
        else if (rollback_en_i)
            ptr <= rollback_ptr_i;
        else
            ptr <= ptr + able_to_push - able_to_pop;;
    end
endmodule