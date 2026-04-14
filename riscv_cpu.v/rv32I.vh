`ifndef HEAD
`define HEAD

`define LUI      7'b0110111     
`define AUIPC    7'b0010111    

`define JAL      7'b1101111
`define JALR     7'b1100111

`define TYPE_B   7'b1100011
`define BEQ      3'b000
`define BNE      3'b001
`define BLT      3'b100
`define BGE      3'b101
`define BLTU     3'b110
`define BGEU     3'b111

`define TYPE_L   7'b0000011
`define LB       3'b000
`define LH       3'b001
`define LW       3'b010
`define LBU      3'b100
`define LHU      3'b101

`define TYPE_S   7'b0100011
`define SB       3'b000
`define SH       3'b001
`define SW       3'b010

`define TYPE_I   7'b0010011
`define ADDI     3'b000
`define SLTI     3'b010
`define SLTIU    3'b011
`define XORI     3'b100
`define ORI      3'b110
`define ANDI     3'b111
`define SLLI     3'b001
`define SRLI_SRAI      3'b101        

`define TYPE_R   7'b0110011
`define ADD_SUB  3'b000         
`define SLL      3'b001
`define SLT      3'b010
`define SLTU     3'b011
`define XOR      3'b100
`define SRL_SRA  3'b101        
`define OR       3'b110
`define AND      3'b111

`define NOP      32'h0000_0013      

`endif