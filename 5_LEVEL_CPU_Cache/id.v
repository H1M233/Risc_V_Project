`include "rv32I.vh"
`include "alu.vh"

module id(
    // from if_id
    (* max_fanout = 30 *)
    input      [31:0]   inst_i,             // 从if_id模块传来的指令内容
    input      [31:0]   pc_addr_i,          // 从if_id模块传来的指令地址
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
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   inst_o,             // 传入给id_ex模块的指令内容
    output reg [31:0]   jump1_o,            // 传入跳转指令地址1
    output reg [31:0]   jump2_o,            // 传入跳转指令地址2
    output reg [4:0]    rd_addr_o,          // 传入指令rd地址
    output reg          reg_wen,            // 寄存器写使能信号
    output reg [31:0]   value1_o,           // 传入寄存器1的数据
    output reg [31:0]   value2_o,           // 传入寄存器2的数据
    output reg          pred_taken_o,
    output reg [`OP_INST_NUM - 1:0] inst_packaged_o,

    // to regs & hazard
    output reg [4:0]    rs1_addr_o,
    output reg [4:0]    rs2_addr_o,

    // from ex
    input               ex_regs_wen_i,
    input      [4:0]    ex_rd_addr_i,
    input               ex_is_load_i,

    // from mem1
    input               mem1_regs_wen_i,
    input      [4:0]    mem1_rd_addr_i,
    input      [31:0]   mem1_rd_data_i,
    input               mem1_is_load_i,

    // from mem2
    input               mem2_regs_wen_i,
    input      [4:0]    mem2_rd_addr_i,
    input      [31:0]   mem2_rd_data_i,

    // from wb
    input               wb_regs_wen_i,
    input      [4:0]    wb_rd_addr_i,
    input      [31:0]   wb_rd_data_i,

    // to id_ex
    output reg [31:0]   fwd_rs1_data_o,
    output reg [31:0]   fwd_rs2_data_o,
    output reg          fwd_rs1_hit_ex_o,
    output reg          fwd_rs2_hit_ex_o,

    // hazard
    output              hazard_en,

    //ecall, mret
    output reg [11:0]   csr_addr_o,
    output reg          ecall,
    output reg          mret,

    // to if1_if2,if2_id
    output reg          stall
);  
    // Hazard
    wire rs1_hit_ex   = (ex_rd_addr_i == rs1_i);
    wire rs2_hit_ex   = (ex_rd_addr_i == rs2_i);
    wire id_need_ex   = ex_is_load_i & (rs1_hit_ex | rs2_hit_ex);

    wire rs1_hit_mem1 = (mem1_rd_addr_i == rs1_i);
    wire rs2_hit_mem1 = (mem1_rd_addr_i == rs2_i);
    wire id_need_mem1 = mem1_is_load_i & (rs1_hit_mem1 | rs2_hit_mem1);

    assign hazard_en = id_need_ex | id_need_mem1;

    // 前推
    wire forwarding_rs1_ex   = (rs1_i == ex_rd_addr_i) && ex_regs_wen_i;
    wire forwarding_rs1_mem1 = (rs1_i == mem1_rd_addr_i) && mem1_regs_wen_i;
    wire forwarding_rs1_mem2 = (rs1_i == mem2_rd_addr_i) && mem2_regs_wen_i;
    wire forwarding_rs1_wb   = (rs1_i == wb_rd_addr_i) && wb_regs_wen_i;

    wire forwarding_rs2_ex   = (rs2_i == ex_rd_addr_i) && ex_regs_wen_i;
    wire forwarding_rs2_mem1 = (rs2_i == mem1_rd_addr_i) && mem1_regs_wen_i;
    wire forwarding_rs2_mem2 = (rs2_i == mem2_rd_addr_i) && mem2_regs_wen_i;
    wire forwarding_rs2_wb   = (rs2_i == wb_rd_addr_i) && wb_regs_wen_i;

    // 并行判断减少 MUX 级数
    wire forwarding_rs1_hit_mem = forwarding_rs1_mem1 | forwarding_rs1_mem2;
    wire [31:0] forwarding_rs1_hit_mem_data  = (forwarding_rs1_mem1) ? mem1_rd_data_i : mem2_rd_data_i;
    wire [31:0] forwarding_rs1_hit_regs_data = (forwarding_rs1_wb) ? wb_rd_data_i : rs1_data_i;

    wire forwarding_rs2_hit_mem = forwarding_rs2_mem1 | forwarding_rs2_mem2;
    wire [31:0] forwarding_rs2_hit_mem_data  = (forwarding_rs2_mem1) ? mem1_rd_data_i : mem2_rd_data_i;
    wire [31:0] forwarding_rs2_hit_regs_data = (forwarding_rs2_wb) ? wb_rd_data_i : rs2_data_i;

    // 前推结果
    wire [31:0] forwarding_rs1_data_hit = (forwarding_rs1_hit_mem) ? forwarding_rs1_hit_mem_data : forwarding_rs1_hit_regs_data;
    wire [31:0] forwarding_rs2_data_hit = (forwarding_rs2_hit_mem) ? forwarding_rs2_hit_mem_data : forwarding_rs2_hit_regs_data;

    // opcode
    (* max_fanout = 30 *) wire is_alu_i  = (opcode_i == `TYPE_I);
    (* max_fanout = 30 *) wire is_alu_r  = (opcode_i == `TYPE_R);
    (* max_fanout = 30 *) wire is_auipc  = (opcode_i == `AUIPC);
    (* max_fanout = 30 *) wire is_lui    = (opcode_i == `LUI);
    (* max_fanout = 30 *) wire is_jal    = (opcode_i == `JAL);
    (* max_fanout = 30 *) wire is_jalr   = (opcode_i == `JALR);
    (* max_fanout = 30 *) wire is_branch = (opcode_i == `TYPE_B);
    (* max_fanout = 30 *) wire is_load   = (opcode_i == `TYPE_L);
    (* max_fanout = 30 *) wire is_store  = (opcode_i == `TYPE_S);
    (* max_fanout = 30 *) wire is_zicsr  = (opcode_i == `TYPE_Zicsr);

    // f3
    (* max_fanout = 30 *) wire f3_000 = (funct3_i == 3'b000);
    (* max_fanout = 30 *) wire f3_001 = (funct3_i == 3'b001);
    (* max_fanout = 30 *) wire f3_010 = (funct3_i == 3'b010);
    (* max_fanout = 30 *) wire f3_011 = (funct3_i == 3'b011);
    (* max_fanout = 30 *) wire f3_100 = (funct3_i == 3'b100);
    (* max_fanout = 30 *) wire f3_101 = (funct3_i == 3'b101);
    (* max_fanout = 30 *) wire f3_110 = (funct3_i == 3'b110);
    (* max_fanout = 30 *) wire f3_111 = (funct3_i == 3'b111);

    // f7
    (* max_fanout = 30 *) wire f7_0000000 = (funct7_i == 7'b0000000);
    (* max_fanout = 30 *) wire f7_0100000 = (funct7_i == 7'b0100000);
    (* max_fanout = 30 *) wire f7_0000001 = (funct7_i == 7'b0000001);

    //区分ecall和mret
    (* max_fanout = 30 *) wire is_ecall = (inst_i[31:20] == 12'b000000000000);
    (* max_fanout = 30 *) wire is_mret  = (inst_i[31:20] == 12'b001100000010);

    // 打包指令
    always @(*) begin
        // opcode
        inst_packaged_o[`OP_I]      = is_alu_i;
        inst_packaged_o[`OP_R]      = is_alu_r;
        inst_packaged_o[`OP_AUIPC]  = is_auipc;
        inst_packaged_o[`OP_LUI]    = is_lui;
        inst_packaged_o[`OP_JAL]    = is_jal;
        inst_packaged_o[`OP_JALR]   = is_jalr;
        inst_packaged_o[`OP_BRANCH] = is_branch;
        inst_packaged_o[`OP_LOAD]   = is_load;
        inst_packaged_o[`OP_STORE]  = is_store;
        inst_packaged_o[`OP_ZICSR]  = is_zicsr;
        // IR-type
        inst_packaged_o[`INST_IR_ADD]  = (is_alu_r & f3_000 & f7_0000000) | (is_alu_i & f3_000);
        inst_packaged_o[`INST_R_SUB]   = is_alu_r & f3_000 & f7_0100000;
        inst_packaged_o[`INST_IR_XOR]  = (is_alu_r & f3_100 & f7_0000000) | (is_alu_i & f3_100);
        inst_packaged_o[`INST_IR_OR]   = (is_alu_r & f3_000 & f7_0000000) | (is_alu_i & f3_110);
        inst_packaged_o[`INST_IR_AND]  = (is_alu_r & f3_111 & f7_0000000) | (is_alu_i & f3_111);
        inst_packaged_o[`INST_IR_SLL]  = (is_alu_r | is_alu_i) & f3_001 & f7_0000000;
        inst_packaged_o[`INST_IR_SRL]  = (is_alu_r | is_alu_i) & f3_101 & f7_0000000;
        inst_packaged_o[`INST_IR_SRA]  = (is_alu_r | is_alu_i) & f3_101 & f7_0100000;
        inst_packaged_o[`INST_IR_SLT]  = (is_alu_r & f3_010 & f7_0000000) | (is_alu_i & f3_010);
        inst_packaged_o[`INST_IR_SLTU] = (is_alu_r & f3_011 & f7_0000000) | (is_alu_i & f3_011);

        // M-type
        inst_packaged_o[`INST_R_MUL]    = is_alu_r & f3_000 & f7_0000001;
        inst_packaged_o[`INST_R_MULH]   = is_alu_r & f3_001 & f7_0000001;
        inst_packaged_o[`INST_R_MULHSU] = is_alu_r & f3_010 & f7_0000001;
        inst_packaged_o[`INST_R_MULHU]  = is_alu_r & f3_011 & f7_0000001;
        inst_packaged_o[`INST_R_DIV]    = is_alu_r & f3_100 & f7_0000001;
        inst_packaged_o[`INST_R_DIVU]   = is_alu_r & f3_101 & f7_0000001;
        inst_packaged_o[`INST_R_REM]    = is_alu_r & f3_110 & f7_0000001;
        inst_packaged_o[`INST_R_REMU]   = is_alu_r & f3_111 & f7_0000001;

        // Load & Store
        inst_packaged_o[`INST_LB]  = is_load & f3_000;
        inst_packaged_o[`INST_LH]  = is_load & f3_001;
        inst_packaged_o[`INST_LW]  = is_load & f3_010;
        inst_packaged_o[`INST_LBU] = is_load & f3_100;
        inst_packaged_o[`INST_LHU] = is_load & f3_101;
        inst_packaged_o[`INST_SB]  = is_store & f3_000;
        inst_packaged_o[`INST_SH]  = is_store & f3_001;
        inst_packaged_o[`INST_SW]  = is_store & f3_010;

        // Branch
        inst_packaged_o[`INST_BEQ]  = is_branch & f3_000;
        inst_packaged_o[`INST_BNE]  = is_branch & f3_001;
        inst_packaged_o[`INST_BLT]  = is_branch & f3_100;
        inst_packaged_o[`INST_BGE]  = is_branch & f3_101;
        inst_packaged_o[`INST_BLTU] = is_branch & f3_110;
        inst_packaged_o[`INST_BGEU] = is_branch & f3_111;

        // CSR
        inst_packaged_o[`INST_CSRRW]  = is_zicsr & f3_001;
        inst_packaged_o[`INST_CSRRS]  = is_zicsr & f3_010;
        inst_packaged_o[`INST_CSRRC]  = is_zicsr & f3_011;
        inst_packaged_o[`INST_CSRRWI] = is_zicsr & f3_101;
        inst_packaged_o[`INST_CSRRSI] = is_zicsr & f3_110;
        inst_packaged_o[`INST_CSRRCI] = is_zicsr & f3_111;
        inst_packaged_o[`INST_ECALL]  = is_zicsr & f3_000 & is_ecall;
        inst_packaged_o[`INST_MRET]   = is_zicsr & f3_000 & is_mret;

        // 纯数值计算独热
        inst_packaged_o[`REQUEST_VALUE_ONLY] = is_auipc | is_lui | is_jal | is_jalr;
    end

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
    always@(*) begin
        pc_addr_o        = pc_addr_i;
        inst_o           = inst_i;
        pred_taken_o     = pred_taken_i;
        fwd_rs1_data_o   = forwarding_rs1_data_hit;
        fwd_rs2_data_o   = (is_alu_i) ? {{20{inst_i[31]}}, inst_i[31:20]} : forwarding_rs2_data_hit;    // 立即数时返回 imm
        fwd_rs1_hit_ex_o = forwarding_rs1_ex;
        fwd_rs2_hit_ex_o = forwarding_rs2_ex & !is_alu_i;    // 当为立即数时，不启用前推

        // CSR
        csr_addr_o       = is_zicsr ? inst_i[31:20] : 12'h520;
        ecall            = is_zicsr & is_ecall;
        mret             = is_zicsr & is_mret;

        (* parallel_case *)
        case(1'b1)
            is_lui: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_auipc: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = pc_addr_i + {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_jal: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = 32'b0;                  
                jump1_o     = 32'b0;
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_jalr: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = pred_pc_i - {{20{inst_i[31]}}, inst_i[31:20]};     // 提前计算 rs1 == pred_pc - imm
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_branch: begin
                reg_wen     = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = pc_addr_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                jump2_o     = pc_add_4;
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = rs2_i;
                rd_addr_o   = 5'b0;
            end

            is_load: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_store: begin
                reg_wen     = 1'b0;
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = rs2_i;
                rd_addr_o   = 5'b0;
            end

            is_alu_i: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_i;
            end

            is_alu_r: begin
                reg_wen     = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = rs1_i;
                rs2_addr_o  = rs2_i;
                rd_addr_o   = rd_i;
                stall       = f7_0000001;
            end

            is_zicsr: begin
                case(funct3_i)
                    `CSRRW,`CSRRS,`CSRRC: begin
                        reg_wen     = (rd_i != 5'b0);
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rs1_addr_o  = rs1_i;
                        rs2_addr_o  = 5'b0;
                        rd_addr_o   = rd_i;
                    end
                    `CSRRWI,`CSRRSI,`CSRRCI: begin
                        reg_wen     = (rd_i != 5'b0);
                        value1_o    = inst_i[19:15]; // zicsr立即数在rs1地址位
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rs1_addr_o  = rs1_i;
                        rs2_addr_o  = 5'b0;
                        rd_addr_o   = rd_i;
                    end
                    `ECALL_MRET: begin
                        reg_wen     = 1'b0; // ecall和mret不写寄存器
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        rd_addr_o   = 5'b0;
                    end
                    default: begin
                        reg_wen     = 1'b0;
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rs1_addr_o  = 5'b0;
                        rs2_addr_o  = 5'b0;
                        rd_addr_o   = 5'b0;
                    end
                endcase
            end

            default: begin
                reg_wen     = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = 5'b0;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule                       