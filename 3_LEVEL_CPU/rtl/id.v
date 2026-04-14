`include "defines.v"

module id(
    // from if_id
    input   wire[31:0]  inst_addr_i,
    input   wire[31:0]  inst_i,

    // from regs
    input   wire[31:0]  rs1_data_i,
    input   wire[31:0]  rs2_data_i,

    // to regs
    output  reg[4:0]    rs1_addr_o,
    output  reg[4:0]    rs2_addr_o,

    // to id_ex
    output  reg[31:0]   inst_addr_o,
    output  reg[31:0]   inst_o,
    output  reg[31:0]   op1_o,
    output  reg[31:0]   op2_o,
    output  reg[4:0]    rd_addr_o,
    output  reg         rd_wen_o,
    output  reg[31:0]   base_addr_o,
    output  reg[31:0]   addr_offest_o,

    // to ram
    output  reg[31:0]   mem_r_addr_o,
    output  reg         mem_r_req_o
);

    // I型
    wire[6:0] opcode    = inst_i[6:0];      // 6-0位    opcode
    wire[4:0] rd        = inst_i[11:7];     // 11-7位   rd
    wire[2:0] func3     = inst_i[14:12];    // 14-12位  func3
    wire[4:0] rs1       = inst_i[19:15];    // 19-15位  rs1
    wire[11:0] imm      = inst_i[31:20];    // 31-20位  imm
    wire[4:0] shamt     = inst_i[24:20];    // 24-20位  shamt

    // R型
    wire[4:0] rs2       = inst_i[24:20];     // 24-20位  rs2
    wire[6:0] func7     = inst_i[31:25];     // 31-25位  func7

    always@(*) begin
        inst_o      = inst_i;
        inst_addr_o = inst_addr_i;
        case(opcode)

            // I型
            `INST_TYPE_I:begin
                base_addr_o     = 32'b0;
                addr_offest_o   = 32'b0;
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;

                case(func3)

                    // 立即数ADDI模式: rd = rs1 + imm
                    // 立即数XORI模式: rd = rs1 ^ imm
                    // 立即数ORI模式: rd = rs1 | imm
                    // 立即数ANDI模式: rd = rs1 & imm
                    // 立即数SLTI模式: rd = (rs1 < imm) ? 1 : 0 - 有符号比较
                    // 立即数SLTIU模式: rd = (rs1 < imm) ? 1 : 0 - 无符号比较 - 为保证代码统一便利，SLTIU仍需符号位扩展
                    `INST_ADDI, `INST_XORI, `INST_ORI, `INST_ANDI, `INST_SLTI, `INST_SLTIU:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = 5'b0;                     // 可考虑删除
                        op1_o       = rs1_data_i;
                        op2_o       = {{20{imm[11]}}, imm};     // 符号位扩展，imm最高位填充32位
                        rd_addr_o   = rd;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数SLLI模式: 左移rd = rs1 << imm[0:4]
                    // 立即数SRLI和SRAI模式：rd = rs1 >> imm[0:4]
                    `INST_SLLI, `INST_SRI:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = 5'b0;                     // 可考虑删除
                        op1_o       = rs1_data_i;
                        op2_o       = {27'b0, shamt};           // 位移运算无需符号位扩展，imm[0:4]填充0至32位
                        rd_addr_o   = rd;
                        rd_wen_o    = 1'b1;
                    end

                    // 默认状态下全给0
                    default:begin
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = 5'b0; 
                        rd_wen_o    = 1'b0;
                    end
                endcase
            end

            // R型
            `INST_TYPE_R_M:begin
                base_addr_o     = 32'b0;
                addr_offest_o   = 32'b0;
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;

                case(func3)

                    // 加减法ADD_SUB模式: rd = rs1 + rs2 或 rd = rs1 - rs2
                    // XOR模式: rd = rs1 ^ imm
                    // OR模式: rd = rs1 | imm
                    // AND模式: rd = rs1 & imm
                    // SLT模式: rd = (rs1 < rs2) ? 1 : 0 - 有符号比较
                    // SLTU模式: rd = (rs1 < rs2) ? 1 : 0 - 无符号比较
                    `INST_ADD_SUB, `INST_XOR, `INST_OR, `INST_AND, `INST_SLT, `INST_SLTU:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = rs2;
                        op1_o       = rs1_data_i;
                        op2_o       = rs2_data_i;
                        rd_addr_o   = rd;
                        rd_wen_o    = 1'b1;
                    end

                    // SLL模式: 左移rd = rs1 << rs2
                    // SRL和SRA模式：rd = rs1 >> rs2
                    `INST_SLL, `INST_SR:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = rs2;
                        op1_o       = rs1_data_i;
                        op2_o       = {27'b0, rs2_data_i[4:0]}; // 需要手动截5位(32位情况下), 默认运算存在问题（32位最多移32位）
                        rd_addr_o   = rd;
                        rd_wen_o    = 1'b1;
                    end

                    // 默认状态下全给0
                    default:begin
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = 5'b0; 
                        rd_wen_o    = 1'b0;
                    end
                endcase
            end

            // B型
            `INST_TYPE_B:begin
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;

                case(func3)
                    // BNE  不等于跳转          !=
                    // BEQ  等于跳转            ==
                    // BLT  小于跳转            <
                    // BGE  大于等于跳转        >=
                    // BLTU 无符号小于跳转      <   - u
                    // BGEU 无符号大于等于跳转  >=  - u
                    `INST_BNE, `INST_BEQ, `INST_BLT, `INST_BGE, `INST_BLTU, `INST_BGEU:begin
                        rs1_addr_o      = rs1;
                        rs2_addr_o      = rs2;
                        op1_o           = rs1_data_i;
                        op2_o           = rs2_data_i;
                        rd_addr_o       = 5'b0;
                        rd_wen_o        = 1'b0;
                        base_addr_o     = inst_addr_i;
                        addr_offest_o   = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0}; // imm[12|10:5], imm[4:1|11]
                    end

                    default:begin
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = 5'b0;
                        rd_wen_o    = 1'b0;
                        base_addr_o     = 32'b0;
                        addr_offest_o   = 32'b0;
                    end
                endcase
            end

            // L型
            `INST_TYPE_L:begin
                case(func3)

                    // LoadBit, LoadHalf, LoadWord, LoadBitUnsigned, LoadHalfUnsigned: rd = M[rs1 + imm][..]
                    `INST_LB, `INST_LH, `INST_LW, `INST_LBU, `INST_LHU:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = rd;
                        rd_wen_o    = 1'b1;
                        base_addr_o     = inst_addr_i;
                        addr_offest_o   = {{20{imm[11]}}, imm};
                        mem_r_addr_o   = rs1 + {{20{imm[11]}}, imm};
                        mem_r_req_o    = 1'b1;
                    end

                    default:begin
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = 32'b0;
                        rd_wen_o    = 1'b0;
                        base_addr_o     = 32'b0;
                        addr_offest_o   = 32'b0;
                        mem_r_addr_o   = 32'b0;
                        mem_r_req_o    = 1'b0;
                    end
                endcase
            end

            // S型
            `INST_TYPE_S:begin
                case(func3)

                    // StoreByte, StoreHalf, StoreWord: M[rs1 + imm][..] = rs2[..]
                    `INST_SB, `INST_SH, `INST_SW:begin
                        rs1_addr_o  = rs1;
                        rs2_addr_o  = rs2;
                        op1_o       = 5'b0;
                        op2_o       = rs2_data_i;
                        rd_addr_o   = 5'b0;
                        rd_wen_o    = 1'b1;
                        base_addr_o     = rs1_data_i;
                        addr_offest_o   = {{20{inst_i[31]}},inst_i[31:25],inst_i[11:7]};
                        mem_r_addr_o   = 32'b0;
                        mem_r_req_o    = 1'b0;
                    end

                    default:begin
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        op1_o       = 32'b0;
                        op2_o       = 32'b0;
                        rd_addr_o   = 32'b0;
                        rd_wen_o    = 1'b0;
                        base_addr_o     = 32'b0;
                        addr_offest_o   = 32'b0;
                        mem_r_addr_o   = 32'b0;
                        mem_r_req_o    = 1'b0;
                    end
                endcase
            end

            // JAL跳跃: rd = pc + 4; pc += imm
            `INST_JAL:begin
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                op1_o       = inst_addr_i;
                op2_o       = 32'b0;
                rd_addr_o   = rd;
                rd_wen_o    = 1'b1;
                base_addr_o     = inst_addr_i;
                addr_offest_o   = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0}; // imm[20|10:1|11|19:12]
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;
            end

            // LUI: rd = imm << 12
            `INST_LUI:begin
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                op1_o       = {inst_i[31:12], 12'b0};   // imm[31:12]
                op2_o       = 32'b0;
                rd_addr_o   = rd;
                rd_wen_o    = 1'b1;
                base_addr_o     = 32'b0;
                addr_offest_o   = 32'b0;
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;
            end

            // JALR跳跃: rd = pc + 4; pc = rs1 + imm
            `INST_JALR:begin
                rs1_addr_o  = rs1;
                rs2_addr_o  = 5'b0;
                op1_o       = rs1_data_i;
                op2_o       = {{20{imm[11]}}, imm};
                rd_addr_o   = rd;
                rd_wen_o    = 1'b1;
                base_addr_o     = rs1_data_i;
                addr_offest_o   = {{20{imm[11]}}, imm};
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;
            end

            // AUIPC: rd = pc + (imm << 12)
            `INST_AUIPC:begin
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                op1_o       = inst_addr_i;
                op2_o       = {inst_i[31:12], 12'b0};   // imm[31:12]
                rd_addr_o   = rd;
                rd_wen_o    = 1'b1;
                base_addr_o     = 32'b0;
                addr_offest_o   = 32'b0;
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;
            end

            default:begin
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                op1_o       = 32'b0;
                op2_o       = 32'b0;
                rd_addr_o   = 5'b0;
                rd_wen_o    = 1'b0;
                base_addr_o     = 32'b0;
                addr_offest_o   = 32'b0;
                mem_r_addr_o   = 32'b0;
                mem_r_req_o    = 1'b0;
            end
        endcase
    end


endmodule