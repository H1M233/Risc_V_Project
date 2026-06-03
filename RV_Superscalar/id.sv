`include "rv32I.vh"
`include "alu.vh"

module id(
    // from if_id
    input      [31:0]   pc_addr_i,
    input      [31:0]   inst_i,
    input      [6:0]    opcode_i,
    input      [2:0]    funct3_i,
    input      [6:0]    funct7_i,
    input      [4:0]    rd_i,
    input      [4:0]    rs1_i,
    input      [4:0]    rs2_i,

    // from bpu
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,
    
    // from regs
    input      [31:0]   rs1_data_i,         // 从寄存器堆读出的寄存rs1的数据
    input      [31:0]   rs2_data_i,         // 从寄存器堆读出的寄存rs2的数据

    // to id_ex
    output data_t       data_packaged_o,
    output decode_t     inst_packaged_o,

    // from ex
    input               slot0_ex_regs_wen_i,
    input               slot1_ex_regs_wen_i,
    input      [4:0]    slot0_ex_rd_addr_i,
    input      [4:0]    slot1_ex_rd_addr_i,

    // from mem1
    input               slot0_mem1_regs_wen_i,
    input               slot1_mem1_regs_wen_i,
    input      [4:0]    slot0_mem1_rd_addr_i,
    input      [4:0]    slot1_mem1_rd_addr_i,
    input      [31:0]   slot0_mem1_rd_data_i,
    input      [31:0]   slot1_mem1_rd_data_i,

    // from mem2
    input               slot0_mem2_regs_wen_i,
    input               slot1_mem2_regs_wen_i,
    input      [4:0]    slot0_mem2_rd_addr_i,
    input      [4:0]    slot1_mem2_rd_addr_i,
    input      [31:0]   slot0_mem2_rd_data_i,
    input      [31:0]   slot1_mem2_rd_data_i,

    // from wb
    input               slot0_wb_regs_wen_i,
    input               slot1_wb_regs_wen_i,
    input      [4:0]    slot0_wb_rd_addr_i,
    input      [4:0]    slot1_wb_rd_addr_i,
    input      [31:0]   slot0_wb_rd_data_i,
    input      [31:0]   slot1_wb_rd_data_i
);  
    // 前推
    wire forwarding_rs1_slot0_ex   = (rs1_i == slot0_ex_rd_addr_i) && slot0_ex_regs_wen_i;
    wire forwarding_rs1_slot0_mem1 = (rs1_i == slot0_mem1_rd_addr_i) && slot0_mem1_regs_wen_i;
    wire forwarding_rs1_slot0_mem2 = (rs1_i == slot0_mem2_rd_addr_i) && slot0_mem2_regs_wen_i;
    wire forwarding_rs1_slot0_wb   = (rs1_i == slot0_wb_rd_addr_i) && slot0_wb_regs_wen_i;

    wire forwarding_rs1_slot1_ex   = (rs1_i == slot1_ex_rd_addr_i) && slot1_ex_regs_wen_i;
    wire forwarding_rs1_slot1_mem1 = (rs1_i == slot1_mem1_rd_addr_i) && slot1_mem1_regs_wen_i;
    wire forwarding_rs1_slot1_mem2 = (rs1_i == slot1_mem2_rd_addr_i) && slot1_mem2_regs_wen_i;
    wire forwarding_rs1_slot1_wb   = (rs1_i == slot1_wb_rd_addr_i) && slot1_wb_regs_wen_i;

    wire forwarding_rs2_slot0_ex   = (rs2_i == slot0_ex_rd_addr_i) && slot0_ex_regs_wen_i;
    wire forwarding_rs2_slot0_mem1 = (rs2_i == slot0_mem1_rd_addr_i) && slot0_mem1_regs_wen_i;
    wire forwarding_rs2_slot0_mem2 = (rs2_i == slot0_mem2_rd_addr_i) && slot0_mem2_regs_wen_i;
    wire forwarding_rs2_slot0_wb   = (rs2_i == slot0_wb_rd_addr_i) && slot0_wb_regs_wen_i;

    wire forwarding_rs2_slot1_ex   = (rs2_i == slot1_ex_rd_addr_i) && slot1_ex_regs_wen_i;
    wire forwarding_rs2_slot1_mem1 = (rs2_i == slot1_mem1_rd_addr_i) && slot1_mem1_regs_wen_i;
    wire forwarding_rs2_slot1_mem2 = (rs2_i == slot1_mem2_rd_addr_i) && slot1_mem2_regs_wen_i;
    wire forwarding_rs2_slot1_wb   = (rs2_i == slot1_wb_rd_addr_i) && slot1_wb_regs_wen_i;

    // 并行判断减少 MUX 级数
    wire forwarding_rs1_hit_mem1 = forwarding_rs1_slot0_mem1 | forwarding_rs1_slot1_mem1;
    wire forwarding_rs1_hit_mem2 = forwarding_rs1_slot0_mem2 | forwarding_rs1_slot1_mem2;
    wire forwarding_rs1_hit_wb = forwarding_rs1_slot0_wb | forwarding_rs1_slot1_wb;

    wire forwarding_rs2_hit_mem1 = forwarding_rs2_slot0_mem1 | forwarding_rs2_slot1_mem1;
    wire forwarding_rs2_hit_mem2 = forwarding_rs2_slot0_mem2 | forwarding_rs2_slot1_mem2;
    wire forwarding_rs2_hit_wb = forwarding_rs2_slot0_wb | forwarding_rs2_slot1_wb;

    wire [31:0] forwarding_rs1_hit_mem1_data = (forwarding_rs1_slot1_mem1) ? slot1_mem1_rd_data_i : slot0_mem1_rd_data_i;
    wire [31:0] forwarding_rs1_hit_mem2_data = (forwarding_rs1_slot1_mem2) ? slot1_mem2_rd_data_i : slot0_mem2_rd_data_i;
    wire [31:0] forwarding_rs1_hit_wb_data   = (forwarding_rs1_slot1_wb) ? slot1_wb_rd_data_i : slot0_wb_rd_data_i;

    wire [31:0] forwarding_rs2_hit_mem1_data = (forwarding_rs2_slot1_mem1) ? slot1_mem1_rd_data_i : slot0_mem1_rd_data_i;
    wire [31:0] forwarding_rs2_hit_mem2_data = (forwarding_rs2_slot1_mem2) ? slot1_mem2_rd_data_i : slot0_mem2_rd_data_i;
    wire [31:0] forwarding_rs2_hit_wb_data   = (forwarding_rs2_slot1_wb) ? slot1_wb_rd_data_i : slot0_wb_rd_data_i;

    wire forwarding_rs1_hit_mem = forwarding_rs1_hit_mem1 | forwarding_rs1_hit_mem2;
    wire [31:0] forwarding_rs1_hit_mem_data  = (forwarding_rs1_hit_mem1) ? forwarding_rs1_hit_mem1_data : forwarding_rs1_hit_mem2_data;
    wire [31:0] forwarding_rs1_hit_regs_data = (forwarding_rs1_hit_wb) ? forwarding_rs1_hit_wb_data : rs1_data_i;

    wire forwarding_rs2_hit_mem = forwarding_rs2_hit_mem1 | forwarding_rs2_hit_mem2;
    wire [31:0] forwarding_rs2_hit_mem_data  = (forwarding_rs2_hit_mem1) ? forwarding_rs2_hit_mem1_data : forwarding_rs2_hit_mem2_data;
    wire [31:0] forwarding_rs2_hit_regs_data = (forwarding_rs2_hit_wb) ? forwarding_rs2_hit_wb_data : rs2_data_i;

    // 前推结果
    wire [31:0] forwarding_rs1_data_hit = (forwarding_rs1_hit_mem) ? forwarding_rs1_hit_mem_data : forwarding_rs1_hit_regs_data;
    wire [31:0] forwarding_rs2_data_hit = (forwarding_rs2_hit_mem) ? forwarding_rs2_hit_mem_data : forwarding_rs2_hit_regs_data;

    // 打包
    assign inst_packaged_o = inst_packaged(inst_i, opcode_i, funct3_i, funct7_i);

    // 打包指令
    function automatic decode_t inst_packaged;
        input [31:0] inst;
        input [6:0] opcode;
        input [2:0] funct3;
        input [6:0] funct7;
        begin
            logic is_alu_i   = (opcode == `TYPE_I);
            logic is_alu_r   = (opcode == `TYPE_R);
            logic is_auipc   = (opcode == `AUIPC);
            logic is_lui     = (opcode == `LUI);
            logic is_jal     = (opcode == `JAL);
            logic is_jalr    = (opcode == `JALR);
            logic is_branch  = (opcode == `TYPE_B);
            logic is_load    = (opcode == `TYPE_L);
            logic is_store   = (opcode == `TYPE_S);
            logic is_zicsr   = (opcode == `TYPE_Zicsr);
            logic is_ecall   = (inst[31:20] == 12'b000000000000);
            logic is_mret    = (inst[31:20] == 12'b001100000010);

            // f3
            logic f3_000 = (funct3 == 3'b000);
            logic f3_001 = (funct3 == 3'b001);
            logic f3_010 = (funct3 == 3'b010);
            logic f3_011 = (funct3 == 3'b011);
            logic f3_100 = (funct3 == 3'b100);
            logic f3_101 = (funct3 == 3'b101);
            logic f3_110 = (funct3 == 3'b110);
            logic f3_111 = (funct3 == 3'b111);

            // f7
            logic f7_0000000 = (funct7 == 7'b0000000);
            logic f7_0100000 = (funct7 == 7'b0100000);

            // opcode
            inst_packaged.is_alu_i   = is_alu_i;
            inst_packaged.is_alu_r   = is_alu_r;
            inst_packaged.is_auipc   = is_auipc;
            inst_packaged.is_lui     = is_lui;
            inst_packaged.is_jal     = is_jal;
            inst_packaged.is_jalr    = is_jalr;
            inst_packaged.is_branch  = is_branch;
            inst_packaged.is_load    = is_load;
            inst_packaged.is_store   = is_store;
            inst_packaged.is_zicsr   = is_zicsr;

            // IR-type
            inst_packaged.sel_add  = (is_alu_r & f3_000 & f7_0000000) | (is_alu_i & f3_000);
            inst_packaged.sel_sub  = is_alu_r & f3_000 & f7_0100000;
            inst_packaged.sel_xor  = (is_alu_r | is_alu_i) & f3_100;
            inst_packaged.sel_or   = (is_alu_r | is_alu_i) & f3_110;
            inst_packaged.sel_and  = (is_alu_r | is_alu_i) & f3_111;
            inst_packaged.sel_sll  = (is_alu_r | is_alu_i) & f3_001;
            inst_packaged.sel_srl  = (is_alu_r | is_alu_i) & f3_101 & f7_0000000;
            inst_packaged.sel_sra  = (is_alu_r | is_alu_i) & f3_101 & f7_0100000;
            inst_packaged.sel_slt  = (is_alu_r | is_alu_i) & f3_010;
            inst_packaged.sel_sltu = (is_alu_r | is_alu_i) & f3_011;

            // Load & Store
            inst_packaged.sel_lb   = is_load & f3_000;
            inst_packaged.sel_lh   = is_load & f3_001;
            inst_packaged.sel_lw   = is_load & f3_010;
            inst_packaged.sel_lbu  = is_load & f3_100;
            inst_packaged.sel_lhu  = is_load & f3_101;
            inst_packaged.sel_sb   = is_store & f3_000;
            inst_packaged.sel_sh   = is_store & f3_001;
            inst_packaged.sel_sw   = is_store & f3_010;

            // Branch
            inst_packaged.sel_beq   = is_branch & f3_000;
            inst_packaged.sel_bne   = is_branch & f3_001;
            inst_packaged.sel_blt   = is_branch & f3_100;
            inst_packaged.sel_bge   = is_branch & f3_101;
            inst_packaged.sel_bltu  = is_branch & f3_110;
            inst_packaged.sel_bgeu  = is_branch & f3_111;

            // CSR
            inst_packaged.sel_csrrw   = is_zicsr & f3_001;
            inst_packaged.sel_csrrs   = is_zicsr & f3_010;
            inst_packaged.sel_csrrc   = is_zicsr & f3_011;
            inst_packaged.sel_csrrwi  = is_zicsr & f3_101;
            inst_packaged.sel_csrrsi  = is_zicsr & f3_110;
            inst_packaged.sel_csrrci  = is_zicsr & f3_111;
            inst_packaged.sel_ecall   = is_zicsr & f3_000 & is_ecall;
            inst_packaged.sel_mret    = is_zicsr & f3_000 & is_mret;

            // 纯数值计算独热
            inst_packaged.request_value_only = is_auipc | is_lui | is_jal | is_jalr;
        end
    endfunction

    // ==========================================================
    // reg_wen: 提前判断目标寄存器是否为 x0 寄存器，减少前推判断级数
    // 
    // value:   只用于传立即数，不传寄存器值!!!，允许在 id 内提前计算
    //          默认认为 value1 放入写入 rd 的内容
    // 
    // jump:    只用于传入跳转地址，建议在 id 内提前计算
    //          不够用可以借用
    // ==========================================================
    wire [31:0] pc_add_4 = pc_addr_i + 32'd4;

    assign data_packaged_o.pc         = pc_addr_i;
    assign data_packaged_o.inst       = inst_i;
    assign data_packaged_o.pred_taken = pred_taken_i;     // 只对 slot0 预测

    assign data_packaged_o.fwd_rs1_data         = forwarding_rs1_data_hit;
    assign data_packaged_o.fwd_rs2_data         = (inst_packaged_o.is_alu_i) ? {{20{inst_i[31]}}, inst_i[31:20]} : forwarding_rs2_data_hit;    // 立即数时返回 imm
    assign data_packaged_o.fwd_rs1_hit_slot0_ex = forwarding_rs1_slot0_ex;
    assign data_packaged_o.fwd_rs1_hit_slot1_ex = forwarding_rs1_slot1_ex;
    assign data_packaged_o.fwd_rs2_hit_slot0_ex = forwarding_rs2_slot0_ex & !inst_packaged_o.is_alu_i; // 当为立即数时，不启用前推
    assign data_packaged_o.fwd_rs2_hit_slot1_ex = forwarding_rs2_slot1_ex & !inst_packaged_o.is_alu_i;

    // CSR
    assign data_packaged_o.csr_addr  = inst_packaged_o.is_zicsr ? inst_i[31:20] : 12'h520;
    assign data_packaged_o.ecall     = inst_packaged_o.is_zicsr & inst_packaged_o.sel_ecall;
    assign data_packaged_o.mret      = inst_packaged_o.is_zicsr & inst_packaged_o.sel_mret;

    always_ff begin
        unique case(1'b1)
            inst_packaged_o.is_lui: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = {inst_i[31:12], 12'b0};
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_auipc: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = pc_addr_i + {inst_i[31:12], 12'b0};
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_jal: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = pc_add_4;
                data_packaged_o.value2   = 32'b0;                  
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_jalr: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = pc_add_4;
                data_packaged_o.value2   = {{20{inst_i[31]}}, inst_i[31:20]};
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = pred_pc_i - {{20{inst_i[31]}}, inst_i[31:20]};     // 提前计算 rs1 == pred_pc - imm
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_branch: begin
                data_packaged_o.regs_wen  = 1'b0;
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = pc_addr_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                data_packaged_o.jump2    = pc_add_4;
                data_packaged_o.rd_addr  = 5'b0;
            end

            inst_packaged_o.is_load: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = {{20{inst_i[31]}}, inst_i[31:20]};
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_store: begin
                data_packaged_o.regs_wen  = 1'b0;
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = 5'b0;
            end

            inst_packaged_o.is_alu_i: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_alu_r: begin
                data_packaged_o.regs_wen  = (rd_i != 5'b0);
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = rd_i;
            end

            inst_packaged_o.is_zicsr: begin
                case(funct3_i)
                    `CSRRW,`CSRRS,`CSRRC: begin
                        data_packaged_o.regs_wen  = (rd_i != 5'b0);
                        data_packaged_o.value1   = 32'b0;
                        data_packaged_o.value2   = 32'b0;
                        data_packaged_o.jump1    = 32'b0;
                        data_packaged_o.jump2    = 32'b0;
                        data_packaged_o.rd_addr  = rd_i;
                    end
                    `CSRRWI,`CSRRSI,`CSRRCI: begin
                        data_packaged_o.regs_wen  = (rd_i != 5'b0);
                        data_packaged_o.value1   = inst_i[19:15]; // zicsr立即数在rs1地址位
                        data_packaged_o.value2   = 32'b0;
                        data_packaged_o.jump1    = 32'b0;
                        data_packaged_o.jump2    = 32'b0;
                        data_packaged_o.rd_addr  = rd_i;
                    end
                    `ECALL_MRET: begin
                        data_packaged_o.regs_wen  = 1'b0; // ecall和mret不写寄存器
                        data_packaged_o.value1   = 32'b0;
                        data_packaged_o.value2   = 32'b0;
                        data_packaged_o.jump1    = 32'b0;
                        data_packaged_o.jump2    = 32'b0;
                        data_packaged_o.rd_addr  = 5'b0;
                    end
                    default: begin
                        data_packaged_o.regs_wen  = 1'b0;
                        data_packaged_o.value1   = 32'b0;
                        data_packaged_o.value2   = 32'b0;
                        data_packaged_o.jump1    = 32'b0;
                        data_packaged_o.jump2    = 32'b0;
                        data_packaged_o.rd_addr  = 5'b0;
                    end
                endcase
            end

            default: begin
                data_packaged_o.regs_wen  = 1'b0;
                data_packaged_o.value1   = 32'b0;
                data_packaged_o.value2   = 32'b0;
                data_packaged_o.jump1    = 32'b0;
                data_packaged_o.jump2    = 32'b0;
                data_packaged_o.rd_addr  = 5'b0;
            end
        endcase
    end
endmodule                       