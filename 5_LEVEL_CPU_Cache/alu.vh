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

// IR-type
`define INST_IR_ADD     9
`define INST_R_SUB      10
`define INST_IR_XOR     11
`define INST_IR_OR      12
`define INST_IR_AND     13
`define INST_IR_SLL     14
`define INST_IR_SRL     15
`define INST_IR_SRA     16
`define INST_IR_SLT     17
`define INST_IR_SLTU    18

// Load & Store
`define INST_LB         19
`define INST_LH         20
`define INST_LW         21
`define INST_LBU        22
`define INST_LHU        23
`define INST_SB         24
`define INST_SH         25
`define INST_SW         26

// Branch
`define INST_BEQ        27
`define INST_BNE        28
`define INST_BLT        29
`define INST_BGE        30
`define INST_BLTU       31
`define INST_BGEU       32

// 纯数值计算独热
`define REQUEST_VALUE_ONLY   33

// Load for ex to mem
`define IS_LB   0
`define IS_LH   1
`define IS_LW   2
`define IS_LBU  3
`define IS_LHU  4

`endif