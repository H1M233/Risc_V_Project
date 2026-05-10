`include "rv32I.vh"
`ifndef OOO_DEFS_VH
`define OOO_DEFS_VH

`define ROB_SIZE        32
`define ROB_IDX_WIDTH   5
`define IQ_SIZE         16
`define LSQ_SIZE        8
`define FETCHQ_DEPTH    8

`define ALU_ADD     4'd0
`define ALU_SUB     4'd1
`define ALU_AND     4'd2
`define ALU_OR      4'd3
`define ALU_XOR     4'd4
`define ALU_SLL     4'd5
`define ALU_SRL     4'd6
`define ALU_SRA     4'd7
`define ALU_SLT     4'd8
`define ALU_SLTU    4'd9
`define ALU_LUI     4'd10
`define ALU_AUIPC   4'd11

`define OPCLASS_ALU     2'd0
`define OPCLASS_BRANCH  2'd1
`define OPCLASS_MEM     2'd2

`define BR_JAL    3'b010
`define BR_JALR   3'b011

`endif
