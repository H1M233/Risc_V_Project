`include "defines.v"

module ex(
    // from id_ex
    input   wire[31:0]  inst_addr_i,
    input   wire[31:0]  inst_i,
    input   wire[31:0]  op1_i,
    input   wire[31:0]  op2_i,
    input   wire[4:0]   rd_addr_i,
    input   wire        rd_wen_i,
    input   wire[31:0]  base_addr_i,
    input   wire[31:0]  addr_offest_i,

    // to regs
    output  reg[4:0]    rd_addr_o,
    output  reg[31:0]   rd_data_o,
    output  reg         rd_wen_o,

    // to ctrl
    output  reg[31:0]   jump_addr_o,
    output  reg         jump_en_o,
    output  reg         hold_flag_o,

    // from mem - read
    input   wire[31:0]  mem_r_data_i,

    // to mem - write
    output  reg[31:0]   mem_w_addr_o,
    output  reg[31:0]   mem_w_data_o,
    output  reg[3:0]    mem_w_sel_o
);

    // 运算器
    wire[31:0]  op1_i_add_op2_i     = op1_i + op2_i;
    wire[31:0]  op1_i_sub_op2_i     = op1_i - op2_i;
    wire[31:0]  op1_i_xor_op2_i     = op1_i ^ op2_i;
    wire[31:0]  op1_i_or_op2_i      = op1_i | op2_i;
    wire[31:0]  op1_i_and_op2_i     = op1_i & op2_i;
    wire[31:0]  op1_i_sll_op2_i     = op1_i << op2_i;
    wire[31:0]  op1_i_srl_op2_i     = op1_i >> op2_i;
    wire[31:0]  op1_i_sra_op2_i     = $signed(op1_i) >>> op2_i;

    // I型
    wire[6:0]   opcode              = inst_i[6:0];      // 6-0位    opcode
    wire[4:0]   rd                  = inst_i[11:7];     // 11-7位   rd
    wire[2:0]   func3               = inst_i[14:12];    // 14-12位  func3
    wire[4:0]   rs1                 = inst_i[19:15];    // 19-15位  rs1
    wire[11:0]  imm                 = inst_i[31:20];    // 31-20位  imm

    // R型
    wire[4:0]   rs2                 = inst_i[24:20];    // 24-20位  rs2
    wire[6:0]   func7               = inst_i[31:25];    // 31-25位  func7

    // B型
    wire        op1_i_equal_op2_i   = (op1_i == op2_i);                         // 判断 =
    wire        op1_i_less_op2_i    = ($signed(op1_i) < $signed(op2_i));        // 判断 <
    wire        op1_i_uless_op2_i   = ($unsigned(op1_i) < $unsigned(op2_i));    // 无符号判断 <
    wire[31:0]  base_addr_add_addr_offset    = base_addr_i + addr_offest_i;   // pc + imm

    // S和L索引
    wire[1:0]   load_index          = base_addr_add_addr_offset[1:0];
    wire[1:0]   store_index         = base_addr_add_addr_offset[1:0];

    always@(*) begin

        case(opcode)

            // I型
            `INST_TYPE_I:begin
                // 重置ctrl
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;

                case(func3)

                    // 立即数ADDI模式: rd = rs1 + imm
                    `INST_ADDI:begin
                        rd_data_o   = op1_i_add_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数XORI模式: rd = rs1 ^ imm
                    `INST_XORI:begin
                        rd_data_o   = op1_i_xor_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数ORI模式: rd = rs1 | imm
                    `INST_ORI:begin
                        rd_data_o   = op1_i_or_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数ANDI模式: rd = rs1 & imm
                    `INST_ANDI:begin
                        rd_data_o   = op1_i_and_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数SLLI模式: 左移rd = rs1 << imm[0:4]
                    `INST_SLLI:begin
                        rd_data_o   = op1_i_sll_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // 立即数SRLI和SRAI模式：rd = rs1 >> imm[0:4]
                    `INST_SRI:begin
                        if(!inst_i[30]) begin                   // SRLI(func7 = 000_0000): 逻辑右移 - 高位补0
                            rd_data_o   = op1_i_srl_op2_i;
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else if(inst_i[30]) begin               // SRAI(func7 = 010_0000): 算数右移 - 高位补原操作数的符号位
                            rd_data_o   = op1_i_sra_op2_i;      // >>>为算数右移操作，操作数为signed类型
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else begin                              // 无效操作
                            rd_data_o   = 32'b0;
                            rd_addr_o   = 5'b0;
                            rd_wen_o    = 1'b0;
                        end
                    end

                    // 立即数SLTI模式: rd = (rs1 < imm) ? 1 : 0 - 有符号比较
                    `INST_SLTI:begin
                        rd_data_o = (op1_i_less_op2_i) ? 32'b1 : 32'b0;
                        rd_addr_o = rd_addr_i;
                        rd_wen_o = 1'b1;
                    end

                    // 立即数SLTIU模式: rd = (rs1 < imm) ? 1 : 0 - 无符号比较
                    `INST_SLTIU:begin
                        rd_data_o = (op1_i_uless_op2_i) ? 32'b1 : 32'b0;
                        rd_addr_o = rd_addr_i;
                        rd_wen_o = 1'b1;
                    end

                    // 默认状态下全给0
                    default:begin
                        rd_data_o = 32'b0;
                        rd_addr_o = 5'b0;
                        rd_wen_o = 1'b0;
                    end
                endcase
            end

            // R型
            `INST_TYPE_R_M:begin
                // 重置ctrl
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;

                case(func3)

                    // 加减法ADD_SUB模式
                    `INST_ADD_SUB:begin
                        if(!inst_i[30]) begin                   // ADD(func7 = 000_0000)
                            rd_data_o   = op1_i_add_op2_i;
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else if(inst_i[30]) begin               // SUB(func7 = 010_0000)或许可被直接优化为else
                            rd_data_o   = op1_i_sub_op2_i;
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else begin                              // 无效操作
                            rd_data_o   = 32'b0;
                            rd_addr_o   = 5'b0;
                            rd_wen_o    = 1'b0;
                        end
                    end

                    // XOR模式: rd = rs1 ^ imm
                    `INST_XOR:begin
                        rd_data_o   = op1_i_xor_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // OR模式: rd = rs1 | imm
                    `INST_OR:begin
                        rd_data_o   = op1_i_or_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // AND模式: rd = rs1 & imm
                    `INST_AND:begin
                        rd_data_o   = op1_i_and_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // SLL模式: 左移rd = rs1 << rs2
                    `INST_SLL:begin
                        rd_data_o   = op1_i_sll_op2_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // SRL和SRA模式：rd = rs1 >> rs2
                    `INST_SR:begin
                        if(!inst_i[30]) begin                   // SRL(func7 = 000_0000): 逻辑右移 - 高位补0
                            rd_data_o   = op1_i_srl_op2_i;
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else if(inst_i[30]) begin               // SRA(func7 = 010_0000): 算数右移 - 高位补原操作数的符号位
                            rd_data_o   = op1_i_sra_op2_i;      // >>>为算数右移操作，操作数为signed类型
                            rd_addr_o   = rd_addr_i;
                            rd_wen_o    = 1'b1;
                        end
                        else begin                              // 无效操作
                            rd_data_o   = 32'b0;
                            rd_addr_o   = 5'b0;
                            rd_wen_o    = 1'b0;
                        end
                    end

                    // SLT模式: rd = (rs1 < rs2) ? 1 : 0 - 有符号比较
                    `INST_SLT:begin
                        rd_data_o = (op1_i_less_op2_i) ? 32'b1 : 32'b0;
                        rd_addr_o = rd_addr_i;
                        rd_wen_o = 1'b1;
                    end

                    // SLTU模式: rd = (rs1 < rs2) ? 1 : 0 - 无符号比较
                    `INST_SLTU:begin
                        rd_data_o = (op1_i_uless_op2_i) ? 32'b1 : 32'b0;
                        rd_addr_o = rd_addr_i;
                        rd_wen_o = 1'b1;
                    end

                    // 默认状态下全给0
                    default:begin
                        rd_data_o = 32'b0;
                        rd_addr_o = 5'b0;
                        rd_wen_o = 1'b0;
                    end
                endcase
            end

            // L型
            `INST_TYPE_L:begin
                // 重置ctrl
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;

                case(func3)

                    // LoadBit: rd = M[rs1 + imm][0:7]
                    `INST_LB:begin
                        // 移至最低位并扩展
                        case(load_index)
							2'b00:      rd_data_o = {{24{mem_r_data_i[7]}}, mem_r_data_i[7:0]};	
							2'b01:      rd_data_o = {{24{mem_r_data_i[15]}}, mem_r_data_i[15:8]};
							2'b10:      rd_data_o = {{24{mem_r_data_i[23]}}, mem_r_data_i[23:16]};
							2'b11:      rd_data_o = {{24{mem_r_data_i[31]}}, mem_r_data_i[31:24]};
							default:    rd_data_o = 32'b0;
						endcase
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // LoadHalf: rd = M[rs1 + imm][0:15]
                    `INST_LH:begin
                        // 移至最低位并扩展
                        case(load_index[1])
							1'b0:       rd_data_o = {{16{mem_r_data_i[15]}}, mem_r_data_i[15:0]};	
							1'b1:       rd_data_o = {{16{mem_r_data_i[31]}}, mem_r_data_i[31:16]};
							default:    rd_data_o = 32'b0;
						endcase
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end
                    
                    // LoadWord: rd = M[rs1 + imm][0:31]
                    `INST_LW:begin
                        rd_data_o   = mem_r_data_i;
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // LoadBitUnsigned: rd = M[rs1 + imm][0:7] - 0扩展
                    `INST_LBU:begin
                        // 移至最低位并0扩展
                        case(load_index)
							2'b00:      rd_data_o = {24'b0, mem_r_data_i[7:0]};	
							2'b01:      rd_data_o = {24'b0, mem_r_data_i[15:8]};
							2'b10:      rd_data_o = {24'b0, mem_r_data_i[23:16]};
							2'b11:      rd_data_o = {24'b0, mem_r_data_i[31:24]};
							default:    rd_data_o = 32'b0;
						endcase
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end

                    // LoadHalfUnsigned: rd = M[rs1 + imm][0:15] - 0扩展
                    `INST_LHU:begin
                        // 移至最低位并0扩展
                        case(load_index[1])
							1'b0:       rd_data_o = {16'b0, mem_r_data_i[15:0]};	
							1'b1:       rd_data_o = {16'b0, mem_r_data_i[31:16]};
							default:    rd_data_o = 32'b0;
						endcase
                        rd_addr_o   = rd_addr_i;
                        rd_wen_o    = 1'b1;
                    end
                    
                    // 默认状态下全给0
                    default:begin
                        rd_data_o   = 32'b0;
                        rd_addr_o   = 5'b0;
                        rd_wen_o    = 1'b0;
                    end
                endcase
            end

            // S型
            `INST_TYPE_S:begin
                // 无需返回寄存器
                rd_data_o   = 32'b0;
                rd_addr_o   = 5'b0;
                rd_wen_o    = 1'b0;

                // 重置ctrl
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                case(func3)

                    // StoreBit: M[rs1 + imm][7:0] = rs2[7:0]
                    `INST_SB:begin
                        case(store_index)
                            2'b00:begin
                                mem_w_data_o    = {24'b0, op2_i[7:0]};
                                mem_w_sel_o     = 4'b0001;
                            end
                            2'b01:begin
                                mem_w_data_o    = {16'b0, op2_i[7:0], 8'b0};
                                mem_w_sel_o     = 4'b0010;
                            end
                            2'b10:begin
                                mem_w_data_o    = {8'b0, op2_i[7:0], 16'b0};
                                mem_w_sel_o     = 4'b0100;
                            end
                            2'b11:begin
                                mem_w_data_o    = {op2_i[7:0], 24'b0};
                                mem_w_sel_o     = 4'b1000;
                            end
                            default:begin
                                mem_w_data_o    = 32'b0;
                                mem_w_sel_o     = 4'b0000;
                            end
                        endcase
                        mem_w_addr_o    = base_addr_add_addr_offset;
                    end

                    // StoreHalf: M[rs1 + imm][15:0] = rs2[15:0]
                    `INST_SH:begin
                        case(store_index[1])
                            1'b0:begin
                                mem_w_data_o    = {16'b0, op2_i[15:0]};
                                mem_w_sel_o     = 4'b0011;
                            end
                            1'b1:begin
                                mem_w_data_o    = {op2_i[15:0], 16'b0};
                                mem_w_sel_o     = 4'b1100;
                            end
                            default:begin
                                mem_w_data_o    = 32'b0;
                                mem_w_sel_o     = 4'b0000;
                            end
                        endcase
                        mem_w_addr_o    = base_addr_add_addr_offset;
                    end
                    
                    // StoreWord: M[rs1 + imm] = rs2
                    `INST_SW:begin
                        mem_w_addr_o    = base_addr_add_addr_offset;
                        mem_w_data_o    = op2_i;
                        mem_w_sel_o     = 4'b1111;
                    end
                    
                    // 默认状态下全给0
                    default:begin
                        mem_w_addr_o    = 32'b0;
                        mem_w_data_o    = 32'b0;
                        mem_w_sel_o     = 4'b0;
                    end
                endcase
            end

            // B型
            `INST_TYPE_B:begin
                // 无需返回寄存器
                rd_data_o   = 32'b0;
                rd_addr_o   = 5'b0;
                rd_wen_o    = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;

                case(func3)

                    // BEQ模式: if(rs1 == rs2) pc += imm
                    `INST_BEQ:begin
                        jump_addr_o     = base_addr_add_addr_offset;
                        jump_en_o       = op1_i_equal_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // BNE模式: if(rs1 != rs2) pc += imm
                    `INST_BNE:begin
                        jump_addr_o     = base_addr_add_addr_offset;
                        jump_en_o       = ~op1_i_equal_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // BLT模式: if(rs1 < rs2) pc += imm
                    `INST_BLT:begin
                        jump_addr_o     = base_addr_add_addr_offset; 
                        jump_en_o       = op1_i_less_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // BGE模式: if(rs1 >= rs2) pc += imm
                    `INST_BGE:begin
                        jump_addr_o     = base_addr_add_addr_offset;
                        jump_en_o       = ~op1_i_less_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // BLTU模式: if(rs1 < rs2) pc += imm - 无符号
                    `INST_BLTU:begin
                        jump_addr_o     = base_addr_add_addr_offset;
                        jump_en_o       = op1_i_uless_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // BGEU模式: if(rs1 >= rs2) pc += imm - 无符号
                    `INST_BGEU:begin
                        jump_addr_o     = base_addr_add_addr_offset;
                        jump_en_o       = ~op1_i_uless_op2_i;
                        hold_flag_o     = 1'b0;
                    end

                    // 默认状态下全给0
                    default:begin
                        jump_addr_o     = 32'b0;
                        jump_en_o       = 1'b0;
                        hold_flag_o     = 1'b0;
                    end
                endcase
            end

            // JAL和JALR跳跃: rd = pc + 4; pc += imm
            `INST_JAL, `INST_JALR:begin
                rd_data_o       = inst_addr_i + 32'h4;
                rd_addr_o       = rd_addr_i;
                rd_wen_o        = 1'b1;
                jump_addr_o     = base_addr_add_addr_offset;
                jump_en_o       = 1'b1;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;
            end

            // LUI: rd = imm << 12
            `INST_LUI:begin
                rd_data_o       = op1_i;
                rd_addr_o       = rd_addr_i;
                rd_wen_o        = 1'b1;
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0 ;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;
            end

            // AUIPC: rd = pc + (imm << 12) 
            `INST_AUIPC:begin
                rd_data_o       = op1_i_add_op2_i;
                rd_addr_o       = rd_addr_i;
                rd_wen_o        = 1'b1;
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;
            end

            default:begin
                rd_data_o       = 32'b0;
                rd_addr_o       = 5'b0;
                rd_wen_o        = 1'b0;
                
                // 重置ctrl
                jump_addr_o     = 32'b0;
                jump_en_o       = 1'b0;
                hold_flag_o     = 1'b0;

                // 重置ram
                mem_w_addr_o    = 32'b0;
                mem_w_data_o    = 32'b0;
                mem_w_sel_o     = 4'b0;
            end
        endcase
    end
endmodule