`include "rv32I.svh"

// 为返回类 JALR 使用的 RAS 栈
// 就是一个物理栈

module ras #(
    parameter DEPTH = 8,
    parameter PTR_WIDTH = $clog2(DEPTH)
)(
    input               clk,
    input               rst,

    // from bpu
    input               push_en_i,      // 压栈使能
    input               pop_en_i,       // 弹栈使能
    input      [31:0]   push_addr_i,    // 压栈地址
    input               rollback_en_i,
    input      [3:0]    rollback_ptr_i,

    // to bpu
    output     [31:0]   pop_addr_o,     // 弹栈地址
    output              isempty_o,      // 为空
    output              isfull_o,       // 为满
    output     [3:0]    ptr_o
);

    reg [31:0] stack_mem [DEPTH - 1:0];
    reg [PTR_WIDTH:0] ptr;

    // 初始化
    initial begin
        for(int i = 0; i < DEPTH; i++) stack_mem[i] = 32'b0;
    end
    

    assign isempty_o   = (ptr == 0);
    assign isfull_o    = (ptr == DEPTH);
    assign pop_addr_o  = (ptr != 0) ? stack_mem[ptr - 1] : 32'b0;      // 始终输出栈顶
    assign ptr_o       = ptr;

    // 压栈
    always_ff @(posedge clk) begin
        if (push_en_i & ptr != DEPTH) begin
            stack_mem[ptr]  <= push_addr_i;
        end
    end

    // 指针控制
    always_ff @(posedge clk) begin
        if (!rst) begin
            ptr <= 0;
        end
        // else if (rollback_en_i) begin
        //     ptr <= rollback_ptr_i;
        // end
        else begin
            if (push_en_i && ptr != DEPTH) ptr <= ptr + 1'b1;    // 压栈
            if (pop_en_i && ptr != 1'b0)   ptr <= ptr - 1'b1;    // 出栈
        end
    end
endmodule