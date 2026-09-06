`include "alu_def.svh"

`ifndef CSR_DEF
`define CSR_DEF

// CSR地址映射
localparam MSTATUS_ADDR         = 12'h300;
localparam MEPC_ADDR            = 12'h341;
localparam MCAUSE_ADDR          = 12'h342;
localparam MTVEC_ADDR           = 12'h305;
localparam MSCRATCH_ADDR        = 12'h340;
localparam FCSR_ADDR            = 12'h003;
localparam FFLAGS_ADDR          = 12'h001;
localparam FRM_ADDR             = 12'h002;
localparam MIE_ADDR             = 12'h304;
localparam MIP_ADDR             = 12'h344;
localparam MTVAL_ADDR           = 12'h343;
localparam MISA_ADDR            = 12'h301;
localparam MVENDORID_ADDR       = 12'hf11;
localparam MARCHID_ADDR         = 12'hf12;
localparam MIMPID_ADDR          = 12'hf13;
localparam MHARTID_ADDR         = 12'hf14;
localparam DCSR_ADDR            = 12'h7b0;
localparam DPC_ADDR             = 12'h7b1;
localparam DSCRATCH0_ADDR       = 12'h7b2;
localparam DSCRATCH1_ADDR       = 12'h7b3;

// 性能计数器地址映射
localparam MCOUNTINHIBIT_ADDR   = 12'h320;
localparam MCYCLE_ADDR          = 12'hC00;
localparam MCYCLEH_ADDR         = 12'hC80;
localparam TIME_ADDR            = 12'hC01;
localparam TIMEH_ADDR           = 12'hC81;
localparam MINSTRET_ADDR        = 12'hC02;
localparam MINSTRETH_ADDR       = 12'hC82;
localparam ICACHE_MISS_ADDR     = 12'hC03;
localparam ICACHE_MISSH_ADDR    = 12'hC83;
localparam MISPREDICT_ADDR      = 12'hC04;
localparam MISPREDICTH_ADDR     = 12'hC84;
localparam DCACHE_MISS_ADDR     = 12'hC05;
localparam DCACHE_MISSH_ADDR    = 12'hC85;

// 性能计数器开关位
localparam MCOUNTINHIBIT_MCYCLE       = 0;
localparam MCOUNTINHIBIT_TIME         = 1;
localparam MCOUNTINHIBIT_MINSTRET     = 2;
localparam MCOUNTINHIBIT_ICACHE_MISS  = 3;
localparam MCOUNTINHIBIT_MISPREDICT   = 4;
localparam MCOUNTINHIBIT_DCACHE_MISS  = 5;


// CSR 解码
typedef struct packed { // MSTATUS
    logic       SD;     // is XS | FS | VS Dirty
    logic [7:0] r0;
    logic       TSR;    // When TSR=1 & 'sret' in S-mode May Cause Illegal Instruction Exception
    logic       TW;     // If ex WFI & Timeout With No Interrupt, Cause a Illegal Instruction Trap
    logic       TVM;    // Take Over Mem From S-mode & Modify its Mem Address Translation in M-mode
    logic       MXR;    // Allow S-mode to Access X=1, R=0 (eXecutable=1, Readable=0) Mem
    logic       SUM;    // Allow S-mode to Access Mem Marked U-mode (SUM=0 May Cause Page Fault)
    logic       MPRV;   // Access Mem In MPP-mode When M-mode
    logic [1:0] XS;     // Custom Status
    logic [1:0] FS;     // Float Status - For Tracking is FREG Dirty
    pm_t        MPP;    // Save Prior Privilege Level When Entering M-mode From an Exception / Interrupt Or 0 When 'mret'
    logic [1:0] VS;     // Vector Status (Unused)
    logic       SPP;    // Save Prior Privilege Level When Entering S-mode From an Exception / Interrupt Or 0 When 'sret'
    logic       MPIE;   // Save MIE When Entering M-mode From an Exception / Interrupt Or 1 When 'nret'
    logic       UBE;    // Controls The Endianness of U-mode (0 = little, 1 = big)
    logic       SPIE;   // Save SIE When Entering S-mode From an Exception / Interrupt Or 1 When 'sret'
    logic       r1;
    logic       MIE;    // M-mode Interrupt Enable
    logic       r2;
    logic       SIE;    // S-mode Interrupt Enable
    logic       r3;
} mstatus_t;

typedef struct packed { // MCAUSE
    logic        INT;
    logic [30:0] CODE;
} mcause_t;

typedef struct packed { // MTVEC
    logic [29:0] BASE;
    logic [1:0]  MODE;
} mtvec_t;


typedef struct packed { // FCSR
    logic [23:0] r0;
    rm_t         frm; // 舍入模式
    fflags_t     flags;
} fcsr_t;

typedef struct packed { // MIE & MIP
    logic [17:0] r0;
    logic        LCOFIE;    // Local Counter Overflow
    logic        SGEIE;     // Supervisor Guest External
    logic        MEIE;      // Machine External
    logic        VSEIE;     // Virtual Supervisor External
    logic        SEIE;      // Supervisor External
    logic        r1;
    logic        MTIE;      // Machine Timer
    logic        VSTIE;     // Virtual Supervisor Timer
    logic        STIE;      // Supervisor Timer
    logic        r2;
    logic        MSIE;      // Machine Software
    logic        VSSIE;     // Virtual Supervisor Software
    logic        SSIE;      // Supervisor Software
    logic        r3;
} mi_t;

// MISA 机器信息解码
`define MISA_XLEN 2'b01             // XLEN - 32=01, 64=10
`define MISA_EXT_V 1'b0             // V - Vector
`define MISA_EXT_U 1'b0             // U - User Mode
`define MISA_EXT_S 1'b0             // S - Supervisor Mode
`define MISA_EXT_Q 1'b0             // Q - Quad Precision Float
`ifdef ENABLE_M                     // M - Multiply / Divide
    `define MISA_EXT_M 1'b1
`else
    `define MISA_EXT_M 1'b0
`endif
`define MISA_EXT_H 1'b0             // H - Hypervisor
`define MISA_EXT_G 1'b0             // G - Support I, A, M, F, D
`ifdef ENABLE_F                     // F - Single Precision Float
    `define MISA_EXT_F 1'b1
`else
    `define MISA_EXT_F 1'b0
`endif
`define MISA_EXT_D 1'b0             // D - Double Precision Float
`define MISA_EXT_C 1'b0             // C - Compressed
`ifdef ENABLE_B                     // B - Bitmanip
    `define MISA_EXT_B 1'b1
`else
    `define MISA_EXT_B 1'b0
`endif
`ifdef ENABLE_A                     // A - Atomic
    `define MISA_EXT_A 1'b1
`else
    `define MISA_EXT_A 1'b0
`endif

`endif