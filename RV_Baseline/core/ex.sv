`include "rv32I.svh"
`include "alu_def.svh"
`include "switch.svh"

module ex(
    input  logic            clk                         ,
    input  logic            rst                         ,
    input  logic            pipe_flush                  ,

    // from ID
    input  EX_data_t        data_pkg_i                  ,
    input  decode_t         inst_pkg_i                  ,
    input  logic            regs_wen_i                  ,
    input  logic            valid_i                     ,

    // frowarding EX data
    input  logic [31:0]     fwd_ex_rd_data_i            ,

    // from D-Cache
    `ifdef ENABLE_A
    input  logic            DCACHE_load_ready_i         ,
    input  logic            DCACHE_store_ready_i        ,
    input  logic [31:0]     DCACHE_rdata_i              ,
    `endif

    // to MEM
    output logic [31:0]     pc_o                        ,
    output logic            valid_o                     ,
    output MEM_data_t       MEM_data_pkg_o              ,
    output RF_data_t        RF_data_pkg_o               ,
    output CSR_data_t       CSR_data_pkg_o              ,

    // to D-Cache
    output DCACHE_data_t    DCACHE_data_pkg_o           ,

    // to BPU
    output BPU_data_t       BPU_data_pkg_o              ,
    output flush_t          mispred_flush_o             ,

    // to CSR
    output logic            ecall_o                     ,
    output logic            mret_o                      ,
    output logic            sret_o                      ,

    // ctrl_stall
    output logic            ctrl_stall_o                
);
    // debug 端口
    wire [31:0] pc         = data_pkg_i.pc;
    wire [31:0] inst       = data_pkg_i.inst;
    wire [31:0] imm        = data_pkg_i.imm;
    wire [31:0] jump1      = data_pkg_i.jump1;
    wire [31:0] jump2      = data_pkg_i.jump2;
    wire [5:0]  rd_addr    = data_pkg_i.rd_addr;
    wire        pred_taken = data_pkg_i.pred_taken;

    // 指令包重命名
    decode_t ipkg;
    assign ipkg = inst_pkg_i;

    // 数据包重命名
    (* max_fanout = 50 *)
    EX_data_t dpkg;
    assign dpkg = data_pkg_i;
    assign pc_o = dpkg.pc;

    // 有效标志传递
    wire valid = valid_i & ~ctrl_stall_o & ~pipe_flush;
    assign valid_o = valid;
    
    // 前推选择 - 对上一周期 ex 的前推
    (* max_fanout = 64 *) logic [31:0] rs1_data_fwd, rs2_data_fwd;
    assign rs1_data_fwd = (dpkg.fwd_rs1_hit_ex) ? fwd_ex_rd_data_i : dpkg.fwd_rs1_data;
    assign rs2_data_fwd = (dpkg.fwd_rs2_hit_ex) ? fwd_ex_rd_data_i : dpkg.fwd_rs2_data;
    
    // 访存地址计算
    wire [31:0] mem_addr_calc     = rs1_data_fwd + dpkg.imm;
    wire [1:0]  mem_addr_calc_low = rs1_data_fwd[1:0] + dpkg.imm[1:0];
    
    // 输出计算结果
    logic [31:0] alu_result;
    always_comb begin
        unique case (1'b1)
            ipkg.is_rv32i     : alu_result = RV32I_res;
            ipkg.is_zicsr     : alu_result = dpkg.csr_rdata;
            `ifdef ENABLE_M
            ipkg.is_Mext      : alu_result = Mext_res;
            `endif
            `ifdef ENABLE_B
            is_Bext           : alu_result = Bext_res;
            `endif
            `ifdef ENABLE_Zicond
            ipkg.is_Zicondext : alu_result = Zicondext_res;
            `endif
            `ifdef ENABLE_A
            ipkg.is_Aext      : alu_result = Aext_res;
            `endif
            `ifdef ENABLE_F
            ipkg.is_FP        : alu_result = Fext_res;
            ipkg.is_FM        : alu_result = Fext_res;
            `endif
            default           : alu_result = 32'b0;
        endcase
    end
    
    // rd & dram 读写
    always_comb begin
        MEM_data_pkg_o = 0;
        RF_data_pkg_o  = 0;

        if (valid) begin
            RF_data_pkg_o.rd_addr          = dpkg.rd_addr;                              // [RF]  写地址
            RF_data_pkg_o.rd_data          = alu_result;                                // [RF]  写数据
            RF_data_pkg_o.regs_wen         = regs_wen_i & valid;                        // [RF]  写使能

            MEM_data_pkg_o.req_load        = DCACHE_data_pkg_o.req_load;                // [MEM] 访存请求
            MEM_data_pkg_o.load_is_signed  = ipkg.sel_lb | ipkg.sel_lh | ipkg.sel_lw;   // [MEM] 访存使用符号
            MEM_data_pkg_o.load_addr_low   = mem_addr_calc_low;                         // [MEM] 访存地址

            unique case (1'b1)                                                          // [MEM] 访存位掩码
                ipkg.sel_lb     : MEM_data_pkg_o.load_mask = 2'b01;
                ipkg.sel_lh     : MEM_data_pkg_o.load_mask = 2'b10;
                ipkg.sel_lw     : MEM_data_pkg_o.load_mask = 2'b11;
                ipkg.sel_lbu    : MEM_data_pkg_o.load_mask = 2'b01;
                ipkg.sel_lhu    : MEM_data_pkg_o.load_mask = 2'b10;
                `ifdef ENABLE_F
                ipkg.is_load_FP : MEM_data_pkg_o.load_mask = 2'b11;
                `endif
                `ifdef ENABLE_A
                ipkg.sel_lr_w   : MEM_data_pkg_o.load_mask = 2'b11;
                `endif
                default         : MEM_data_pkg_o.load_mask = 2'b00;
            endcase
        end
    end
    
    // RV32I Unit
    logic [31:0] RV32I_res;
    alu_RV32I ALU_RV32I (
        .value1         (rs1_data_fwd),
        .value2         (rs2_data_fwd),
        .ipkg           (ipkg),
        .dpkg           (dpkg),
        .valid_i        (valid),
        
        .bpkg           (BPU_data_pkg_o),
        .mispred_flush  (mispred_flush_o),
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
        .valid_i        (valid),
        
        .atom_req_load  (atom_req_load),
        .atom_req_store (atom_req_store),
        .atom_addr      (atom_addr),
        .atom_wdata     (atom_wdata),
        
        .dcachepkg      (DCACHE_data_pkg_o)
    );
    
    // CSR 控制
    logic [4:0] fflags;
    alu_csr ALU_CSR (
        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),
        .dpkg       (dpkg),
        
        `ifdef ENABLE_F
        .fflags     (fflags),
        `endif
        
        .cpkg       (CSR_data_pkg_o)
    );
    assign ecall_o = ipkg.sel_ecall & valid;
    assign mret_o  = ipkg.sel_mret & valid;
    assign sret_o  = ipkg.sel_sret & valid;
    
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
    logic Bext_ctrl;
    logic [31:0] Bext_res;
    `ifdef ENABLE_B
    wire is_Bext = ipkg.is_Bext_zba | ipkg.is_Bext_zbb | ipkg.is_Bext_zbc | ipkg.is_Bext_zbs | ipkg.is_Bext_zbkb | ipkg.is_Bext_zbkx;
    alu_Bext ALU_BEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .valid      (is_Bext & valid_o),
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
        .load_ready     (DCACHE_load_ready_i),
        .store_ready    (DCACHE_store_ready_i),
        .mem_rdata      (DCACHE_rdata_i),

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
    assign ctrl_stall_o = (Mext_ctrl | Bext_ctrl | Aext_ctrl | Fext_ctrl) & ~pipe_flush;
endmodule
