`include "switch.svh"

`ifndef ALU_DEF
`define ALU_DEF

// F 扩展寄存器
`ifdef ENABLE_F
    `define RF_NUM 64
    `define RF_IDX_WIDTH 6
`else
    `define RF_NUM 32
    `define RF_IDX_WIDTH 5
`endif

// 特权级模式
typedef enum {U = 2'b00, S = 2'b01, M = 2'b11} pm_t;

typedef struct packed {
    logic        en;
    logic [31:0] pc;
} flush_t;

typedef struct packed {
    logic [31:0]                    pc;
    logic [31:0]                    inst;
    logic [31:0]                    pc_next;
    flush_t                         pred_flush;
    logic [4:0]                     ras_ptr_snapshot;
    logic [`GSHARE_BHR_WIDTH - 1:0] gshare_ghr_snapshot;
} prefetch_t;

typedef struct packed {
    logic [31:0]                    pc;
    logic [31:0]                    inst;
    logic [31:0]                    imm;
    logic [31:0]                    jump1;
    logic [31:0]                    jump2;
    logic [`RF_IDX_WIDTH - 1:0]     rd_addr;
    logic                           pred_taken;
    logic                           is_ret;
    logic [4:0]                     ras_ptr_snapshot;
    logic [`GSHARE_BHR_WIDTH - 1:0] gshare_ghr_snapshot;
    logic [11:0]                    csr_waddr;
    logic [31:0]                    csr_rdata;
    `ifdef ENABLE_F
    logic [31:0]                    rs3_rdata;
    `endif
} EX_data_t;

typedef struct packed {
    logic [31:0]                    fwd_rs1_data;
    logic [31:0]                    fwd_rs2_data;
    logic                           fwd_rs1_hit_ex;
    logic                           fwd_rs2_hit_ex;
} EX_FWD_data_t;

typedef struct packed {
    // opcode OneShot
    logic is_alu_i;
    logic is_alu_r;
    logic is_auipc;
    logic is_lui;
    logic is_jal;
    logic is_jalr;
    logic is_branch;
    logic is_load;
    logic is_store;
    logic is_zicsr;

    // ================================
    // RV32I
    // ================================
    logic is_rv32i;
    
    // IR-type
    logic sel_add;
    logic sel_sub;
    logic sel_xor;
    logic sel_or;
    logic sel_and;
    logic sel_sll;
    logic sel_srl;
    logic sel_sra;
    logic sel_slt;
    logic sel_sltu;
    
    // Load & Store
    logic sel_lb;
    logic sel_lh;
    logic sel_lw;
    logic sel_lbu;
    logic sel_lhu;
    logic sel_sb;
    logic sel_sh;
    logic sel_sw;
    
    // Branch
    logic sel_beq;
    logic sel_bne;
    logic sel_blt;
    logic sel_bge;
    logic sel_bltu;
    logic sel_bgeu;

    // fence
    logic sel_fence;
    
    // CSR
    logic sel_csrrw;
    logic sel_csrrs;
    logic sel_csrrc;
    logic sel_csrrwi;
    logic sel_csrrsi;
    logic sel_csrrci;
    logic sel_ecall;
    logic sel_mret;
    logic sel_sret;

    // ================================
    // M-ext
    // ================================
    `ifdef ENABLE_M
    logic is_Mext;
    logic sel_mul;
    logic sel_mulh;
    logic sel_mulhsu;
    logic sel_mulhu;
    logic sel_div;
    logic sel_divu;
    logic sel_rem;
    logic sel_remu;
    `endif

    // ================================
    // B-ext
    // ================================
    `ifdef ENABLE_B
    // Zba
    `ifdef ENABLE_B_ZBA
    logic is_Bext_zba;
    logic sel_sh1add;
    logic sel_sh2add;
    logic sel_sh3add;
    `endif

    // Zbb
    `ifdef ENABLE_B_ZBB
    logic is_Bext_zbb;
    logic sel_andn;
    logic sel_orn;
    logic sel_xnor;
    logic sel_clz;
    logic sel_ctz;
    logic sel_cpop;
    logic sel_max;
    logic sel_maxu;
    logic sel_min;
    logic sel_minu;
    logic sel_sext_b;
    logic sel_sext_h;
    logic sel_zext_h;
    logic sel_rol;
    logic sel_ror;
    logic sel_orc_b;
    logic sel_rev8;
    `endif

    // Zbc
    `ifdef ENABLE_B_ZBC
    logic is_Bext_zbc;
    logic sel_clmul;
    logic sel_clmulh;
    logic sel_clmulr;
    `endif

    // Zbs
    `ifdef ENABLE_B_ZBS
    logic is_Bext_zbs;
    logic sel_bclr;
    logic sel_bext;
    logic sel_binv;
    logic sel_bset;
    `endif

    // Zbkb
    `ifdef ENABLE_B_ZBKB
    logic is_Bext_zbkb;
    logic sel_pack;
    logic sel_packh;
    logic sel_brev8;
    logic sel_zip;
    logic sel_unzip;
    `endif

    // Zbkx
    `ifdef ENABLE_B_ZBKX
    logic is_Bext_zbkx;
    logic sel_xperm4;
    logic sel_xperm8;
    `endif
    `endif

    // ================================
    // Zicond-ext
    // ================================
    `ifdef ENABLE_Zicond
    logic is_Zicondext;
    logic sel_czero_eqz;
    logic sel_czero_nez;
    `endif

    // ================================
    // F-ext
    // ================================
    `ifdef ENABLE_F
    logic is_FP;
    logic is_load_FP;
    logic is_store_FP;
    logic sel_fadd_s;
    logic sel_fclass_s;
    logic sel_fcvt_s_w;
    logic sel_fcvt_s_wu;
    logic sel_fcvt_w_s;
    logic sel_fcvt_wu_s;
    logic sel_fdiv_s;
    logic sel_feq_s;
    logic sel_fle_s;
    logic sel_flt_s;
    logic sel_flw;
    logic sel_fmax_s;
    logic sel_fmin_s;
    logic sel_fmul_s;
    logic sel_fmv_w_x;
    logic sel_fmv_x_w;
    logic sel_fsgnj_s;
    logic sel_fsgnjn_s;
    logic sel_fsgnjx_s;
    logic sel_fsqrt_s;
    logic sel_fsub_s;
    logic sel_fsw;
    logic is_FM;
    logic sel_fmadd_s;
    logic sel_fmsub_s;
    logic sel_fnmadd_s;
    logic sel_fnmsub_s;
    `endif

    // ================================
    // A-ext
    // ================================
    `ifdef ENABLE_A
    logic is_Aext;
    logic sel_lr_w;
    logic sel_sc_w;
    logic sel_amoswap_w;
    logic sel_amoadd_w;
    logic sel_amoand_w;
    logic sel_amoor_w;
    logic sel_amoxor_w;
    logic sel_amomax_w;
    logic sel_amomaxu_w;
    logic sel_amomin_w;
    logic sel_amominu_w;
    `endif
    
    logic request_value_only;
} decode_t;
    
    typedef struct packed {
    logic                       req_load;
    logic [1:0]                 load_mask;
    logic [1:0]                 load_addr_low;
    logic                       load_is_signed;
} MEM_data_t;

typedef struct packed {
    logic        req_load;
    logic        req_store;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [3:0]  we;
    logic        write_dram;
} DCACHE_data_t;

typedef struct packed {
    logic [11:0] waddr;
    logic [31:0] wdata;
    logic        wen;
    logic        ecall;
    logic        mret;
    logic        sret;
} CSR_data_t;

typedef struct packed {
    logic                           update_btb_en;
    logic                           update_gshare_en;
    logic [31:0]                    update_pc;
    logic [31:0]                    update_target;
    logic                           actual_taken;
    logic                           rollback_ras_en;
    logic [4:0]                     ras_ptr_snapshot;
    logic [`GSHARE_BHR_WIDTH - 1:0] gshare_ghr_snapshot;
} BPU_data_t;

typedef struct packed {
    logic [`RF_IDX_WIDTH - 1:0] rd_addr;
    logic [31:0]                rd_data;
    logic                       regs_wen;
} RF_data_t;

typedef struct packed {logic ltu, lts;} cmp_result_t;
function automatic cmp_result_t fast_compare(input logic [31:0] a, b);       
    // ltu (a < b unsigned)
    fast_compare.ltu = a < b;
    
    // lts (a < b signed)
    fast_compare.lts = (a[31] ^ b[31]) ? a[31] : fast_compare.ltu;
endfunction

// Fval 解码
typedef enum {
    RNE = 3'b000,   // 向最接近的值舍入, 首选偶数值
    RTZ = 3'b001,   // 向零舍入
    RDN = 3'b010,   // 向下舍入 (向 -> −∞)
    RUP = 3'b011,   // 向上舍入 (向 -> +∞)
    RMM = 3'b100,   // 向最接近的值舍入, 首选最大值 
    DYN = 3'b111    // 在指令字段: 选择动态舍入模式; 在 fcsr: 非法值
} rm_t;

typedef struct packed {
    logic        sign;   // 符号位
    logic [7:0]  exp;   // 指数位
    logic [22:0] mant;   // 尾数位
} fval_t;

typedef struct packed {
    logic NV;   // 非法操作
    logic DZ;   // 除以 0
    logic OF;   // 上溢
    logic UF;   // 下溢
    logic NX;   // 不精确
} fflags_t;

`endif
