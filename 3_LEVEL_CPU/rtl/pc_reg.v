module pc_reg(
    input   wire        clk,
    input   wire        rst,
    input   wire[31:0]  jump_addr_i,
    input   wire        jump_en_i,
    // input   wire        hold_flag_i,
    output  reg[31:0]   pc_addr_o
);

always@(posedge clk) begin
    if (rst == 1'b0)
        pc_addr_o <= 31'b0;
    else if(jump_en_i)
        pc_addr_o <= jump_addr_i;
    else
        pc_addr_o <= pc_addr_o + 3'd4;    // 指令为4字节为一组
end

endmodule