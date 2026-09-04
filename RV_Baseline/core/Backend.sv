`include "alu_def.svh"
`include "switch.svh"
module Backend(
    input  logic                        clk                     ,
    input  logic                        rst                     ,

    // from Frontend
    input  prefetch_t                   data_pkg_i              ,
    input  logic                        valid_i                 ,

    // to Frontend
    output flush_t                      EX_mispred_flush        ,
    output BPU_data_t                   BPU_data_pkg_o          ,
    output logic                        ready_o                 ,

    // to RF
    output logic [`RF_IDX_WIDTH - 1:0]  RF_rs1_addr_o           ,
    output logic [`RF_IDX_WIDTH - 1:0]  RF_rs2_addr_o           ,
    output RF_data_t                    RF_data_pkg_o           ,
    `ifdef ENABLE_F
    output logic [`RF_IDX_WIDTH - 1:0]  RF_rs3_addr_o           ,
    `endif

    // to CSR
    output logic [11:0]                 CSR_addr_o              ,
    output logic [31:0]                 CSR_WB_pc_o             ,
    output CSR_data_t                   CSR_data_pkg_o          ,
    output logic                        EX_ecall_o              ,
    output logic                        EX_mret_o               ,
    output logic                        EX_sret_o               ,

    // from RF
    input  logic [31:0]                 RF_rs1_rdata_i          ,
    input  logic [31:0]                 RF_rs2_rdata_i          ,
    `ifdef ENABLE_F
    input  logic [31:0]                 RF_rs3_rdata_i          ,
    `endif

    // from CSR
    input  logic [31:0]                 CSR_rdata_i             ,
    input  flush_t                      CSR_trap_flush_i        ,

    // Perip Bridge side
    output logic [31:0]                 DCACHE_perip_addr       ,
    output logic [3:0]                  DCACHE_perip_we         ,
    output logic                        DCACHE_perip_wen        ,
    output logic [31:0]                 DCACHE_perip_wdata      ,
    input  logic [31:0]                 DCACHE_perip_rdata      
);

    // ID - out
    EX_data_t       ID_data_pkg_o;
    EX_FWD_data_t   ID_fwd_data_pkg_o;
    decode_t        ID_inst_pkg_o;
    logic           ID_regs_wen_o;
    logic           ID_valid_o;
    logic           ID_hazard_stall;

    // EX - in
    EX_data_t       EX_data_pkg_i;
    EX_FWD_data_t   EX_fwd_data_pkg_i;
    decode_t        EX_inst_pkg_i;
    logic           EX_regs_wen_i;
    logic           EX_valid_i;

    // EX - out
    logic [31:0]    EX_pc_o;
    logic           EX_valid_o;
    RF_data_t       EX_RF_data_pkg_o;
    MEM_data_t      EX_MEM_data_pkg_o;
    CSR_data_t      EX_CSR_data_pkg_o;
    DCACHE_data_t   EX_DCACHE_data_pkg_o;
    BPU_data_t      EX_BPU_data_pkg_o;
    flush_t         EX_mispred_flush_o;
    logic           EX_ctrl_stall;

    // MEM - in
    logic [31:0]    MEM_pc_i;
    logic           MEM_valid_i;
    RF_data_t       MEM_RF_data_pkg_i;
    MEM_data_t      MEM_MEM_data_pkg_i;
    CSR_data_t      MEM_CSR_data_pkg_i;

    // MEM - out
    logic [31:0]    MEM_pc_o;
    logic           MEM_valid_o;
    RF_data_t       MEM_RF_data_pkg_o;
    CSR_data_t      MEM_CSR_data_pkg_o;

    // D-Cache
    DCACHE_data_t   DCACHE_data_pkg_i;
    logic           DCACHE_load_ready;
    logic           DCACHE_store_ready;
    logic [31:0]    DCACHE_rdata;
    logic           DCACHE_stall;

    // WB - in
    logic [31:0]    WB_pc_i;
    logic           WB_valid_i;
    RF_data_t       WB_RF_data_pkg_i;
    CSR_data_t      WB_CSR_data_pkg_i;

    // WB - out
    RF_data_t       WB_RF_data_pkg_o;
    CSR_data_t      WB_CSR_data_pkg_o;

    assign ready_o          = ~(DCACHE_stall | ID_hazard_stall | EX_ctrl_stall);

    // hold & flush
    wire pipe_hold_id_ex        = DCACHE_stall | EX_ctrl_stall;
    wire pipe_hold_ex_mem       = DCACHE_stall;
    wire pipe_hold_ex_bpu       = DCACHE_stall;
    wire pipe_hold_mem1_mem2    = DCACHE_stall;

    wire pipe_flush_id_ex       = EX_mispred_flush.en | CSR_trap_flush_i.en | ID_hazard_stall;
    wire pipe_flush_ex          = EX_mispred_flush.en;
    // ID 例化
    id ID(
        .data_pkg_i             (data_pkg_i),
        .valid_i                (valid_i),

        .rs1_addr_o             (RF_rs1_addr_o),
        .rs2_addr_o             (RF_rs2_addr_o),
        .csr_addr_o             (CSR_addr_o),

        .rs1_rdata_i            (RF_rs1_rdata_i),
        .rs2_rdata_i            (RF_rs2_rdata_i),
        .csr_rdata_i            (CSR_rdata_i),

        `ifdef ENABLE_F
        .rs3_addr_o             (RF_rs3_addr_o),
        .rs3_rdata_i            (RF_rs3_rdata_i),
        `endif

        .data_pkg_o             (ID_data_pkg_o),
        .fwd_data_pkg_o         (ID_fwd_data_pkg_o),
        .inst_pkg_o             (ID_inst_pkg_o),
        .regs_wen_o             (ID_regs_wen_o),
        .valid_o                (ID_valid_o),

        .EX_RF_data_pkg_i       (EX_RF_data_pkg_o),
        .EX_is_load_i           (EX_MEM_data_pkg_o.req_load),
        .EX_CSR_wen_i           (EX_CSR_data_pkg_o.wen),

        .MEM1_RF_data_pkg_i     (MEM_RF_data_pkg_i),
        .MEM1_is_load_i         (MEM_MEM_data_pkg_i.req_load),
        .MEM1_CSR_wen_i         (MEM_CSR_data_pkg_i.wen),

        .MEM2_RF_data_pkg_i     (MEM_RF_data_pkg_o),
        .MEM2_CSR_wen_i         (MEM_CSR_data_pkg_o.wen),

        .WB_RF_data_pkg_i       (WB_RF_data_pkg_o),
        .WB_CSR_wen_i           (WB_CSR_data_pkg_o.wen),

        .hazard_en              (ID_hazard_stall)
    );

    // ID -> EX
    always_ff @(posedge clk) begin
        if (rst) begin
            EX_data_pkg_i       <= 0;
            EX_fwd_data_pkg_i   <= 0;
            EX_inst_pkg_i       <= 0;
            EX_regs_wen_i       <= 0;
            EX_valid_i          <= 0;
        end else if (pipe_hold_id_ex) begin
            // ..
            EX_fwd_data_pkg_i.fwd_rs1_hit_ex <= EX_fwd_data_pkg_i.fwd_rs1_hit_ex & pipe_hold_ex_mem;
            EX_fwd_data_pkg_i.fwd_rs2_hit_ex <= EX_fwd_data_pkg_i.fwd_rs2_hit_ex & pipe_hold_ex_mem;
        end else if (pipe_flush_id_ex) begin
            EX_data_pkg_i       <= 0;
            EX_fwd_data_pkg_i   <= 0;
            EX_inst_pkg_i       <= 0;
            EX_regs_wen_i       <= 0;
            EX_valid_i          <= 0;
        end else begin
            EX_data_pkg_i       <= ID_data_pkg_o;
            EX_fwd_data_pkg_i   <= ID_fwd_data_pkg_o;
            EX_inst_pkg_i       <= ID_inst_pkg_o;
            EX_regs_wen_i       <= ID_regs_wen_o;
            EX_valid_i          <= ID_valid_o;
        end
    end

    // EX 例化
    ex EX(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_flush             (pipe_flush_ex),

        // from ID
        .data_pkg_i             (EX_data_pkg_i),
        .fwd_data_pkg_i         (EX_fwd_data_pkg_i),
        .inst_pkg_i             (EX_inst_pkg_i),
        .regs_wen_i             (EX_regs_wen_i),
        .valid_i                (EX_valid_i),

        // frowarding EX data
        .fwd_ex_rd_data_i       (MEM_RF_data_pkg_i.rd_data),

        // from D-Cache
        `ifdef ENABLE_A
        .DCACHE_load_ready_i    (DCACHE_load_ready),
        .DCACHE_store_ready_i   (DCACHE_store_ready),
        .DCACHE_rdata_i         (DCACHE_rdata),
        `endif

        // to MEM
        .pc_o                   (EX_pc_o),
        .valid_o                (EX_valid_o),
        .MEM_data_pkg_o         (EX_MEM_data_pkg_o),
        .RF_data_pkg_o          (EX_RF_data_pkg_o),
        .CSR_data_pkg_o         (EX_CSR_data_pkg_o),

        // to D-Cache
        .DCACHE_data_pkg_o      (EX_DCACHE_data_pkg_o),

        // to BPU
        .BPU_data_pkg_o         (EX_BPU_data_pkg_o),
        .mispred_flush_o        (EX_mispred_flush_o),

        // to CSR
        .ecall_o                (EX_ecall_o),
        .mret_o                 (EX_mret_o),
        .sret_o                 (EX_sret_o),

        // ctrl_stall
        .ctrl_stall_o           (EX_ctrl_stall)
    );

    // EX -> MEM
    always_ff @(posedge clk) begin
        if (rst) begin
            MEM_pc_i                <= 0;
            MEM_valid_i             <= 0;
            MEM_MEM_data_pkg_i      <= 0;
            MEM_RF_data_pkg_i       <= 0;
            MEM_CSR_data_pkg_i      <= 0;
            DCACHE_data_pkg_i       <= 0;
        end else if (pipe_hold_ex_mem) begin
            // ...
        end else begin
            MEM_pc_i                <= EX_pc_o;
            MEM_valid_i             <= EX_valid_o;
            MEM_MEM_data_pkg_i      <= EX_MEM_data_pkg_o;
            MEM_RF_data_pkg_i       <= EX_RF_data_pkg_o;
            MEM_CSR_data_pkg_i      <= EX_CSR_data_pkg_o;
            DCACHE_data_pkg_i       <= EX_DCACHE_data_pkg_o;
        end
    end
    
    // EX -> BPU
    always_ff @(posedge clk) begin
        if (rst) begin
            BPU_data_pkg_o      <= 0;
            EX_mispred_flush    <= 0;
        end else if (pipe_hold_ex_bpu) begin
            // ...
        end else begin
            BPU_data_pkg_o      <= EX_BPU_data_pkg_o;
            EX_mispred_flush    <= EX_mispred_flush_o;
        end
    end

    // MEM
    mem MEM(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (pipe_hold_mem1_mem2),

        .DCACHE_ack             (DCACHE_load_ready),
        .DCACHE_rdata           (DCACHE_rdata),

        .pc_i                   (MEM_pc_i),
        .valid_i                (MEM_valid_i),
        .MEM_data_pkg_i         (MEM_MEM_data_pkg_i),
        .RF_data_pkg_i          (MEM_RF_data_pkg_i),
        .CSR_data_pkg_i         (MEM_CSR_data_pkg_i),

        .pc_o                   (MEM_pc_o),
        .valid_o                (MEM_valid_o),
        .RF_data_pkg_o          (MEM_RF_data_pkg_o),
        .CSR_data_pkg_o         (MEM_CSR_data_pkg_o)
    );

    // D-cache
    dcache DCACHE(
        .clk                    (clk),
        .rst                    (rst),

        .cpu_data_pkg_i         (DCACHE_data_pkg_i),
        .cpu_rdata              (DCACHE_rdata),
        .load_ready             (DCACHE_load_ready),
        .store_ready            (DCACHE_store_ready),

        .stall                  (DCACHE_stall),

        .perip_addr             (DCACHE_perip_addr),
        .perip_we               (DCACHE_perip_we),
        .perip_wen              (DCACHE_perip_wen),
        .perip_wdata            (DCACHE_perip_wdata),
        .perip_rdata            (DCACHE_perip_rdata)
    );

    // MEM -> WB
    always_ff @(posedge clk) begin
        if (rst) begin
            WB_pc_i                 <= 0;
            WB_valid_i              <= 0;
            WB_RF_data_pkg_i        <= 0;
            WB_CSR_data_pkg_i       <= 0;
        end else begin
            WB_pc_i                 <= MEM_pc_o;
            WB_valid_i              <= MEM_valid_o;
            WB_RF_data_pkg_i        <= MEM_RF_data_pkg_o;
            WB_CSR_data_pkg_i       <= MEM_CSR_data_pkg_o;
        end
    end

    // WB
    assign RF_data_pkg_o  = WB_RF_data_pkg_o;
    assign CSR_data_pkg_o = WB_CSR_data_pkg_o;
    wb WB(
        .pc_i                   (WB_pc_i),
        .valid_i                (WB_valid_i),
        .data_pkg_i             (WB_RF_data_pkg_i),
        .CSR_data_pkg_i         (WB_CSR_data_pkg_i),

        .pc_o                   (CSR_WB_pc_o),
        .data_pkg_o             (WB_RF_data_pkg_o),
        .CSR_data_pkg_o         (WB_CSR_data_pkg_o)
    );
endmodule