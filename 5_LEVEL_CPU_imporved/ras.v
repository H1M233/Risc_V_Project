`include "rv32I.vh"
// 在ID阶段输入出栈压栈信号，返回出栈地址给PC
// jal x1, offset：压栈PC + 4
// jalr x0, x1, 0：出栈

module ras #(
    parameter DEPTH     = 8,
    parameter PTR_WIDTH = $clog2(DEPTH)
)(
    input               clk,
    input               rst,

    // from gshare
    input               push_en,
    input               pop_en,
    input      [31:0]   push_addr_i,

    // to gshare
    output     [31:0]   pop_addr_o,
    output              isempty_o,
    output              isfull_o
);

    reg [31:0] stack_mem [DEPTH - 1:0];
    reg [PTR_WIDTH:0] ptr;

    integer i;
    always@(posedge clk or negedge rst) begin
        if(!rst) begin
            ptr <= 0;
            for(i = 0; i < DEPTH; i = i + 1) stack_mem[i] <= 32'b0;
        end
        else begin
            // 仅压栈
            if(push_en && !pop_en && ptr != DEPTH) begin
                stack_mem[ptr]  <= push_addr_i;
                ptr             <= ptr + 1'b1;
            end

            // 仅出栈
            else if(!push_en && pop_en && ptr != 1'b0) begin
                ptr             <= ptr - 1'b1;
            end

            // 同时压栈出栈：指针不变
            else if(push_en && pop_en) begin 
                stack_mem[ptr - 1]  <= push_addr_i;
            end
        end
    end

    assign isempty_o    = (ptr == 0);
    assign isfull_o     = (ptr == DEPTH);
    assign pop_addr_o   = (pop_en && !isempty_o) ? stack_mem[ptr - 1] : 32'hDEAD_BEEF;

endmodule