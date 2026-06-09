`ifndef ALU_DEF
`define ALU_DEF

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
        logic        fwd_rs1_hit_ex;
        logic        fwd_rs2_hit_ex;
    } id_ex_data_t;

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

        // M-type
        logic sel_Mext_using_mul;
        logic sel_Mext_using_divier;
        logic sel_mul;
        logic sel_mulh;
        logic sel_mulhsu;
        logic sel_mulhu;
        logic sel_div;
        logic sel_divu;
        logic sel_rem;
        logic sel_remu;

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