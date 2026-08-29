`include "rv32I.vh"

module ex(
    // from id_ex
    input      [31:0]   inst_i,
    input      [31:0]   jump1_i,
    input      [31:0]   jump2_i,
    input      [4:0]    rd_addr_i,
    input               regs_wen_i,
    input      [31:0]   rs1_data_i,
    input      [31:0]   rs2_data_i,
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,

    // to hazard
    output reg [6:0]    hazard_opcode,

    // to ex_mem
    output reg [31:0]   inst_o,
    output reg [31:0]   mem_addr_o,
    output reg          mem_req,
    output reg          mem_wen,
    output reg          regs_wen_o,
    output reg [31:0]   rs2_data_o,

    // to ex_mem & hazard
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,

    // to jump
    output reg [31:0]   jump_addr_o,
    output reg          jump_en,

    // 没用上
    output reg [31:0]   rs1_data_o
);
    // 提取指令
    wire [6:0]  opcode = inst_i[6:0];
    wire [2:0]  funct3 = inst_i[14:12];
    wire [6:0]  funct7 = inst_i[31:25];

    // 计算
    wire [31:0] value1_add_value2           = value1_i + value2_i;                          // 操作数加法
    wire [31:0] jump1_add_jump2             = jump1_i + jump2_i;                            // 跳转数加法
    wire        value1_eq_value2            = (value1_i == value2_i);                       // 比较相等
    wire        value1_lt_value2_signed     = ($signed(value1_i) < $signed(value2_i));      // 比较小于（有符号数）
    wire        value1_lt_value2_unsigned   = (value1_i < value2_i);                        // 比较小于（无符号数）
    wire [31:0] value1_xor_value2           = value1_i ^ value2_i;                          // 异或
    wire [31:0] value1_or_value2            = value1_i | value2_i;                          // 或
    wire [31:0] value1_and_value2           = value1_i & value2_i;                          // 与
    wire [31:0] value1_sub_value2           = value1_i - value2_i;                          // 操作数减

    always@(*) begin
        regs_wen_o      = regs_wen_i;
        mem_wen         = 1'b0;
        mem_req         = 1'b0;
        mem_addr_o      = 32'b0;
        rd_data_o       = 32'b0;
        rd_addr_o       = rd_addr_i;
        rs1_data_o      = rs1_data_i;
        rs2_data_o      = rs2_data_i;
        jump_en         = 1'b0;
        jump_addr_o     = 32'b0;
        hazard_opcode   = opcode;  // 将opcode传递给hazard模块，用于冒险检测
        inst_o          = inst_i;

        case(opcode)
            `LUI: begin
                rd_data_o   = value1_add_value2;
            end
            `AUIPC: begin   
                rd_data_o   = value1_add_value2;
            end
            `JAL: begin
                rd_data_o   = value1_add_value2;
                jump_en     = 1'b1;
                jump_addr_o = jump1_add_jump2;
            end
            `JALR: begin
                rd_data_o   = value1_add_value2;
                jump_en     = 1'b1;
                jump_addr_o = jump1_add_jump2;
            end
            `TYPE_B: begin
                case(funct3)
                    `BEQ:begin
                        jump_en     = value1_eq_value2;
                        jump_addr_o = (value1_eq_value2) ? jump1_add_jump2 : 32'b0;
                    end
                    `BNE:begin
                        jump_en     = ~value1_eq_value2;
                        jump_addr_o = (~value1_eq_value2) ? jump1_add_jump2 : 32'b0;
                    end
                    `BLT:begin
                        jump_en     = value1_lt_value2_signed;
                        jump_addr_o = (value1_lt_value2_signed) ? jump1_add_jump2 : 32'b0;
                    end
                    `BGE:begin
                        jump_en     = ~value1_lt_value2_signed;
                        jump_addr_o = (~value1_lt_value2_signed) ? jump1_add_jump2 : 32'b0; 
                    end
                    `BLTU:begin
                        jump_en     = value1_lt_value2_unsigned;
                        jump_addr_o = (value1_lt_value2_unsigned) ? jump1_add_jump2 : 32'b0;
                    end
                    `BGEU:begin
                        jump_en     = ~value1_lt_value2_unsigned;
                        jump_addr_o = (~value1_lt_value2_unsigned) ? jump1_add_jump2 : 32'b0;
                    end
                    default: begin
                        jump_en     = 1'b0;
                        jump_addr_o = 32'b0;
                    end
                endcase
            end
            `TYPE_L: begin
                case(funct3)
                    `LB: begin
                        mem_req     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `LH: begin
                        mem_req     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `LW: begin
                        mem_req     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `LBU: begin
                        mem_req     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `LHU: begin
                        mem_req     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    default: begin
                        mem_req     = 1'b0;
                        mem_addr_o  = 32'b0;
                    end
                endcase
            end
            `TYPE_S: begin
                case(funct3)
                    `SB: begin
                        mem_req     = 1'b1;
                        mem_wen     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `SH: begin
                        mem_req     = 1'b1;
                        mem_wen     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    `SW: begin
                        mem_req     = 1'b1;
                        mem_wen     = 1'b1;
                        mem_addr_o  = value1_add_value2;
                    end
                    default: begin
                        mem_req     = 1'b0;
                        mem_wen     = 1'b0;
                        mem_addr_o  = 32'b0;
                    end
                endcase

            end
            `TYPE_I: begin
                case(funct3)
                    `ADDI:  rd_data_o = value1_add_value2;
                    `SLTI:  rd_data_o = value1_lt_value2_signed;
                    `SLTIU: rd_data_o = value1_lt_value2_unsigned;
                    `XORI:  rd_data_o = value1_xor_value2;
                    `ORI:   rd_data_o = value1_or_value2;
                    `ANDI:  rd_data_o = value1_and_value2;
                    `SLLI:  rd_data_o = value1_i << value2_i[4:0];
                    `SRLI_SRAI:begin
                        if      (funct7 == 7'b0000000)  rd_data_o = value1_i >> value2_i[4:0];
                        else if (funct7 == 7'b0100000)  rd_data_o = $signed(value1_i) >>> value2_i[4:0]; 
                    end
                    default:rd_data_o = 32'b0;
                endcase
            end
            `TYPE_R: begin
                case(funct3)
                    `ADD_SUB:begin
                        if      (funct7 == 7'b0000000)  rd_data_o = value1_add_value2;
                        else if (funct7 == 7'b0100000)  rd_data_o = value1_sub_value2;
                    end
                    `SLL:   rd_data_o = value1_i << value2_i[4:0];
                    `SLT:   rd_data_o = value1_lt_value2_signed;
                    `SLTU:  rd_data_o = value1_lt_value2_unsigned;
                    `XOR:   rd_data_o = value1_xor_value2;
                    `SRL_SRA:begin
                        if      (funct7 == 7'b0000000)  rd_data_o = value1_i >> value2_i[4:0];
                        else if (funct7 == 7'b0100000)  rd_data_o = $signed(value1_i) >>> value2_i[4:0]; 
                    end
                    `OR:    rd_data_o = value1_or_value2;
                    `AND:   rd_data_o = value1_and_value2;
                    default:rd_data_o = 32'b0;
                endcase
            end
            default: begin
                rd_data_o   = 32'b0;
                mem_req     = 1'b0;
                mem_wen     = 1'b0;
                mem_addr_o  = 32'b0;
                jump_en     = 1'b0;
                jump_addr_o = 32'b0;
            end
        endcase
    end
endmodule