`ifndef ALU_DEF
`define ALU_DEF

`define OP_INST_NUM     42

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

// I-type
`define INST_ADDI            9
`define INST_XORI            10
`define INST_ORI             11
`define INST_ANDI            12
`define INST_SLLI            13
`define INST_SRLI            14
`define INST_SRAI            15
`define INST_SLTI            16
`define INST_SLTIU           17

// R-type
`define INST_ADD             18
`define INST_SUB             19
`define INST_XOR             20
`define INST_OR              21
`define INST_AND             22
`define INST_SLL             23
`define INST_SRL             24
`define INST_SRA             25
`define INST_SLT             26
`define INST_SLTU            27

// Load & Store
`define INST_LB              28
`define INST_LH              29
`define INST_LW              30
`define INST_LBU             31
`define INST_LHU             32
`define INST_SB              33
`define INST_SH              34
`define INST_SW              35

// Branch
`define INST_BEQ             36
`define INST_BNE             37
`define INST_BLT             38
`define INST_BGE             39
`define INST_BLTU            40
`define INST_BGEU            41

// Load for ex to mem
`define IS_LB   0
`define IS_LH   1
`define IS_LW   2
`define IS_LBU  3
`define IS_LHU  4

`endif