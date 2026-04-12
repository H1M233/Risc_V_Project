module regs(
    input   wire        clk,
    input   wire        rst,
    // from id
    input   wire[4:0]   rs1_raddr_i,
    input   wire[4:0]   rs2_raddr_i,

    // to id
    output  reg[31:0]   rs1_rdata_o,
    output  reg[31:0]   rs2_rdata_o,

    // from ex
    input   wire[4:0]   rd_waddr_i,
    input   wire[31:0]  rd_wdata_i,
    input   wire        rd_wen_i
);
    // 设置32个32位寄存器
    reg[31:0] regs[0:31];
    integer i;

    always@(*) begin
        if(rst == 1'b0)
            rs1_rdata_o = 32'b0;
        else if(rs1_raddr_i == 5'b0)
            rs1_rdata_o = 32'b0;
        else if(rd_wen_i && rs1_raddr_i == rd_waddr_i)    // 当后一条指令需要调用前一条指令同寄存器的值时，直接赋值
            rs1_rdata_o = rd_wdata_i;
        else
            rs1_rdata_o = regs[rs1_raddr_i];
    end

    always@(*) begin
        if(rst == 1'b0)
            rs2_rdata_o = 32'b0;
        else if(rs2_raddr_i == 5'b0)
            rs2_rdata_o = 32'b0;
        else if(rd_wen_i && rs2_raddr_i == rd_waddr_i)    // 同上
            rs2_rdata_o = rd_wdata_i;
        else
            rs2_rdata_o = regs[rs2_raddr_i];
    end

    always@(posedge clk) begin
        if(rst == 1'b0) begin
            for(i = 0; i <= 31; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end
        else if(rd_wen_i && rd_waddr_i != 5'b0) begin
            regs[rd_waddr_i] <= rd_wdata_i;
        end
    end
endmodule