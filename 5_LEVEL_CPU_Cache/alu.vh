`ifndef ALU_DEF
`define ALU_DEF

`define OP_INST_NUM     34

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

`endif