`include "rv32I.vh"
`include "alu_def.svh"
`include "switch.vh"

module ex(
    input  logic            clk,
    input  logic            rst,
    input  logic            pipe_flush,

    // from id_ex
    input  id_ex_data_t     data_packaged_i,
    input  decode_t         inst_packaged_i,
    input  logic            regs_wen_i,
    input  logic            valid_i,

    // frowarding ex data
    input  logic [31:0]     fwd_ex_rd_data_i,

    // from d-cache
    input  logic            dcache_load_ready_i,
    input  logic            dcache_store_ready_i,
    input  logic [31:0]     dcache_rdata_i,

    // to ex_mem & hazard
    output ex_mem_data_t    mem_data_packaged_o,
    output logic            valid_o,

    // to ex_dcache & hazard
    output ex_lsu_data_t    dcache_data_packaged_o,

    // to ex_bpu
    output ex_bpu_data_t    bpu_data_packaged_o,
    output logic            pred_flush_en,
    output logic [31:0]     pred_flush_pc,

    // to csr_regs
    output ex_csr_data_t    csr_data_packaged_o,

    // ctrl_stall
    output logic            ctrl_stall
);
    // debug 端口
    wire [31:0] pc         = data_packaged_i.pc;
    wire [31:0] inst       = data_packaged_i.inst;
    wire [31:0] imm        = data_packaged_i.imm;
    wire [31:0] jump1      = data_packaged_i.jump1;
    wire [31:0] jump2      = data_packaged_i.jump2;
    wire [5:0]  rd_addr    = data_packaged_i.rd_addr;
    wire        pred_taken = data_packaged_i.pred_taken;

    // 主操作码独热
    decode_t ipkg;
    assign ipkg = inst_packaged_i;

    id_ex_data_t dpkg;
    assign dpkg = data_packaged_i;

    // 前推选择 - 当为立即数时 fwd_rs2_data_i 代表 imm
    wire fwd_rs1_hit_ex_i = dpkg.fwd_rs1_hit_ex;
    wire fwd_rs2_hit_ex_i = dpkg.fwd_rs2_hit_ex;
    wire [31:0] fwd_rs1_data_i = dpkg.fwd_rs1_data;
    wire [31:0] fwd_rs2_data_i = dpkg.fwd_rs2_data;
    
    // 前推选择 - 对上一周期 ex 的前推
    wire [31:0] rs1_data_fwd = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] rs2_data_fwd = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;
    
    // 访存地址计算
    wire [31:0]  mem_addr_calc = rs1_data_fwd + dpkg.imm;
    wire mem_addr_calc_sum0 = rs1_data_fwd[0] ^ dpkg.imm[0];
    wire mem_addr_calc_carry0 = rs1_data_fwd[0] & dpkg.imm[0];
    wire mem_addr_calc_sum1 = rs1_data_fwd[1] ^ dpkg.imm[1] ^ mem_addr_calc_carry0;
    wire [1:0]  mem_addr_calc_low = {mem_addr_calc_sum1, mem_addr_calc_sum0};
    
    // 输出计算结果
    logic [31:0] alu_result;
    always_comb begin
        unique case (1'b1)
            ipkg.is_rv32i     : alu_result = RV32I_res;
            ipkg.is_zicsr     : alu_result = dpkg.csr_rdata;
            ipkg.is_Mext      : alu_result = Mext_res;
            is_Bext           : alu_result = Bext_res;
            ipkg.is_Zicondext : alu_result = Zicondext_res;
            ipkg.is_Aext      : alu_result = Aext_res;
            ipkg.is_FP        : alu_result = Fext_res;
            default           : alu_result = 32'b0;
        endcase
    end
    
    // rd & dram 读写
    ex_mem_data_t mpkg;
    assign mem_data_packaged_o  = mpkg;
    assign mpkg.rd_addr         = dpkg.rd_addr;
    assign mpkg.rd_data         = alu_result;
    assign mpkg.regs_wen        = regs_wen_i & ~ctrl_stall; // regs 写使能
    assign mpkg.req_load        = dcache_data_packaged_o.req_load;
    assign mpkg.load_is_signed  = ipkg.sel_lb | ipkg.sel_lh | ipkg.sel_lw;
    assign mpkg.load_addr_low   = mem_addr_calc_low;
    assign valid_o              = valid_i; // 未使用
    
    always_comb begin
        unique case (1'b1)
            ipkg.is_load_FP : mpkg.load_mask = 2'b11;
            ipkg.sel_lr_w   : mpkg.load_mask = 2'b11;
            ipkg.sel_lb     : mpkg.load_mask = 2'b01;
            ipkg.sel_lh     : mpkg.load_mask = 2'b10;
            ipkg.sel_lw     : mpkg.load_mask = 2'b11;
            ipkg.sel_lbu    : mpkg.load_mask = 2'b01;
            ipkg.sel_lhu    : mpkg.load_mask = 2'b10;
            default         : mpkg.load_mask = 2'b00;
        endcase    
    end
    
    // RV32I Unit
    logic [31:0] RV32I_res;
    alu_RV32I ALU_RV32I (
        .value1         (rs1_data_fwd),
        .value2         (rs2_data_fwd),
        .imm            (dpkg.imm),
        .jump1          (dpkg.jump1),
        .jump2          (dpkg.jump2),
        .ipkg           (ipkg),
        .dpkg           (dpkg),
        
        .bpkg       (bpu_data_packaged_o),
        .pred_flush_en  (pred_flush_en),
        .pred_flush_pc  (pred_flush_pc),
        .result         (RV32I_res)
    );
    
    // Load & Store Unit
    logic atom_req_load, atom_req_store;
    logic [31:0] atom_addr, atom_wdata;
    alu_lsu ALU_LSU (
        .rs1            (rs1_data_fwd),
        .rs2            (rs2_data_fwd),
        .mem_addr       (mem_addr_calc),
        .mem_addr_low   (mem_addr_calc_low),
        .regs_wen       (regs_wen_i),
        .ipkg           (ipkg),
        
        .atom_req_load  (atom_req_load),
        .atom_req_store (atom_req_store),
        .atom_addr      (atom_addr),
        .atom_wdata     (atom_wdata),
        
        .dcachepkg      (dcache_data_packaged_o)
    );
    
    // CSR 控制
    logic [4:0] fflags;
    alu_csr ALU_CSR (
        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),
        .dpkg       (dpkg),

        .fflags     (fflags),

        .cpkg       (csr_data_packaged_o)
    );
    
    // M-ext
    logic Mext_ctrl;
    logic [31:0] Mext_res;
    `ifdef ENABLE_M
    alu_Mext ALU_MEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),

        .ctrl       (Mext_ctrl),
        .result     (Mext_res)
    );
    `else
    assign Mext_ctrl = 1'b0;
    `endif

    // B-ext
    wire is_Bext = ipkg.is_Bext_zba | ipkg.is_Bext_zbb | ipkg.is_Bext_zbc | ipkg.is_Bext_zbs | ipkg.is_Bext_zbkb | ipkg.is_Bext_zbkx;
    logic Bext_ctrl;
    logic [31:0] Bext_res;
    `ifdef ENABLE_B
    alu_Bext ALU_BEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .valid      (is_Bext),
        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),

        .ctrl       (Bext_ctrl),
        .result     (Bext_res)
    );
    `else
    assign Bext_ctrl = 1'b0;
    assign Bext_res  = 32'b0;
    `endif

    // Zicond-ext
    logic [31:0] Zicondext_res;
    `ifdef ENABLE_Zicond
    wire Zicond_value2_nez = |rs2_data_fwd;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_czero_eqz : Zicondext_res = (~Zicond_value2_nez) ? 0 : rs1_data_fwd;
            ipkg.sel_czero_nez : Zicondext_res = (Zicond_value2_nez)  ? 0 : rs1_data_fwd;
            default : Zicondext_res = 32'b0;
        endcase
    end
    `else
    assign Zicondext_res = 32'b0;
    `endif

    // A-ext
    logic Aext_ctrl;
    logic [31:0] Aext_res;
    `ifdef ENABLE_A
    alu_Aext ALU_AEXT (
        .clk            (clk),
        .rst            (rst),
        .flush          (pipe_flush),

        .rs1            (rs1_data_fwd),
        .rs2            (rs2_data_fwd),
        .ipkg           (ipkg),

        .AXI_wen        (1'b0),
        .load_ready     (dcache_load_ready_i),
        .store_ready    (dcache_store_ready_i),
        .mem_rdata      (dcache_rdata_i),

        .atom_req_load  (atom_req_load),
        .atom_req_store (atom_req_store),
        .atom_addr      (atom_addr),
        .atom_wdata     (atom_wdata),

        .AXI_lock       (),
        .ctrl           (Aext_ctrl),
        .result         (Aext_res)
    );
    `else
    assign atom_req_load  = 1'b0;
    assign atom_req_store = 1'b0;
    assign atom_addr      = 32'b0;
    assign atom_wdata     = 32'b0;

    assign Aext_ctrl      = 1'b0;
    assign Aext_res       = 32'b0;
    `endif

    // F-ext
    logic Fext_ctrl;
    logic [31:0] Fext_res;
    `ifdef ENABLE_F
    alu_Fext ALU_FEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .dpkg       (dpkg),
        .ipkg       (ipkg),

        .fflags     (fflags),

        .ctrl       (Fext_ctrl),
        .result     (Fext_res)
    );
    `else
    assign fflags    = 0;
    assign Fext_ctrl = 1'b0;
    assign Fext_res  = 32'b0;
    `endif


    // ex 暂停控制
    assign ctrl_stall = (Mext_ctrl | Bext_ctrl | Aext_ctrl | Fext_ctrl) & ~pipe_flush;
endmodule
