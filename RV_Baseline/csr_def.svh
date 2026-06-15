`include "alu_def.svh"
// CSR 解码
typedef struct packed { // MSTATU
        logic       SD;
        logic [7:0] r0;
        logic       TSR;
        logic       TW;
        logic       TVM;
        logic       MXR;
        logic       SUM;
        logic       MPRV;
        logic [1:0] XS;
        logic [1:0] FS;
        pm_t        MPP;
        logic [1:0] VS;
        logic       SPP;
        logic       MPIE;
        logic       UBE;
        logic       SPIE;
        logic       r1;
        logic       MIE;
        logic       r2;
        logic       SIE;
        logic       r3;
    } mstatus_t;

typedef struct packed { // MEPC
    logic [31:0] PC;
} mepc_t;

typedef struct packed { // MCAUSE
    logic        INT;
    logic [30:0] CODE;
} mcause_t;

typedef struct packed { // MTVEC
    logic [29:0] BASE;
    logic [1:0]  MODE;
} mtvec_t;

typedef struct packed { // MSCRATCH
    logic [31:0] SCRATCH;
} mscratch_t;

typedef struct packed { // FCSR
    logic [23:0] r0;
    rm_t         frm; // 舍入模式
    fflags_t     flags;
} fcsr_t;