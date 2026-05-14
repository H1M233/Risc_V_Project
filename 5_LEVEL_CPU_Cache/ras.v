`include "rv32I.vh"

// 为返回类 JALR 使用的 RAS 栈
// 就是一个物理栈

module ras #(
    parameter DEPTH     = 8,
    parameter PTR_WIDTH = $clog2(DEPTH)
)(
    input               clk,
    input               rst,

    // from gshare
    input               push_en_i,      // 压栈使能
    input               pop_en_i,       // 弹栈使能
    input      [31:0]   push_addr_i,    // 压栈地址

    // to gshare
    output     [31:0]   pop_addr_o,     // 弹栈地址
    output              isempty_o,      // 为空
    output              isfull_o        // 为满
);

    reg [31:0] stack_mem [DEPTH - 1:0];
    reg [PTR_WIDTH:0] ptr;

    assign isempty_o    = (ptr == 0);
    assign isfull_o     = (ptr == DEPTH);
    assign pop_addr_o   = (ptr != 0) ? stack_mem[ptr - 1] : 32'b0;      // 始终输出栈顶

    integer i;
    initial begin
        for(i = 0; i < DEPTH; i = i + 1) stack_mem[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (rst & push_en_i & ptr != DEPTH) begin
            stack_mem[ptr]  <= push_addr_i;
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            ptr <= 0;
        end
        else begin
            // 压栈
            if(push_en_i && ptr != DEPTH) begin
                ptr <= ptr + 1'b1;
            end

            // 出栈
            if(pop_en_i && ptr != 1'b0) begin
                ptr <= ptr - 1'b1;
            end
        end
    end
endmodule