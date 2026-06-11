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
    input      [3:0]    ras_ptr_i,
    // from regs
    input      [31:0]   rs1_data_i,         // 从寄存器堆读出的寄存rs1的数据
    input      [31:0]   rs2_data_i,         // 从寄存器堆读出的寄存rs2的数据

    // to id_ex
    output id_ex_data_t data_packaged_o,
    output decode_t     inst_packaged_o,
    output logic        regs_wen_o,

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

    // hazard
    output              hazard_en
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

    assign inst_packaged_o = d(inst_i, opcode_i, funct3_i, funct7_i);

    // 打包指令
    function automatic decode_t d;
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
            logic f7_0000001 = (funct7 == 7'b0000001);

            // opcode
            d.is_alu_i   = is_alu_i;
            d.is_alu_r   = is_alu_r;
            d.is_auipc   = is_auipc;
            d.is_lui     = is_lui;
            d.is_jal     = is_jal;
            d.is_jalr    = is_jalr;
            d.is_branch  = is_branch;
            d.is_load    = is_load;
            d.is_store   = is_store;
            d.is_zicsr   = is_zicsr;

            // IR-type
            d.sel_add  = (is_alu_r & f3_000 & f7_0000000) | (is_alu_i & f3_000);
            d.sel_sub  = is_alu_r & f3_000 & f7_0100000;
            d.sel_xor  = (is_alu_r & f7_0000000 | is_alu_i) & f3_100;
            d.sel_or   = (is_alu_r & f7_0000000 | is_alu_i) & f3_110;
            d.sel_and  = (is_alu_r & f7_0000000 | is_alu_i) & f3_111;
            d.sel_sll  = (is_alu_r | is_alu_i) & f3_001 & f7_0000000;
            d.sel_srl  = (is_alu_r | is_alu_i) & f3_101 & f7_0000000;
            d.sel_sra  = (is_alu_r | is_alu_i) & f3_101 & f7_0100000;
            d.sel_slt  = (is_alu_r & f7_0000000 | is_alu_i) & f3_010;
            d.sel_sltu = (is_alu_r & f7_0000000 | is_alu_i) & f3_011;

            // M-type
            d.sel_Mext_using_mul    = is_alu_r & (f3_000 | f3_001 | f3_010 | f3_011) & f7_0000001;
            d.sel_Mext_using_divider = is_alu_r & (f3_100 | f3_101 | f3_110 | f3_111) & f7_0000001;
            d.sel_mul    = is_alu_r & f3_000 & f7_0000001;
            d.sel_mulh   = is_alu_r & f3_001 & f7_0000001;
            d.sel_mulhsu = is_alu_r & f3_010 & f7_0000001;
            d.sel_mulhu  = is_alu_r & f3_011 & f7_0000001;
            d.sel_div    = is_alu_r & f3_100 & f7_0000001;
            d.sel_divu   = is_alu_r & f3_101 & f7_0000001;
            d.sel_rem    = is_alu_r & f3_110 & f7_0000001;
            d.sel_remu   = is_alu_r & f3_111 & f7_0000001;

            // Load & Store
            d.sel_lb   = is_load & f3_000;
            d.sel_lh   = is_load & f3_001;
            d.sel_lw   = is_load & f3_010;
            d.sel_lbu  = is_load & f3_100;
            d.sel_lhu  = is_load & f3_101;
            d.sel_sb   = is_store & f3_000;
            d.sel_sh   = is_store & f3_001;
            d.sel_sw   = is_store & f3_010;

            // Branch
            d.sel_beq   = is_branch & f3_000;
            d.sel_bne   = is_branch & f3_001;
            d.sel_blt   = is_branch & f3_100;
            d.sel_bge   = is_branch & f3_101;
            d.sel_bltu  = is_branch & f3_110;
            d.sel_bgeu  = is_branch & f3_111;

            // CSR
            d.sel_csrrw   = is_zicsr & f3_001;
            d.sel_csrrs   = is_zicsr & f3_010;
            d.sel_csrrc   = is_zicsr & f3_011;
            d.sel_csrrwi  = is_zicsr & f3_101;
            d.sel_csrrsi  = is_zicsr & f3_110;
            d.sel_csrrci  = is_zicsr & f3_111;
            d.sel_ecall   = is_zicsr & f3_000 & is_ecall;
            d.sel_mret    = is_zicsr & f3_000 & is_mret;

            // 纯数值计算独热
            d.request_value_only = is_auipc | is_lui | is_jal | is_jalr;
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
    wire [31:0] pc_add_4     = pc_addr_i + 32'd4;
    wire [31:0] pc_addr_o    = pc_addr_i;
    wire [31:0] inst_o       = inst_i;
    wire        pred_taken_o = pred_taken_i;

    // 指令信息
    assign data_packaged_o.pc           = pc_addr_o;
    assign data_packaged_o.inst         = inst_o;
    assign data_packaged_o.pred_taken   = pred_taken_o;
    assign data_packaged_o.ras_ptr      = ras_ptr_i;

    // 前推
    assign data_packaged_o.fwd_rs1_data = forwarding_rs1_data_hit;
    assign data_packaged_o.fwd_rs2_data = (inst_packaged_o.is_alu_i) ? {{20{inst_i[31]}}, inst_i[31:20]} : forwarding_rs2_data_hit;    // 立即数时返回 imm
    assign data_packaged_o.fwd_rs1_hit_ex = forwarding_rs1_ex;
    assign data_packaged_o.fwd_rs2_hit_ex = forwarding_rs2_ex & !inst_packaged_o.is_alu_i;  // 当为立即数时，不启用前推
    
    // CSR
    assign data_packaged_o.csr_addr  = inst_packaged_o.is_zicsr ? inst_i[31:20] : 12'h520;
    assign data_packaged_o.ecall     = inst_packaged_o.sel_ecall;
    assign data_packaged_o.mret      = inst_packaged_o.sel_mret;

    // 数据
    logic [31:0] value1_o, value2_o, jump1_o, jump2_o, rd_addr_o;
    assign data_packaged_o.value1  = value1_o;
    assign data_packaged_o.value2  = value2_o;
    assign data_packaged_o.jump1   = jump1_o;
    assign data_packaged_o.jump2   = jump2_o;
    assign data_packaged_o.rd_addr = rd_addr_o;
    
    always_comb begin
        unique case(1'b1)
            inst_packaged_o.is_lui: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_auipc: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_addr_i + {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_jal: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = 32'b0;                  
                jump1_o     = 32'b0;
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_jalr: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = pred_pc_i - {{20{inst_i[31]}}, inst_i[31:20]};     // 提前计算 rs1 == pred_pc - imm
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_branch: begin
                regs_wen_o  = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = pc_addr_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                jump2_o     = pc_add_4;
                rd_addr_o   = 5'b0;
            end

            inst_packaged_o.is_load: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_store: begin
                regs_wen_o  = 1'b0;
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end

            inst_packaged_o.is_alu_i: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_alu_r: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            inst_packaged_o.is_zicsr: begin
                case(funct3_i)
                    `CSRRW,`CSRRS,`CSRRC: begin
                        regs_wen_o  = (rd_i != 5'b0);
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    `CSRRWI,`CSRRSI,`CSRRCI: begin
                        regs_wen_o  = (rd_i != 5'b0);
                        value1_o    = inst_i[19:15]; // zicsr立即数在rs1地址位
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    `ECALL_MRET: begin
                        regs_wen_o  = 1'b0; // ecall和mret不写寄存器
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = 5'b0;
                    end
                    default: begin
                        regs_wen_o  = 1'b0;
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = 5'b0;
                    end
                endcase
            end

            default: begin
                regs_wen_o  = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule                       