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

`define TYPE_Zicsr    7'b1110011
`define CSRRW    3'b001
`define CSRRS    3'b010
`define CSRRC    3'b011
`define CSRRWI   3'b101
`define CSRRSI   3'b110
`define CSRRCI   3'b111

`define TYPE_AMO 7'b0101111

`define TYPE_FP       7'b1010011
`define TYPE_LOAD_FP  7'b0000111
`define TYPE_STORE_FP 7'b0100111
`define OP_FMADD      7'b1000011
`define OP_FMSUB      7'b1000111
`define OP_FNMADD     7'b1001111
`define OP_FNMSUB     7'b1001011

`define ECALL_MRET    3'b000

`define CNOP     32'h0000_0001
`define NOP      32'h0000_0013      

`define EBREAK   32'h0010_0073

`define RET      32'h00008067

`endif