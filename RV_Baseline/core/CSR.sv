`include "rv32I.svh"
`include "alu_def.svh"
`include "csr_def.svh"

module CSR(
    input  logic                    clk                     ,
    input  logic                    rst                     ,

    // from id
    input  logic [11:0]             csr_addr                ,
    output logic [31:0]             csr_rdata               ,

    // from wb
    input  logic [31:0]             wb_pc_i                 ,
    input  CSR_data_t               data_pkg_i              ,

    // from ex
    input  logic                    ex_ecall                ,
    input  logic                    ex_mret                 ,
    input  logic                    ex_sret                 ,

    // from PerfCounter
    input  PerfCounter_t            PerfCounter_pkg_i       ,

    // trap
    output flush_t                  trap_flush_o            

    // // 外部中断
    // input  logic         PLIC,
    // input  logic [31:0]  PLIC_id
);
    // 解码
    wire [11:0] csr_waddr = data_pkg_i.waddr;
    wire [31:0] csr_wdata = data_pkg_i.wdata;
    wire        csr_wen   = data_pkg_i.wen;
    wire        wb_ecall  = data_pkg_i.ecall;
    wire        wb_mret   = data_pkg_i.mret;
    wire        wb_sret   = data_pkg_i.sret;

    // 特权级寄存器
    pm_t current_privilege;

    // 定义CSR寄存器
    mstatus_t    mstatus;       // 机器状态寄存器
    logic [31:0] mepc;          // 机器异常程序计数器
    mcause_t     mcause;        // 机器异常原因寄存器
    mtvec_t      mtvec;         // 机器异常向量基地址寄存器
    logic [31:0] mscratch;      // 机器临时寄存器
    fcsr_t       fcsr;          // F 扩展浮点控制和状态异常寄存器
    mi_t         mie;           // 机器中断开关 (Enable)
    mi_t         mip;           // 机器中断挂起 (Pending)
    logic [31:0] mtval;         // 异常抛出数据
    logic [31:0] misa;          // 机器支持的扩展信息
    logic [31:0] mvendorid;     // 设备制造商 ID
    logic [31:0] marchid;       // 设备架构 ID
    logic [31:0] mimpid;        // 设备版本号
    logic [31:0] mhartid;       // 核心编号
    logic [31:0] dcsr;          // Debug 状态寄存器
    logic [31:0] dpc;           // Debug PC
    logic [31:0] dscratch0;     // Debug 临时寄存器 x0
    logic [31:0] dscratch1;     // Debug 临时寄存器 x1

    logic [31:0] mcountinhibit; // 性能计数器开关
    logic [63:0] mcycle;
    logic [63:0] time_;
    logic [63:0] minstret;
    logic [63:0] mhpmcounter3;
    logic [63:0] mhpmcounter4;
    logic [63:0] mhpmcounter5;

    // 机器信息连线
    assign misa = {
        `MISA_XLEN,         // XLEN - 32=01, 64=10
        8'b0,
        `MISA_EXT_V,        // V - Vector
        `MISA_EXT_U,        // U - User Mode
        1'b0,
        `MISA_EXT_S,        // S - Supervisor Mode
        1'b0,
        `MISA_EXT_Q,        // Q - Quad Precision Float
        3'b0,
        `MISA_EXT_M,        // M - Multiply / Divide
        3'b0,
        1'b1,               // I - Base
        `MISA_EXT_H,        // H - Hypervisor
        `MISA_EXT_G,        // G - Support I, A, M, F, D
        `MISA_EXT_F,        // F - Single Precision Float
        1'b0,
        `MISA_EXT_D,        // D - Double Precision Float
        `MISA_EXT_C,        // C - Compressed
        `MISA_EXT_B,        // B - Bitmanip
        `MISA_EXT_A         // A - Atomic
    };
    
    assign mvendorid = 32'b0;
    assign marchid   = 32'b0;
    assign mimpid    = 32'b0;
    assign mhartid   = 32'b0;

    // CSR 写
    always_ff @(posedge clk) begin
        if (rst) begin
            current_privilege   <= M;
            mstatus             <= 32'b0;
            mepc                <= 32'b0;
            mcause              <= 32'b0;
            mtvec               <= 32'b0;
            mscratch            <= 32'b0;
        end
        else if (wb_ecall) begin
            current_privilege   <= M;
            mepc                <= wb_pc_i;             // 保存引发ecall的指令地址
            mcause.CODE         <= 31'hb;               // 设置异常原因，0xB表示环境调用
            mstatus.MPIE        <= mstatus.MIE;         // 保存当前中断使能
            mstatus.MIE         <= 1'b0;                // 关闭全局中断
            mstatus.MPP         <= current_privilege;   // 保存当前特权级
        end
        else if (wb_mret) begin
            current_privilege   <= mstatus.MPP;     // 恢复特权级
            mstatus.MIE         <= mstatus.MPIE;    // 恢复之前的中断使能
            mstatus.MPIE        <= 1'b1;            // 重置 MPIE
            mstatus.MPP         <= U;
        end
        else if (csr_wen) begin
            case (csr_waddr)
                MSTATUS_ADDR       : mstatus        <= csr_wdata;
                MEPC_ADDR          : mepc           <= csr_wdata;
                MCAUSE_ADDR        : mcause         <= csr_wdata;
                MTVEC_ADDR         : mtvec          <= csr_wdata;
                MSCRATCH_ADDR      : mscratch       <= csr_wdata;

                // FCSR
                FCSR_ADDR          : fcsr           <= csr_wdata[7:0];
                FFLAGS_ADDR        : fcsr.flags     <= csr_wdata[4:0];
                FRM_ADDR           : fcsr.frm       <= rm_t'(csr_wdata[2:0]);

                // PerfCounter
                MCOUNTINHIBIT_ADDR : mcountinhibit  <= csr_wdata;
                default            : ; // 无效地址，保持不变
            endcase
        end 
    end

    // CSR 读
    always_comb begin
        case (csr_addr)
            MSTATUS_ADDR       : csr_rdata = mstatus;
            MEPC_ADDR          : csr_rdata = mepc;
            MCAUSE_ADDR        : csr_rdata = mcause;
            MTVEC_ADDR         : csr_rdata = mtvec;
            MSCRATCH_ADDR      : csr_rdata = mscratch;

            // FCSR
            FCSR_ADDR          : csr_rdata = fcsr;
            FFLAGS_ADDR        : csr_rdata = {26'b0, fcsr.flags};
            FRM_ADDR           : csr_rdata = {29'b0, fcsr.frm};

            // PerfCounter
            MCOUNTINHIBIT_ADDR : csr_rdata = mcountinhibit;
            MCYCLE_ADDR        : csr_rdata = mcycle[31:0];
            MCYCLEH_ADDR       : csr_rdata = mcycle[63:32];
            TIME_ADDR          : csr_rdata = time_[31:0];
            TIMEH_ADDR         : csr_rdata = time_[63:32];
            MINSTRET_ADDR      : csr_rdata = minstret[31:0];
            MINSTRETH_ADDR     : csr_rdata = minstret[63:32];
            ICACHE_MISS_ADDR   : csr_rdata = mhpmcounter3[31:0];
            ICACHE_MISSH_ADDR  : csr_rdata = mhpmcounter3[63:32];
            MISPREDICT_ADDR    : csr_rdata = mhpmcounter4[31:0];
            MISPREDICTH_ADDR   : csr_rdata = mhpmcounter4[63:32];
            DCACHE_MISS_ADDR   : csr_rdata = mhpmcounter5[31:0];
            DCACHE_MISSH_ADDR  : csr_rdata = mhpmcounter5[63:32];
            default            : csr_rdata = 32'b0; // 无效地址，返回0
        endcase
    end
    
    // trap 处理
    assign trap_flush_o.en = ex_ecall | ex_mret;
    always_comb begin
        unique case (1'b1)
            ex_ecall   : trap_flush_o.pc = {mtvec.BASE, 2'b0};     // 跳转到异常处理程序地址
            ex_mret    : trap_flush_o.pc = mepc;                   // 从 mepc 恢复执行地址
            default    : trap_flush_o.pc = 32'b0;
        endcase
    end

    // PerfCounter_if 例化
    `define DECLARE_PERFCOUNTER(NAME, _reg,_event_pulse) \
        PerfCounter PerfCounter_``NAME``_inst( \
            .clk            (clk), \
            .rst            (rst), \
            .enable         (mcountinhibit[MCOUNTINHIBIT_``NAME]), \
            .event_pulse    (_event_pulse), \
            .wenl           (csr_wen && csr_waddr == NAME``_ADDR), \
            .wenh           (csr_wen && csr_waddr == NAME``H_ADDR), \
            .wdata          (csr_wdata), \
            .value          (_reg) \
        );

    `DECLARE_PERFCOUNTER(MCYCLE,        mcycle,         1'b1)
    `DECLARE_PERFCOUNTER(TIME,          time_,          1'b1)
    `DECLARE_PERFCOUNTER(MINSTRET,      minstret,       PerfCounter_pkg_i.minstret)
    `DECLARE_PERFCOUNTER(ICACHE_MISS,   mhpmcounter3,   PerfCounter_pkg_i.icache_miss)
    `DECLARE_PERFCOUNTER(MISPREDICT,    mhpmcounter4,   PerfCounter_pkg_i.mispredict)
    `DECLARE_PERFCOUNTER(DCACHE_MISS,   mhpmcounter5,   PerfCounter_pkg_i.dcache_miss)
endmodule