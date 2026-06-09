`include "rv32I.vh"

// 为返回类 JALR 使用的 RAS 栈
// 就是一个物理栈

module ras #(
    parameter DEPTH = 8,
    parameter PTR_WIDTH = $clog2(DEPTH)
)(
    input  logic        clk,
    input  logic        rst,

    // from bpu
    input  logic        push_en_i,      // 压栈使能
    input  logic        pop_en_i,       // 弹栈使能
    input  logic [31:0] push_addr_i,    // 压栈地址
    input  logic        update_ptr_en,
    input  logic [3:0]  update_ptr,

    // to bpu
    output logic [31:0] pop_addr_o,     // 弹栈地址
    output logic        isempty_o,      // 为空
    output logic        isfull_o,       // 为满
    output logic [3:0]  ras_ptr         // RAS 指针
);

    reg [31:0] stack_mem [DEPTH - 1:0];
    reg [PTR_WIDTH:0] ptr;

    assign ras_ptr     = ptr;
    assign isempty_o   = (ptr == 0);
    assign isfull_o    = (ptr == DEPTH);
    assign pop_addr_o  = (ptr != 0) ? stack_mem[ptr - 1] : 32'b0;      // 始终输出栈顶

    integer i;
    initial begin
        for(i = 0; i < DEPTH; i = i + 1) stack_mem[i] = 32'b0;
    end

    // 压栈
    always_ff @(posedge clk) begin
        if (rst & push_en_i & ptr != DEPTH) begin
            stack_mem[ptr]  <= push_addr_i;
        end
    end

    // 指针控制
    always_ff @(posedge clk) begin
        if (!rst) begin
            ptr <= 0;
        end
        else if (update_ptr_en) begin
            ptr <= update_ptr_en;
        end
        else begin
            if (push_en_i && ptr != DEPTH) ptr <= ptr + 1'b1;    // 压栈
            if (pop_en_i && ptr != 1'b0)   ptr <= ptr - 1'b1;    // 出栈
        end
    end
endmodule