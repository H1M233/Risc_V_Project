`include "rv32I.vh"

module ex(
    input regs_wen_i,
    input [31:0] inst_i,
    input [31:0] value1_i,
    input [31:0] value2_i,
    input [31:0] jump1_i,
    input [31:0] jump2_i,
    input [4:0] rd_addr_i,
    input [31:0] rs1_data_i,
    input [31:0] rs2_data_i,

    output reg jump_en,
    output reg [31:0] jump_addr_o,
    output reg regs_wen_o,
    output reg [6:0] hazard_opcode,
    output reg [31:0] inst_o,

    output reg mem_wen,
    output reg mem_req,
    output reg [31:0] mem_addr_o,
    output reg [31:0] rd_data_o,
    output reg [4:0] rd_addr_o,
    output reg [31:0] rs1_data_o,
    output reg [31:0] rs2_data_o
);
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];

    wire [31:0] value1_add_value2;   //操作数加法
    assign value1_add_value2 = value1_i + value2_i;

    wire [31:0] jump1_add_jump2;    //跳转数加法
    assign jump1_add_jump2 = jump1_i + jump2_i;

    wire value1_eq_value2;          //比较相等
    assign value1_eq_value2 = (value1_i == value2_i);

    wire value1_lt_value2_signed;   //比较小于（有符号数）
    assign value1_lt_value2_signed = ($signed(value1_i) < $signed(value2_i));

    wire value1_lt_value2_unsigned; //比较小于（无符号数）
    assign value1_lt_value2_unsigned = (value1_i < value2_i);

    wire [31:0] value1_xor_value2;  //异或
    assign value1_xor_value2 = value1_i ^ value2_i;

    wire [31:0] value1_or_value2;   //或
    assign value1_or_value2 = value1_i | value2_i;

    wire [31:0] value1_and_value2;  //与
    assign value1_and_value2 = value1_i & value2_i;
    
    wire [31:0] value1_sub_value2;  //操作数减法
    assign value1_sub_value2 = value1_i - value2_i;

    always@(*) begin
        regs_wen_o = regs_wen_i;
        mem_wen = 1'b0;
        mem_req = 1'b0;
        mem_addr_o = 32'b0;
        rd_data_o = 32'b0;
        rd_addr_o = rd_addr_i;
        rs1_data_o = rs1_data_i;
        rs2_data_o = rs2_data_i;
        jump_en = 1'b0;
        jump_addr_o = 32'b0;
        hazard_opcode = opcode;  // 将opcode传递给hazard模块，用于冒险检测
        inst_o = inst_i;

        case(opcode)
            `LUI: begin
                rd_data_o = value1_add_value2;
            end
            `AUIPC: begin   
                rd_data_o = value1_add_value2;
            end
            `JAL: begin
                rd_data_o = value1_add_value2;
                jump_en = 1'b1;
                jump_addr_o = jump1_add_jump2;
            end
            `JALR: begin
                rd_data_o = value1_add_value2;
                jump_en = 1'b1;
                jump_addr_o = jump1_add_jump2;
            end
            `TYPE_B: begin
                case(funct3)
                    `BEQ:begin
                        jump_en = value1_eq_value2;
                        jump_addr_o = (value1_eq_value2) ? jump1_add_jump2 : 32'b0;
                    end
                    `BNE:begin
                        jump_en = ~value1_eq_value2;
                        jump_addr_o = (~value1_eq_value2) ? jump1_add_jump2 : 32'b0;
                    end
                    `BLT:begin
                        jump_en = value1_lt_value2_signed;
                        jump_addr_o = (value1_lt_value2_signed) ? jump1_add_jump2 : 32'b0;
                    end
                    `BGE:begin
                        jump_en = ~value1_lt_value2_signed;
                        jump_addr_o = (~value1_lt_value2_signed) ? jump1_add_jump2 : 32'b0; 
                    end
                    `BLTU:begin
                        jump_en = value1_lt_value2_unsigned;
                        jump_addr_o = (value1_lt_value2_unsigned) ? jump1_add_jump2 : 32'b0;
                    end
                    `BGEU:begin
                        jump_en = ~value1_lt_value2_unsigned;
                        jump_addr_o = (~value1_lt_value2_unsigned) ? jump1_add_jump2 : 32'b0;
                    end
                    default: begin
                        jump_en = 1'b0;
                        jump_addr_o = 32'b0;
                    end
                endcase
            end
            `TYPE_L: begin
                case(funct3)
                    `LB: begin
                        mem_req = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `LH: begin
                        mem_req = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `LW: begin
                        mem_req = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `LBU: begin
                        mem_req = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `LHU: begin
                        mem_req = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    default: begin
                        mem_req = 1'b0;
                        mem_addr_o = 32'b0;
                    end
                endcase
            end
            `TYPE_S: begin
                case(funct3)
                    `SB: begin
                        mem_req = 1'b1;
                        mem_wen = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `SH: begin
                        mem_req = 1'b1;
                        mem_wen = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    `SW: begin
                        mem_req = 1'b1;
                        mem_wen = 1'b1;
                        mem_addr_o = value1_add_value2;
                    end
                    default: begin
                        mem_req = 1'b0;
                        mem_wen = 1'b0;
                        mem_addr_o = 32'b0;
                    end
                endcase

            end
            `TYPE_I: begin
                case(funct3)
                    `ADDI:begin
                        rd_data_o = value1_add_value2;
                    end
                    `SLTI:begin
                        rd_data_o = value1_lt_value2_signed;
                    end
                    `SLTIU:begin
                        rd_data_o = value1_lt_value2_unsigned;
                    end
                    `XORI:begin
                        rd_data_o = value1_xor_value2;
                    end
                    `ORI:begin
                        rd_data_o = value1_or_value2;
                    end
                    `ANDI:begin
                        rd_data_o = value1_and_value2;
                    end
                    `SLLI:begin
                        rd_data_o = value1_i << value2_i[4:0];
                    end
                    `SRLI_SRAI:begin
                        if(funct7 == 7'b0000000) begin
                            rd_data_o = value1_i >> value2_i[4:0];
                        end
                        else if(funct7 == 7'b0100000) begin
                            rd_data_o = $signed(value1_i) >>> value2_i[4:0]; 
                        end
                    end
                    default: begin
                        rd_data_o = 32'b0;
                    end
                endcase
            end
            `TYPE_R: begin
                case(funct3)
                    `ADD_SUB:begin
                        if(funct7 == 7'b0000000) begin
                            rd_data_o = value1_add_value2;
                        end
                        else if(funct7 == 7'b0100000) begin
                            rd_data_o = value1_sub_value2;
                        end
                    end
                    `SLL:begin
                        rd_data_o = value1_i << value2_i[4:0];
                    end
                    `SLT:begin
                        rd_data_o = value1_lt_value2_signed;
                    end
                    `SLTU:begin
                        rd_data_o = value1_lt_value2_unsigned;
                    end
                    `XOR:begin
                        rd_data_o = value1_xor_value2;
                    end
                    `SRL_SRA:begin
                        if(funct7 == 7'b0000000) begin
                            rd_data_o = value1_i >> value2_i[4:0];
                        end
                        else if(funct7 == 7'b0100000) begin
                            rd_data_o = $signed(value1_i) >>> value2_i[4:0]; 
                        end
                    end
                    `OR:begin
                        rd_data_o = value1_or_value2;
                    end
                    `AND:begin
                        rd_data_o = value1_and_value2;
                    end
                    default: begin
                        rd_data_o = 32'b0;
                    end
                endcase
            end
            default: begin
                rd_data_o = 32'b0;
                mem_req = 1'b0;
                mem_wen = 1'b0;
                mem_addr_o = 32'b0;
                jump_en = 1'b0;
                jump_addr_o = 32'b0;
            end
        endcase
    end
endmodule