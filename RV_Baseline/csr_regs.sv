`include "rv32I.vh"
`include "alu_def.svh"
`include "csr_def.svh"

module csr_regs(
    input  logic clk,
    input  logic rst,

    // from id
    input  logic [11:0]  csr_addr,
    output logic [31:0]  csr_rdata,

    // from wb
    input  ex_csr_data_t data_packaged_i,
    
    // trap
    input  logic         ecall,          // from wb
    input  logic         mret,           // from wb
    input  logic [31:0]  ecall_inst,     // from wb
    output logic         trap_en,
    output logic [31:0]  trap_pc
);
    // 解码
    wire [11:0] csr_waddr = data_packaged_i.waddr;
    wire [31:0] csr_wdata = data_packaged_i.wdata;
    wire        csr_wen   = data_packaged_i.wen;

    // 特权级寄存器
    pm_t current_privilege;

    // 定义CSR寄存器
    mstatus_t   mstatus;     // 机器状态寄存器
    mepc_t      mepc;        // 机器异常程序计数器
    mcause_t    mcause;      // 机器异常原因寄存器
    mtvec_t     mtvec;       // 机器异常向量基地址寄存器
    mscratch_t  mscratch;    // 机器临时寄存器
    fcsr_t      fcsr;        // F 扩展浮点控制和状态异常寄存器

    // CSR地址映射
    localparam MSTATUS_ADDR  = 12'h300;
    localparam MEPC_ADDR     = 12'h341;
    localparam MCAUSE_ADDR   = 12'h342;
    localparam MTVEC_ADDR    = 12'h305;
    localparam MSCRATCH_ADDR = 12'h340;
    localparam FCSR_ADDR     = 12'h003;
    localparam FFLAGS_ADDR   = 32'h001;
    localparam FRM_ADDR      = 32'h002;

    // CSR 写
    always_ff @(posedge clk) begin
        if (!rst) begin
            current_privilege   <= M;
            mstatus             <= 32'b0;
            mepc                <= 32'b0;
            mcause              <= 32'b0;
            mtvec               <= 32'b0;
            mscratch            <= 32'b0;
        end
        else if (ecall) begin
            current_privilege   <= M;
            mepc.PC             <= ecall_inst;          // 保存引发ecall的指令地址
            mcause.CODE         <= 31'hb;               // 设置异常原因，0xB表示环境调用
            mstatus.MPIE        <= mstatus.MIE;         // 保存当前中断使能
            mstatus.MIE         <= 1'b0;                // 关闭全局中断
            mstatus.MPP         <= current_privilege;   // 保存当前特权级
        end
        else if (mret) begin
            current_privilege   <= mstatus.MPP;     // 恢复特权级
            mstatus.MIE         <= mstatus.MPIE;    // 恢复之前的中断使能
            mstatus.MPIE        <= 1'b1;            // 重置 MPIE
            mstatus.MPP         <= U;
        end
        else if (csr_wen) begin
            case (csr_waddr)
                MSTATUS_ADDR  : mstatus  <= csr_wdata;
                MEPC_ADDR     : mepc     <= csr_wdata;
                MCAUSE_ADDR   : mcause   <= csr_wdata;
                MTVEC_ADDR    : mtvec    <= csr_wdata;
                MSCRATCH_ADDR : mscratch <= csr_wdata;

                FCSR_ADDR     : fcsr       <= csr_wdata[7:0];
                FFLAGS_ADDR   : fcsr.flags <= csr_wdata[4:0];
                FRM_ADDR      : fcsr.frm   <= rm_t'(csr_wdata[2:0]);
                default       : ; // 无效地址，保持不变
            endcase
        end 
    end

    // CSR 读
    always_comb begin
        case (csr_addr)
            MSTATUS_ADDR  : csr_rdata = mstatus;
            MEPC_ADDR     : csr_rdata = mepc;
            MCAUSE_ADDR   : csr_rdata = mcause;
            MTVEC_ADDR    : csr_rdata = mtvec;
            MSCRATCH_ADDR : csr_rdata = mscratch;

            FCSR_ADDR     : csr_rdata = fcsr;
            FFLAGS_ADDR   : csr_rdata = {26'b0, fcsr.flags};
            FRM_ADDR      : csr_rdata = {29'b0, fcsr.frm};
            default       : csr_rdata = 32'b0; // 无效地址，返回0
        endcase
    end
    
    // trap 处理
    assign trap_en = ecall | mret;
    always_comb begin
        unique case (1'b1)
            ecall   : trap_pc = {mtvec.BASE, 2'b0};     // 跳转到异常处理程序地址
            mret    : trap_pc = mepc.PC;                // 从mepc恢复执行地址
            default : trap_pc = 32'b0;
        endcase
    end
endmodule