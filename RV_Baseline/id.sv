`include "rv32I.vh"
`include "alu.vh"

module id(
    // from if_id
    input  if_id_t      data_packaged_i,

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
    input      [4:0]    ex_rd_addr_i,
    input               ex_regs_wen_i,
    input               ex_is_load_i,

    // from mem1
    input      [4:0]    mem1_rd_addr_i,
    input      [31:0]   mem1_rd_data_i,
    input               mem1_regs_wen_i,
    input               mem1_is_load_i,

    // from mem2
    input      [4:0]    mem2_rd_addr_i,
    input      [31:0]   mem2_rd_data_i,
    input               mem2_regs_wen_i,

    // from wb
    input      [4:0]    wb_rd_addr_i,
    input      [31:0]   wb_rd_data_i,
    input               wb_regs_wen_i,

    // hazard
    output              hazard_en
);  
    // 解码
    wire [31:0] pc_i     = data_packaged_i.pc;
    wire [31:0] inst_i   = data_packaged_i.inst;
    wire [6:0]  opcode_i = data_packaged_i.opcode;
    wire [2:0]  funct3_i = data_packaged_i.funct3;
    wire [6:0]  funct7_i = data_packaged_i.funct7;
    wire [4:0]  rd_i     = data_packaged_i.rd;
    wire [4:0]  rs1_i    = data_packaged_i.rs1;
    wire [4:0]  rs2_i    = data_packaged_i.rs2;

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

    decode_t ipkg;
    assign ipkg = d(inst_i, opcode_i, funct3_i, funct7_i);
    assign inst_packaged_o = ipkg;

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
            logic is_Aext    = (opcode == `TYPE_AMO);

            logic [4:0] funct5 = inst[31:27];

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
            d.sel_add  = (is_alu_r & f7_0000000 | is_alu_i) & f3_000;
            d.sel_sub  = is_alu_r & f3_000 & f7_0100000;
            d.sel_xor  = (is_alu_r & f7_0000000 | is_alu_i) & f3_100;
            d.sel_or   = (is_alu_r & f7_0000000 | is_alu_i) & f3_110;
            d.sel_and  = (is_alu_r & f7_0000000 | is_alu_i) & f3_111;
            d.sel_sll  = (is_alu_r | is_alu_i) & f3_001 & f7_0000000;
            d.sel_srl  = (is_alu_r | is_alu_i) & f3_101 & f7_0000000;
            d.sel_sra  = (is_alu_r | is_alu_i) & f3_101 & f7_0100000;
            d.sel_slt  = (is_alu_r & f7_0000000 | is_alu_i) & f3_010;
            d.sel_sltu = (is_alu_r & f7_0000000 | is_alu_i) & f3_011;
            
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

            // fence
            // d.sel_fence = ;

            // 纯数值输出
            d.request_value_only = is_auipc | is_lui | is_jal | is_jalr;
            
            d.is_rv32i  = d.sel_add | d.sel_sub  | d.sel_xor | d.sel_or
                        | d.sel_and | d.sel_sll  | d.sel_srl | d.sel_sra
                        | d.sel_slt | d.sel_sltu | is_load   | is_store
                        | is_branch | d.request_value_only;
            
            // ZICSR
            d.sel_csrrw   = is_zicsr & f3_001;
            d.sel_csrrs   = is_zicsr & f3_010;
            d.sel_csrrc   = is_zicsr & f3_011;
            d.sel_csrrwi  = is_zicsr & f3_101;
            d.sel_csrrsi  = is_zicsr & f3_110;
            d.sel_csrrci  = is_zicsr & f3_111;
            d.sel_ecall   = is_zicsr & f3_000 & is_ecall;
            d.sel_mret    = is_zicsr & f3_000 & is_mret;
            
            // M-ext
            `ifdef ENABLE_M
            d.is_Mext    = is_alu_r & (funct7 == 7'b0000001);
            d.sel_mul    = d.is_Mext & f3_000;
            d.sel_mulh   = d.is_Mext & f3_001;
            d.sel_mulhsu = d.is_Mext & f3_010;
            d.sel_mulhu  = d.is_Mext & f3_011;
            d.sel_div    = d.is_Mext & f3_100;
            d.sel_divu   = d.is_Mext & f3_101;
            d.sel_rem    = d.is_Mext & f3_110;
            d.sel_remu   = d.is_Mext & f3_111;
            `endif

            // B-ext
            `ifdef ENABLE_B

            // Zba
            `ifdef ENABLE_B_ZBA
            d.sel_sh1add = is_alu_r & f3_010 & (funct7 == 7'b0010000);
            d.sel_sh2add = is_alu_r & f3_100 & (funct7 == 7'b0010000);
            d.sel_sh3add = is_alu_r & f3_110 & (funct7 == 7'b0010000);
            d.is_Bext_zba = d.sel_sh1add | d.sel_sh2add | d.sel_sh3add;
            `endif

            // Zbb
            `ifdef ENABLE_B_ZBB
            d.sel_andn   = is_alu_r & f3_111 & (funct7 == 7'b0100000);
            d.sel_orn    = is_alu_r & f3_110 & (funct7 == 7'b0100000);
            d.sel_xnor   = is_alu_r & f3_100 & (funct7 == 7'b0100000);
            d.sel_clz    = is_alu_i & f3_001 & (inst[31:20] == 11'b011000000000);
            d.sel_ctz    = is_alu_i & f3_001 & (inst[31:20] == 11'b011000000001);
            d.sel_cpop   = is_alu_i & f3_001 & (inst[31:20] == 11'b011000000010);
            d.sel_max    = is_alu_r & f3_110 & (funct7 == 7'b0000101);
            d.sel_maxu   = is_alu_r & f3_111 & (funct7 == 7'b0000101);
            d.sel_min    = is_alu_r & f3_100 & (funct7 == 7'b0000101);
            d.sel_minu   = is_alu_r & f3_101 & (funct7 == 7'b0000101);
            d.sel_sext_b = is_alu_i & f3_001 & (inst[31:20] == 11'b011000000100);
            d.sel_sext_h = is_alu_i & f3_001 & (inst[31:20] == 11'b011000000101);
            d.sel_zext_h = is_alu_r & f3_100 & (inst[31:20] == 11'b000010000000);
            d.sel_rol    = is_alu_r & f3_001 & (funct7 == 7'b0110000);
            d.sel_ror    = (is_alu_r | is_alu_i) & f3_101 & (funct7 == 7'b0110000);
            d.sel_orc_b  = is_alu_i & f3_101 & (inst[31:20] == 11'b001010000111);
            d.sel_rev8   = is_alu_i & f3_101 & (inst[31:20] == 11'b011010011000);
            d.is_Bext_zbb   = d.sel_andn  | d.sel_orn  | d.sel_xnor  | d.sel_clz
                            | d.sel_ctz   | d.sel_cpop | d.sel_max   | d.sel_maxu
                            | d.sel_min   | d.sel_minu | d.sel_sext_b| d.sel_sext_h
                            | d.sel_zext_h| d.sel_rol  | d.sel_ror   | d.sel_orc_b
                            | d.sel_rev8;
            `endif
            
            // Zbc
            `ifdef ENABLE_B_ZBC
            d.sel_clmul  = is_alu_r & f3_001 & (funct7 == 7'b0000101);
            d.sel_clmulh = is_alu_r & f3_011 & (funct7 == 7'b0000101);
            d.sel_clmulr = is_alu_r & f3_010 & (funct7 == 7'b0000101);
            d.is_Bext_zbc = d.sel_clmul | d.sel_clmulh| d.sel_clmulr;
            `endif
            
            // Zbs
            `ifdef ENABLE_B_ZBS
            d.sel_bclr   = (is_alu_r | is_alu_i) & f3_001 & (funct7 == 7'b0100100);
            d.sel_bext   = (is_alu_r | is_alu_i) & f3_101 & (funct7 == 7'b0100100);
            d.sel_binv   = (is_alu_r | is_alu_i) & f3_001 & (funct7 == 7'b0110100);
            d.sel_bset   = (is_alu_r | is_alu_i) & f3_001 & (funct7 == 7'b0010100);
            d.is_Bext_zbs = d.sel_bclr | d.sel_bext | d.sel_binv | d.sel_bset;
            `endif

            // Zbkb
            `ifdef ENABLE_B_ZBKB
            d.sel_pack   = is_alu_r & f3_100 & (funct7 == 7'b0000100);
            d.sel_packh  = is_alu_r & f3_111 & (funct7 == 7'b0000100);
            d.sel_brev8  = is_alu_i & f3_101 & (inst[31:20] == 11'b011010000111);
            d.sel_zip    = is_alu_i & f3_001 & (inst[31:20] == 11'b000010001111);
            d.sel_unzip  = is_alu_i & f3_101 & (inst[31:20] == 11'b000010001111);
            d.is_Bext_zbkb = d.sel_pack | d.sel_packh | d.sel_brev8 | d.sel_zip | d.sel_unzip;
            `endif

            // Zbkx
            `ifdef ENABLE_B_ZBKX
            d.sel_xperm4 = is_alu_r & f3_010 & (funct7 == 7'b0010100);
            d.sel_xperm8 = is_alu_r & f3_100 & (funct7 == 7'b0010100);
            d.is_Bext_zbkx = d.sel_xperm4 | d.sel_xperm8;
            `endif
            `endif

            // Zicond-ext
            `ifdef ENABLE_Zicond
            d.is_Zicondext  = is_alu_r & (f3_101 | f3_111) & (funct7 == 7'b0000111);
            d.sel_czero_eqz = is_alu_r & f3_101 & (funct7 == 7'b0000111);
            d.sel_czero_nez = is_alu_r & f3_111 & (funct7 == 7'b0000111);
            `endif

            // F-ext
            `ifdef ENABLE_F
            d.sel_fadd_s;
            d.sel_fclass_s;
            d.sel_fcvt_s_w;
            d.sel_fcvt_s_wu;
            d.sel_fcvt_wu_s;
            d.sel_fdiv_s;
            d.sel_feq_s;
            d.sel_fle_s;
            d.sel_flt_s;
            d.sel_flw;
            d.sel_fmadd_s;
            d.sel_fmax_s;
            d.sel_fmin_s;
            d.sel_fmsub_s;
            d.sel_fmul_s;
            d.sel_fmv_w_x;
            d.sel_fmv_x_w;
            d.sel_fnmadd_s;
            d.sel_fnmsub_s;
            d.sel_fsgnj_s;
            d.sel_fsgnjn_s;
            d.sel_fsgnjx_s;
            d.sel_fsqrt_s;
            d.sel_fsub_s;
            d.sel_fsw;
            d.is_Fext;
            `endif
            
            // A-ext
            `ifdef ENABLE_A
            d.is_Aext = is_Aext & f3_010;
            d.sel_lr_w      = is_Aext & (funct5 == 5'b00010);
            d.sel_sc_w      = is_Aext & (funct5 == 5'b00011);
            d.sel_amoswap_w = is_Aext & (funct5 == 5'b00001);
            d.sel_amoadd_w  = is_Aext & (funct5 == 5'b00000);
            d.sel_amoand_w  = is_Aext & (funct5 == 5'b01100);
            d.sel_amoor_w   = is_Aext & (funct5 == 5'b01000);
            d.sel_amoxor_w  = is_Aext & (funct5 == 5'b00100);
            d.sel_amomax_w  = is_Aext & (funct5 == 5'b10100);
            d.sel_amomaxu_w = is_Aext & (funct5 == 5'b11100);
            d.sel_amomin_w  = is_Aext & (funct5 == 5'b10000);
            d.sel_amominu_w = is_Aext & (funct5 == 5'b11000);
            `endif

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
    wire [31:0] pc_add_4     = pc_i + 32'd4;
    wire [31:0] pc_addr_o    = pc_i;
    wire [31:0] inst_o       = inst_i;
    wire        pred_taken_o = pred_taken_i;

    // 指令信息
    assign data_packaged_o.pc           = pc_addr_o;
    assign data_packaged_o.inst         = inst_o;
    assign data_packaged_o.pred_taken   = pred_taken_o;
    assign data_packaged_o.ras_ptr      = ras_ptr_i;

    // 前推
    assign data_packaged_o.fwd_rs1_data = forwarding_rs1_data_hit;
    assign data_packaged_o.fwd_rs2_data = (ipkg.is_alu_i) ? {{20{inst_i[31]}}, inst_i[31:20]} : forwarding_rs2_data_hit;    // 立即数时返回 imm
    assign data_packaged_o.fwd_rs1_hit_ex = forwarding_rs1_ex;
    assign data_packaged_o.fwd_rs2_hit_ex = forwarding_rs2_ex & !ipkg.is_alu_i;  // 当为立即数时，不启用前推
    
    // CSR
    assign data_packaged_o.csr_addr  = ipkg.is_zicsr ? inst_i[31:20] : 12'h520;
    assign data_packaged_o.ecall     = ipkg.sel_ecall;
    assign data_packaged_o.mret      = ipkg.sel_mret;

    // 数据
    logic [31:0] value1_o, value2_o, jump1_o, jump2_o, rd_addr_o;
    assign data_packaged_o.value1  = value1_o;
    assign data_packaged_o.value2  = value2_o;
    assign data_packaged_o.jump1   = jump1_o;
    assign data_packaged_o.jump2   = jump2_o;
    assign data_packaged_o.rd_addr = rd_addr_o;
    
    always_comb begin
        unique case(1'b1)
            ipkg.is_lui: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_auipc: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_i + {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_jal: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = 32'b0;                  
                jump1_o     = 32'b0;
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rd_addr_o   = rd_i;
            end

            ipkg.is_jalr: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = pc_add_4;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = pred_pc_i - {{20{inst_i[31]}}, inst_i[31:20]};     // 提前计算 rs1 == pred_pc - imm
                rd_addr_o   = rd_i;
            end

            ipkg.is_branch: begin
                regs_wen_o  = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = pc_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                jump2_o     = pc_add_4;
                rd_addr_o   = 5'b0;
            end

            ipkg.is_load: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_store: begin
                regs_wen_o  = 1'b0;
                value1_o    = 32'b0;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end

            ipkg.is_alu_i: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_alu_r: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_zicsr: begin
                unique case(1'b1)
                    ipkg.sel_csrrw, ipkg.sel_csrrs, ipkg.sel_csrrc: begin
                        regs_wen_o  = (rd_i != 5'b0);
                        value1_o    = 32'b0;
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    ipkg.sel_csrrwi, ipkg.sel_csrrsi, ipkg.sel_csrrci: begin
                        regs_wen_o  = (rd_i != 5'b0);
                        value1_o    = inst_i[19:15]; // zicsr立即数在rs1地址位
                        value2_o    = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    ipkg.sel_ecall, ipkg.sel_mret: begin
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

            ipkg.is_Aext: begin
                regs_wen_o  = (rd_i != 5'b0);
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
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