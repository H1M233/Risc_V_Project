`include "rv32I.vh"
`include "alu.vh"

module csr_regs(
    input clk,
    input rst,
    input [31:0] csr_addr,         //from id value2
    input [31:0] csr_wdata,        //from ex
    input csr_wen,

    output reg [31:0] csr_rdata,
    //ecall
    input ecall,                    //from wb
    input mret,                     //from wb
    input [31:0] ecall_inst,
    output reg [31:0] ecall_mret_addr
);
    // 定义CSR寄存器
    reg [31:0] mstatus;   // 机器状态寄存器
    reg [31:0] mepc;      // 机器异常程序计数器
    reg [31:0] mcause;    // 机器异常原因寄存器
    reg [31:0] mtvec;     // 机器异常向量基地址寄存器

    // CSR地址映射
    localparam MSTATUS_ADDR = 12'h300;
    localparam MEPC_ADDR    = 12'h341;
    localparam MCAUSE_ADDR  = 12'h342;
    localparam MTVEC_ADDR   = 12'h305;

    // CSR写入逻辑
    always @(posedge clk) begin
        if (!rst) begin
            mstatus <= 32'b0;
            mepc <= 32'b0;
            mcause <= 32'b0;
            mtvec <= 32'b0;
            csr_rdata <= 32'b0;
            ecall_mret_addr <= 32'b0;
        end
        else if (ecall) begin
            mepc <= ecall_inst; // 保存引发ecall的指令地址
            mcause <= 32'h0000_000b; // 设置异常原因，0xB表示环境调用
            mstatus[3] <= 1'b0; // 设置mstatus的MIE位为0，禁止中断
            ecall_mret_addr <= mtvec; // 跳转到异常处理程序地址
        end
        else if (mret) begin
            ecall_mret_addr <= mepc; // 从mepc恢复执行地址
            mstatus[3] <= 1'b1; // 设置mstatus的MIE位为1，允许中断
        end
        else if (csr_wen) begin
            case (csr_addr)
                MSTATUS_ADDR: mstatus <= csr_wdata;
                MEPC_ADDR: mepc <= csr_wdata;
                MCAUSE_ADDR: mcause <= csr_wdata;
                MTVEC_ADDR: mtvec <= csr_wdata;
                default: ; // 无效地址，保持不变
            endcase
        end 
    end
    // CSR读数据逻辑
    always @(*) begin
        case (csr_addr)
            MSTATUS_ADDR: csr_rdata = mstatus;
            MEPC_ADDR: csr_rdata = mepc;
            MCAUSE_ADDR: csr_rdata = mcause;
            MTVEC_ADDR: csr_rdata = mtvec;
            default: csr_rdata = 32'b0; // 无效地址，返回0
        endcase
    end

endmodule