`include "rv32I.svh"
`include "alu_def.svh"

module id(
    // from Frontend
    input  prefetch_t                   data_pkg_i          ,
    input  logic                        valid_i             ,

    // to RF
    output logic [`RF_IDX_WIDTH - 1:0]  rs1_addr_o          ,
    output logic [`RF_IDX_WIDTH - 1:0]  rs2_addr_o          ,
    output logic [11:0]                 csr_addr_o          ,

    // from RF
    input  logic [31:0]                 rs1_rdata_i         ,
    input  logic [31:0]                 rs2_rdata_i         ,
    input  logic [31:0]                 csr_rdata_i         ,

    `ifdef ENABLE_F
    output logic [`RF_IDX_WIDTH - 1:0]  rs3_addr_o          ,
    input  logic [31:0]                 rs3_rdata_i         ,
    `endif

    // to EX
    output EX_data_t                    data_pkg_o          ,
    output decode_t                     inst_pkg_o          ,
    output logic                        regs_wen_o          ,
    output logic                        valid_o             ,

    // from EX
    input  RF_data_t                    EX_RF_data_pkg_i    ,
    input  logic                        EX_is_load_i        ,
    input  logic                        EX_CSR_wen_i        ,

    // from MEM1
    input  RF_data_t                    MEM1_RF_data_pkg_i  ,
    input  logic                        MEM1_is_load_i      ,
    input  logic                        MEM1_CSR_wen_i      ,

    // from MEM2
    input  RF_data_t                    MEM2_RF_data_pkg_i  ,
    input  logic                        MEM2_CSR_wen_i      ,

    // from WB
    input  RF_data_t                    WB_RF_data_pkg_i    ,
    input  logic                        WB_CSR_wen_i        ,
    
    // hazard
    output logic                        hazard_en           
);  
    assign valid_o = valid_i;

    // 解码
    wire [31:0] pc_i     = data_pkg_i.pc;
    wire [31:0] inst_i   = data_pkg_i.inst;
    wire [6:0]  opcode_i = inst_i[6:0];
    wire [4:0]  rd_i     = inst_i[11:7];
    wire [2:0]  funct3_i = inst_i[14:12];
    wire [4:0]  rs1_i    = inst_i[19:15];
    wire [4:0]  rs2_i    = inst_i[24:20];
    wire [6:0]  funct7_i = inst_i[31:25];

    decode_t ipkg;
    assign ipkg = d(inst_i, opcode_i, funct3_i, rs2_i, funct7_i);
    assign inst_pkg_o = ipkg;

    // F 扩展的寄存器扩展
    `ifdef ENABLE_F
    wire using_frs1   = (ipkg.is_FP & ~(ipkg.sel_fmv_w_x | ipkg.sel_fcvt_s_w | ipkg.sel_fcvt_s_wu)) | ipkg.is_FM;
    wire using_frs2   = ipkg.is_load_FP | ipkg.is_store_FP | ipkg.is_FP | ipkg.is_FM;
    wire using_frd    = ipkg.is_load_FP | ipkg.is_store_FP
                        | (ipkg.sel_fmv_w_x | ipkg.sel_fadd_s | ipkg.sel_fsub_s | ipkg.sel_fmin_s
                        | ipkg.sel_fmax_s | ipkg.sel_fsgnj_s | ipkg.sel_fsgnjn_s | ipkg.sel_fsgnjx_s
                        | ipkg.sel_fcvt_s_w | ipkg.sel_fcvt_s_wu | ipkg.sel_fmul_s | ipkg.sel_fdiv_s
                        | ipkg.sel_fsqrt_s | ipkg.is_FM);
    
    wire [5:0] rs1_addr_with_F = {using_frs1, rs1_i};
    wire [5:0] rs2_addr_with_F = {using_frs2, rs2_i};
    wire [5:0] rd_addr_with_F  = {using_frd, rd_addr_o};
    wire [5:0] rs3_addr_with_F = (ipkg.is_FM) ? {1'b1, inst_i[31:27]} : 0;
    `else
    wire using_frd = 0;
    `endif
    
    // Hazard
    wire rs1_hit_EX   = (EX_RF_data_pkg_i.rd_addr == rs1_addr_o);
    wire rs2_hit_EX   = (EX_RF_data_pkg_i.rd_addr == rs2_addr_o);
    wire ID_need_EX   = EX_is_load_i & (rs1_hit_EX | rs2_hit_EX);

    wire rs1_hit_MEM1 = (MEM1_RF_data_pkg_i.rd_addr == rs1_addr_o);
    wire rs2_hit_MEM1 = (MEM1_RF_data_pkg_i.rd_addr == rs2_addr_o);
    wire ID_need_MEM1 = MEM1_is_load_i & (rs1_hit_MEM1 | rs2_hit_MEM1);

    logic is_FP;
    `ifdef ENABLE_F
    assign is_FP = ipkg.is_FP;
    `else
    assign is_FP = 1'b0;
    `endif
    wire CSR_hazard = (ipkg.is_zicsr | is_FP) & (EX_CSR_wen_i | MEM1_CSR_wen_i | MEM2_CSR_wen_i | WB_CSR_wen_i);

    logic rs3_hazard;
    `ifdef ENABLE_F
    wire hazard_rs3_ex   = (rs3_addr_o == EX_RF_data_pkg_i.rd_addr) & EX_RF_data_pkg_i.regs_wen;
    wire hazard_rs3_mem1 = (rs3_addr_o == MEM1_RF_data_pkg_i.rd_addr) & MEM1_RF_data_pkg_i.regs_wen;
    wire hazard_rs3_mem2 = (rs3_addr_o == MEM2_RF_data_pkg_i.rd_addr) & MEM2_RF_data_pkg_i.regs_wen;
    wire hazard_rs3_wb   = (rs3_addr_o == WB_RF_data_pkg_i.rd_addr) & WB_RF_data_pkg_i.regs_wen;
    assign rs3_hazard = ipkg.is_FM & (hazard_rs3_ex | hazard_rs3_mem1 | hazard_rs3_mem2 | hazard_rs3_wb);
    `else
    assign rs3_hazard = 0;
    `endif

    assign hazard_en = ID_need_EX | ID_need_MEM1 | CSR_hazard | rs3_hazard;

    // 前推
    wire forwarding_rs1_ex   = (rs1_addr_o == EX_RF_data_pkg_i.rd_addr) & EX_RF_data_pkg_i.regs_wen;
    wire forwarding_rs1_mem1 = (rs1_addr_o == MEM1_RF_data_pkg_i.rd_addr) & MEM1_RF_data_pkg_i.regs_wen;
    wire forwarding_rs1_mem2 = (rs1_addr_o == MEM2_RF_data_pkg_i.rd_addr) & MEM2_RF_data_pkg_i.regs_wen;
    wire forwarding_rs1_wb   = (rs1_addr_o == WB_RF_data_pkg_i.rd_addr) & WB_RF_data_pkg_i.regs_wen;

    wire forwarding_rs2_ex   = (rs2_addr_o == EX_RF_data_pkg_i.rd_addr) & EX_RF_data_pkg_i.regs_wen;
    wire forwarding_rs2_mem1 = (rs2_addr_o == MEM1_RF_data_pkg_i.rd_addr) & MEM1_RF_data_pkg_i.regs_wen;
    wire forwarding_rs2_mem2 = (rs2_addr_o == MEM2_RF_data_pkg_i.rd_addr) & MEM2_RF_data_pkg_i.regs_wen;
    wire forwarding_rs2_wb   = (rs2_addr_o == WB_RF_data_pkg_i.rd_addr) & WB_RF_data_pkg_i.regs_wen;

    // 并行判断减少 MUX 级数
    wire        forwarding_rs1_hit_mem       = forwarding_rs1_mem1 | forwarding_rs1_mem2;
    wire [31:0] forwarding_rs1_hit_mem_data  = (forwarding_rs1_mem1) ? MEM1_RF_data_pkg_i.rd_data : MEM2_RF_data_pkg_i.rd_data;
    wire [31:0] forwarding_rs1_hit_regs_data = (forwarding_rs1_wb) ? WB_RF_data_pkg_i.rd_data : rs1_rdata_i;

    wire        forwarding_rs2_hit_mem       = forwarding_rs2_mem1 | forwarding_rs2_mem2;
    wire [31:0] forwarding_rs2_hit_mem_data  = (forwarding_rs2_mem1) ? MEM1_RF_data_pkg_i.rd_data : MEM2_RF_data_pkg_i.rd_data;
    wire [31:0] forwarding_rs2_hit_regs_data = (forwarding_rs2_wb) ? WB_RF_data_pkg_i.rd_data : rs2_rdata_i;

    // 前推结果
    wire [31:0] forwarding_rs1_data_hit = (forwarding_rs1_hit_mem) ? forwarding_rs1_hit_mem_data : forwarding_rs1_hit_regs_data;
    wire [31:0] forwarding_rs2_data_hit = (forwarding_rs2_hit_mem) ? forwarding_rs2_hit_mem_data : forwarding_rs2_hit_regs_data;

    // 打包指令
    function automatic decode_t d(
        input [31:0] inst,
        input [6:0] opcode,
        input [2:0] funct3,
        input [4:0] rs2,
        input [6:0] funct7
    );   
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
        `ifdef ENABLE_A
        logic OP_AMO     = (opcode == `TYPE_AMO);
        `endif
        `ifdef ENABLE_F
        logic OP_FP      = (opcode == `TYPE_FP);
        logic LOAD_FP    = (opcode == `TYPE_LOAD_FP);
        logic STORE_FP   = (opcode == `TYPE_STORE_FP);
        `endif

        `ifdef ENABLE_A
        logic [4:0] funct5 = inst[31:27];
        `endif

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

        // rst to zero
        d = 0; 

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
        d.sel_ecall   = is_zicsr & f3_000 & (inst[31:20] == 12'b000000000000);
        d.sel_mret    = is_zicsr & f3_000 & (inst[31:20] == 12'b001100000010);
        d.sel_sret    = 1'b0;
        
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
        d.is_FP         = OP_FP;
        d.is_load_FP    = LOAD_FP;
        d.is_store_FP   = STORE_FP;
        d.sel_fadd_s    = OP_FP & f7_0000000;
        d.sel_fclass_s  = OP_FP & f3_001 & (funct7 == 7'b1110000);
        d.sel_fcvt_s_w  = OP_FP & (rs2 == 5'b00000) & (funct7 == 7'b1101000);
        d.sel_fcvt_s_wu = OP_FP & (rs2 == 5'b00001) & (funct7 == 7'b1101000);
        d.sel_fcvt_w_s  = OP_FP & (rs2 == 5'b00000) & (funct7 == 7'b1100000);
        d.sel_fcvt_wu_s = OP_FP & (rs2 == 5'b00001) & (funct7 == 7'b1100000);
        d.sel_fdiv_s    = OP_FP & (funct7 == 7'b0001100);
        d.sel_feq_s     = OP_FP & f3_010 & (funct7 == 7'b1010000);
        d.sel_fle_s     = OP_FP & f3_000 & (funct7 == 7'b1010000);
        d.sel_flt_s     = OP_FP & f3_001 & (funct7 == 7'b1010000);
        d.sel_flw       = LOAD_FP & f3_010;
        d.sel_fmax_s    = OP_FP & f3_001 & (funct7 == 7'b0010100);
        d.sel_fmin_s    = OP_FP & f3_000 & (funct7 == 7'b0010100);
        d.sel_fmul_s    = OP_FP & (funct7 == 7'b0001000);
        d.sel_fmv_w_x   = OP_FP & f3_000 & (rs2 == 5'b00000) & (funct7 == 7'b1111000);
        d.sel_fmv_x_w   = OP_FP & f3_000 & (rs2 == 5'b00000) & (funct7 == 7'b1110000);
        d.sel_fsgnj_s   = OP_FP & f3_000 & (funct7 == 7'b0010000);
        d.sel_fsgnjn_s  = OP_FP & f3_001 & (funct7 == 7'b0010000);
        d.sel_fsgnjx_s  = OP_FP & f3_010 & (funct7 == 7'b0010000);
        d.sel_fsqrt_s   = OP_FP & (rs2 == 5'b00000) & (funct7 == 7'b0101100);
        d.sel_fsub_s    = OP_FP & (funct7 == 7'b0000100);
        d.sel_fsw       = STORE_FP & f3_010;
        d.sel_fmadd_s   = (opcode == `OP_FMADD);
        d.sel_fmsub_s   = (opcode == `OP_FMSUB);
        d.sel_fnmadd_s  = (opcode == `OP_FNMADD);
        d.sel_fnmsub_s  = (opcode == `OP_FNMSUB);
        d.is_FM         = d.sel_fmadd_s | d.sel_fmsub_s | d.sel_fnmadd_s | d.sel_fnmsub_s;
        `endif
        
        // A-ext
        `ifdef ENABLE_A
        d.is_Aext = OP_AMO & f3_010;
        d.sel_lr_w      = OP_AMO & (funct5 == 5'b00010);
        d.sel_sc_w      = OP_AMO & (funct5 == 5'b00011);
        d.sel_amoswap_w = OP_AMO & (funct5 == 5'b00001);
        d.sel_amoadd_w  = OP_AMO & (funct5 == 5'b00000);
        d.sel_amoand_w  = OP_AMO & (funct5 == 5'b01100);
        d.sel_amoor_w   = OP_AMO & (funct5 == 5'b01000);
        d.sel_amoxor_w  = OP_AMO & (funct5 == 5'b00100);
        d.sel_amomax_w  = OP_AMO & (funct5 == 5'b10100);
        d.sel_amomaxu_w = OP_AMO & (funct5 == 5'b11100);
        d.sel_amomin_w  = OP_AMO & (funct5 == 5'b10000);
        d.sel_amominu_w = OP_AMO & (funct5 == 5'b11000);
        `endif

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
    `ifdef ENABLE_F
    assign rs1_addr_o = rs1_addr_with_F;
    assign rs2_addr_o = rs2_addr_with_F;
    assign rs3_addr_o = rs3_addr_with_F;
    `else
    assign rs1_addr_o = rs1_i;
    assign rs2_addr_o = rs2_i;
    `endif

    wire [31:0] pc_next = data_pkg_i.pc_next;
    wire [31:0] pc_o    = pc_i;
    wire [31:0] inst_o  = inst_i;

    // 指令信息
    assign data_pkg_o.pc                    = pc_i;
    assign data_pkg_o.inst                  = inst_i;
    assign data_pkg_o.pred_taken            = data_pkg_i.pred_flush.en;
    assign data_pkg_o.is_ret                = inst_i == `RET;
    assign data_pkg_o.ras_ptr_snapshot      = data_pkg_i.ras_ptr_snapshot;
    assign data_pkg_o.gshare_ghr_snapshot   = data_pkg_i.gshare_ghr_snapshot;

    // 前推
    assign data_pkg_o.fwd_rs1_data = forwarding_rs1_data_hit;
    assign data_pkg_o.fwd_rs2_data = (ipkg.is_alu_i) ? {{20{inst_i[31]}}, inst_i[31:20]} : forwarding_rs2_data_hit;    // 立即数时返回 imm
    assign data_pkg_o.fwd_rs1_hit_ex = forwarding_rs1_ex;
    assign data_pkg_o.fwd_rs2_hit_ex = forwarding_rs2_ex & !ipkg.is_alu_i;  // 当为立即数时，不启用前推
    
    // CSR
    always_comb begin
        unique case (1'b1)
            ipkg.is_zicsr : csr_addr_o = inst_i[31:20];
            `ifdef ENABLE_F
            ipkg.is_FP    : csr_addr_o = 12'h003;       // fcsr
            ipkg.is_FM    : csr_addr_o = 12'h003;       // fcsr
            `endif
            default       : csr_addr_o = 12'h0;
        endcase
    end
    assign data_pkg_o.csr_waddr = csr_addr_o;
    assign data_pkg_o.csr_rdata = csr_rdata_i;

    // 数据
    logic [31:0] imm_o, jump1_o, jump2_o;
    logic [4:0] rd_addr_o;
    assign data_pkg_o.imm       = imm_o;
    assign data_pkg_o.jump1     = jump1_o;
    assign data_pkg_o.jump2     = jump2_o;
    `ifdef ENABLE_F
    assign data_pkg_o.rd_addr   = rd_addr_with_F;
    assign data_pkg_o.rs3_rdata = rs3_rdata_i;
    `else
    assign data_pkg_o.rd_addr   = rd_addr_o;
    `endif

    wire rd_neq_zero = (rd_i != 5'b0) | using_frd;
    
    always_comb begin
        unique case(1'b1)
            ipkg.is_lui: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = {inst_i[31:12], 12'b0};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_auipc: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = pc_i + {inst_i[31:12], 12'b0};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_jal: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = pc_next;
                jump1_o     = 32'b0;
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rd_addr_o   = rd_i;
            end

            ipkg.is_jalr: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = pc_next;
                jump1_o     = data_pkg_i.pred_flush.pc - {{20{inst_i[31]}}, inst_i[31:20]};     // 提前计算 rs1 == pred_pc - imm
                jump2_o     = {{20{inst_i[31]}}, inst_i[31:20]};
                rd_addr_o   = rd_i;
            end

            ipkg.is_branch: begin
                regs_wen_o  = 1'b0;
                imm_o       = 32'b0;
                jump1_o     = pc_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                jump2_o     = pc_next;
                rd_addr_o   = 5'b0;
            end

            ipkg.is_load: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_store: begin
                regs_wen_o  = 1'b0;
                imm_o       = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end

            ipkg.is_alu_i: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_alu_r: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_zicsr: begin
                unique case(1'b1)
                    ipkg.sel_csrrw, ipkg.sel_csrrs, ipkg.sel_csrrc: begin
                        regs_wen_o  = rd_neq_zero;
                        imm_o       = inst_i[19:15];
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    ipkg.sel_csrrwi, ipkg.sel_csrrsi, ipkg.sel_csrrci: begin
                        regs_wen_o  = rd_neq_zero;
                        imm_o       = inst_i[19:15]; // zicsr立即数在rs1地址位
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = rd_i;
                    end
                    ipkg.sel_ecall, ipkg.sel_mret: begin
                        regs_wen_o  = 1'b0; // ecall和mret不写寄存器
                        imm_o       = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = 5'b0;
                    end
                    default: begin
                        regs_wen_o  = 1'b0;
                        imm_o       = 32'b0;
                        jump1_o     = 32'b0;
                        jump2_o     = 32'b0;
                        rd_addr_o   = 5'b0;
                    end
                endcase
            end

            `ifdef ENABLE_A
            ipkg.is_Aext: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end
            `endif

            `ifdef ENABLE_F
            ipkg.is_FP, ipkg.is_FM: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = {29'b0, funct3_i};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_load_FP: begin
                regs_wen_o  = rd_neq_zero;
                imm_o       = {{20{inst_i[31]}}, inst_i[31:20]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = rd_i;
            end

            ipkg.is_store_FP: begin
                regs_wen_o  = 1'b0;
                imm_o       = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end
            `endif

            default: begin
                regs_wen_o  = 1'b0;
                imm_o       = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule