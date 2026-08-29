`include "rv32I.svh"
`include "alu_def.svh"
`include "switch.svh"

module top_riscv(
    input  logic            cpu_rst                 ,
    input  logic            cpu_clk                 ,

    // to Perip Bridge
    output logic [31:0]     ICACHE_perip_addr       ,
    output logic            ICACHE_perip_arvalid    ,
    output logic            ICACHE_perip_ren        ,
    input  logic            ICACHE_perip_ready      ,
    input  logic [31:0]     ICACHE_perip_rdata      ,
    input  logic            ICACHE_perip_rvalid     ,

    output logic [31:0]     DCACHE_perip_addr       ,
    output logic [3:0]      DCACHE_perip_we         ,
    output logic            DCACHE_perip_wen        ,
    output logic [31:0]     DCACHE_perip_wdata      ,
    input  logic [31:0]     DCACHE_perip_rdata      
);
    // RF
    logic [`RF_IDX_WIDTH - 1:0] RF_rs1_addr_i;
    logic [`RF_IDX_WIDTH - 1:0] RF_rs2_addr_i;
    logic [31:0]                RF_rs1_rdata_o;
    logic [31:0]                RF_rs2_rdata_o;
    `ifdef ENABLE_F
    logic [`RF_IDX_WIDTH - 1:0] RF_rs3_addr_i;
    logic [31:0]                RF_rs3_rdata_o;
    `endif
    
    // CSR
    logic [11:0]                CSR_addr_i;
    logic [31:0]                CSR_rdata;
    flush_t                     CSR_trap_flush;
    
    // Frontend to Backend
    prefetch_t                  Backend_data_pkg_i;
    logic                       Backend_valid_i;
    
    // Backend to Frontend
    BPU_data_t                  Backend_BPU_data_pkg_o;
    logic                       Backend_ready;
    flush_t                     Backend_EX_mispred_flush_o;
    logic                       Backend_EX_ecall_o;
    logic                       Backend_EX_mret_o;
    logic                       Backend_EX_sret_o;
    
    // Backend to RF & CSR
    RF_data_t                   Backend_RF_data_pkg_o;
    logic [31:0]                Backend_WB_pc_o;
    CSR_data_t                  Backend_CSR_data_pkg_o;

    // RF 例化
    RF RF(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),

        .data_pkg_i             (Backend_RF_data_pkg_o),
        
        `ifdef ENABLE_F
        .rs3_addr_i             (RF_rs3_addr_i),
        .rs3_data_o             (RF_rs3_rdata_o),
        `endif

        .rs1_addr_i             (RF_rs1_addr_i),
        .rs2_addr_i             (RF_rs2_addr_i),

        .rs1_data_o             (RF_rs1_rdata_o),
        .rs2_data_o             (RF_rs2_rdata_o)
    );

    // CSR 例化
    CSR CSR(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),

        .csr_addr               (CSR_addr_i),
        .csr_rdata              (CSR_rdata),
        
        .wb_pc_i                (Backend_WB_pc_o),
        .data_pkg_i             (Backend_CSR_data_pkg_o),
        
        .ex_ecall               (Backend_EX_ecall_o),
        .ex_mret                (Backend_EX_mret_o),
        .ex_sret                (Backend_EX_sret_o),
        
        .trap_flush_o           (CSR_trap_flush)
    );

    // Frontend 例化
    Frontend Frontend(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),

        // PC Flush
        .EX_mispred_flush_i     (Backend_EX_mispred_flush_o),
        .CSR_trap_flush_i       (CSR_trap_flush),

        // to Backend
        .data_pkg_o             (Backend_data_pkg_i),
        .valid_o                (Backend_valid_i),

        // from Backend
        .BPU_data_pkg_i         (Backend_BPU_data_pkg_o),
        .Backend_ready_i        (Backend_ready),

        // Perip Bridge side
        .ICACHE_perip_addr      (ICACHE_perip_addr),
        .ICACHE_perip_arvalid   (ICACHE_perip_arvalid),
        .ICACHE_perip_ren       (ICACHE_perip_ren),
        .ICACHE_perip_ready     (ICACHE_perip_ready),
        .ICACHE_perip_rdata     (ICACHE_perip_rdata),
        .ICACHE_perip_rvalid    (ICACHE_perip_rvalid)
    );

    // Backend 例化
    Backend Backend(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),

        // from Frontend
        .data_pkg_i             (Backend_data_pkg_i),
        .valid_i                (Backend_valid_i),

        // to Frontend
        .EX_mispred_flush       (Backend_EX_mispred_flush_o),
        .BPU_data_pkg_o         (Backend_BPU_data_pkg_o),
        .ready_o                (Backend_ready),

        // to RF
        .RF_rs1_addr_o          (RF_rs1_addr_i),
        .RF_rs2_addr_o          (RF_rs2_addr_i),
        .RF_data_pkg_o          (Backend_RF_data_pkg_o),
        `ifdef ENABLE_F
        .RF_rs3_addr_o          (RF_rs3_addr_i),
        `endif

        // to CSR
        .CSR_addr_o             (CSR_addr_i),
        .CSR_WB_pc_o            (Backend_WB_pc_o),
        .CSR_data_pkg_o         (Backend_CSR_data_pkg_o),
        .EX_ecall_o             (Backend_EX_ecall_o),
        .EX_mret_o              (Backend_EX_mret_o),
        .EX_sret_o              (Backend_EX_sret_o),

        // from RF
        .RF_rs1_rdata_i         (RF_rs1_rdata_o),
        .RF_rs2_rdata_i         (RF_rs2_rdata_o),
        `ifdef ENABLE_F
        .RF_rs3_rdata_i         (RF_rs3_rdata_o),
        `endif

        // from CSR
        .CSR_rdata_i            (CSR_rdata),
        .CSR_trap_flush_i       (CSR_trap_flush),

        // Perip Bridge side
        .DCACHE_perip_addr      (DCACHE_perip_addr),
        .DCACHE_perip_we        (DCACHE_perip_we),
        .DCACHE_perip_wen       (DCACHE_perip_wen),
        .DCACHE_perip_wdata     (DCACHE_perip_wdata),
        .DCACHE_perip_rdata     (DCACHE_perip_rdata)
);

endmodule
