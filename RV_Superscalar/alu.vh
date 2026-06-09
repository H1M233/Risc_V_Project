`ifndef ALU_DEF
`define ALU_DEF

`define OP_INST_NUM     43

// opcode
`define OP_I            0
`define OP_R            1
`define OP_AUIPC        2
`define OP_LUI          3
`define OP_JAL          4
`define OP_JALR         5
`define OP_BRANCH       6
`define OP_LOAD         7
`define OP_STORE        8
`define OP_ZICSR        9

// IR-type
`define INST_IR_ADD     10
`define INST_R_SUB      11
`define INST_IR_XOR     12
`define INST_IR_OR      13
`define INST_IR_AND     14
`define INST_IR_SLL     15
`define INST_IR_SRL     16
`define INST_IR_SRA     17
`define INST_IR_SLT     18
`define INST_IR_SLTU    19

// Load & Store
`define INST_LB         20
`define INST_LH         21
`define INST_LW         22
`define INST_LBU        23
`define INST_LHU        24
`define INST_SB         25
`define INST_SH         26
`define INST_SW         27

// Branch
`define INST_BEQ        28
`define INST_BNE        29
`define INST_BLT        30
`define INST_BGE        31
`define INST_BLTU       32
`define INST_BGEU       33

// CSR
`define INST_CSRRW      34
`define INST_CSRRS      35
`define INST_CSRRC      36
`define INST_CSRRWI     37
`define INST_CSRRSI     38
`define INST_CSRRCI     39

`define INST_ECALL      40
`define INST_MRET       41

// 纯数值计算独热
`define REQUEST_VALUE_ONLY   42

// Load for ex to mem
`define IS_LB   0
`define IS_LH   1
`define IS_LW   2
`define IS_LBU  3
`define IS_LHU  4

    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] inst;
        logic [31:0] value1;
        logic [31:0] value2;
        logic [31:0] jump1;
        logic [31:0] jump2;
        logic [4:0]  rd_addr;
        logic        pred_taken;
        logic [3:0]  ras_snapshot;
        logic        is_ret;
        logic [11:0] csr_addr;
        logic        ecall;
        logic        mret;
        logic [31:0] fwd_rs1_data;
        logic [31:0] fwd_rs2_data;
        logic        fwd_rs1_hit_slot0_ex;
        logic        fwd_rs1_hit_slot1_ex;
        logic        fwd_rs2_hit_slot0_ex;
        logic        fwd_rs2_hit_slot1_ex;
    } data_t;

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

        // CSR
        logic sel_csrrw;
        logic sel_csrrs;
        logic sel_csrrc;
        logic sel_csrrwi;
        logic sel_csrrsi;
        logic sel_csrrci;
        logic sel_ecall;
        logic sel_mret;

        logic request_value_only;
    } decode_t;
`endif

