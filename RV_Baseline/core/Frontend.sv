`include "alu_def.svh"
`include "switch.svh"

module Frontend(
    input  logic            clk                     ,
    input  logic            rst                     ,

    // PC flush
    input  flush_t          EX_mispred_flush_i      ,
    input  flush_t          CSR_trap_flush_i        ,

    // to Backend
    output prefetch_t       data_pkg_o              ,
    output logic            valid_o                 ,

    // from Backend
    input  BPU_data_t       BPU_data_pkg_i          ,
    input  logic            Backend_ready_i         ,

    // Perip Bridge side
    output logic [31:0]     ICACHE_perip_addr       ,
    output logic            ICACHE_perip_arvalid    ,
    output logic            ICACHE_perip_ren        ,
    input  logic            ICACHE_perip_ready      ,
    input  logic [31:0]     ICACHE_perip_rdata      ,
    input  logic            ICACHE_perip_rvalid     
);
    // flush
    wire Frontend_flush           = EX_mispred_flush_i.en | CSR_trap_flush_i.en;
    wire Frontend_flush_with_pred = Frontend_flush | BPU_pred_flush.en;

    // PC
    (* max_fanout = 64 *)
    logic [31:0]    PC_pc_o;
    logic           PC_stall;

    // I-Cache
    logic [31:0]    ICACHE_req_pc;
    logic           ICACHE_req_valid;
    logic [31:0]    ICACHE_resp_pc;
    logic [31:0]    ICACHE_resp_inst;
    logic           ICACHE_resp_valid;
    logic           ICACHE_stall;

    // RVCExpander
    `ifdef ENABLE_C
    logic           RVCE_is_compressed;
    logic [31:0]    RVCE_expanded_inst;
    `endif

    // BPU
    logic [31:0]                        BPU_pc_r;
    logic [31:0]                        BPU_inst_r;
    `ifdef ENABLE_C
    logic                               BPU_is_compressed_r;
    `endif
    logic [31:0]                        BPU_pc_next_r;
    logic                               BPU_valid_r;
    flush_t                             BPU_pred_flush;
    logic [4:0]                         BPU_ras_ptr_snapshot;
    logic [`GSHARE_BHR_WIDTH - 1:0]     BPU_gsahre_ghr_snapshot;
    logic [`GSHARE_BHR_WIDTH - 1:0]     BPU_gsahre_ghr_snapshot_r;

    // FIFO
    prefetch_t      Frontend_fifo_din;
    prefetch_t      Frontend_fifo_dout;
    logic           Frontend_fifo_isfull;
    logic           Frontend_fifo_isempty;

    // PC 例化
    assign PC_stall = ICACHE_stall | Frontend_fifo_isfull;
    pc PC(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (PC_stall),

        `ifdef ENABLE_C
        .frontend_isCompressed  (RVCE_is_compressed),
        `endif

        .BPU_pred_flush         (BPU_pred_flush),
        .EX_mispred_flush       (EX_mispred_flush_i),
        .CSR_trap_flush         (CSR_trap_flush_i),

        .pc_o                   (PC_pc_o)
    );

    // I-Cache 例化
    assign ICACHE_req_pc    = PC_pc_o;
    assign ICACHE_req_valid = 1'b1;
    icache ICACHE(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (Frontend_fifo_isfull),
        .pipe_flush             (Frontend_flush_with_pred),

        .cpu_addr               (ICACHE_req_pc),
        .cpu_arvalid            (ICACHE_req_valid),
        .cpu_addr_r             (ICACHE_resp_pc),
        .cpu_rdata              (ICACHE_resp_inst),
        .cpu_rvalid             (ICACHE_resp_valid),
        .cpu_stall              (ICACHE_stall),

        .perip_addr             (ICACHE_perip_addr),
        .perip_arvalid          (ICACHE_perip_arvalid),
        .perip_ren              (ICACHE_perip_ren),
        .perip_ready            (ICACHE_perip_ready),
        .perip_rdata            (ICACHE_perip_rdata),
        .perip_rvalid           (ICACHE_perip_rvalid)
    );
    
    // RVCExpander 例化
    `ifdef ENABLE_C
    assign RVCE_is_compressed = ICACHE_resp_inst[1:0] != 2'b11;
    RVCExpander RVCExpander(
        .inst_i     (ICACHE_resp_inst),
        .inst_o     (RVCE_expanded_inst)
    );
    `endif

    // BPU 例化
    always_ff @(posedge clk) begin
        if (rst) begin
            BPU_pc_r                    <= 0;
            BPU_inst_r                  <= 0;
            `ifdef ENABLE_C
            BPU_is_compressed_r         <= 0;
            `endif
            BPU_pc_next_r               <= 0;
            BPU_valid_r                 <= 0;
            BPU_gsahre_ghr_snapshot_r   <= 0;
        end else if (Frontend_fifo_isfull) begin
            // ...
        end else if (Frontend_flush_with_pred) begin
            BPU_pc_r                    <= 0;
            BPU_inst_r                  <= 0;
            `ifdef ENABLE_C
            BPU_is_compressed_r         <= 0;
            `endif
            BPU_pc_next_r               <= 0;
            BPU_valid_r                 <= 0;
            BPU_gsahre_ghr_snapshot_r   <= 0;
        end else begin
            BPU_pc_r                    <= ICACHE_resp_pc;
            `ifdef ENABLE_C
            BPU_inst_r                  <= RVCE_expanded_inst;
            BPU_is_compressed_r         <= RVCE_is_compressed;
            `else
            BPU_inst_r                  <= ICACHE_resp_inst;
            `endif
            BPU_pc_next_r               <= ICACHE_req_pc;
            BPU_valid_r                 <= ICACHE_resp_valid;
            BPU_gsahre_ghr_snapshot_r   <= BPU_gsahre_ghr_snapshot;
        end
    end

    bpu_top #(
        .BHR_WIDTH          (`GSHARE_BHR_WIDTH),
        .PHT_IDX_WIDTH      (`GSHARE_PHT_IDX_WIDTH),
        .BTB_IDX_WIDTH      (`BTB_IDX_WIDTH)
    ) BPU(
        .clk                (clk),
        .rst                (rst),
        .pipe_hold          (Frontend_fifo_isfull),
        .pipe_flush         (Frontend_flush_with_pred),
        .outer_flush        (Frontend_flush),

        .pc_early_i         (ICACHE_req_pc),
        .pc_i               (ICACHE_resp_pc),
        `ifdef ENMABLE_C
        .inst_i             (RVCE_expanded_inst),
        `else
        .inst_i             (ICACHE_resp_inst),
        `endif
        .valid_i            (ICACHE_resp_valid),

        .data_pkg_i         (BPU_data_pkg_i),

        .pred_flush_o       (BPU_pred_flush),
        .ptr_o              (BPU_ras_ptr_snapshot),
        .ghr_o              (BPU_gsahre_ghr_snapshot)
    );

    // FIFO 例
    assign Frontend_fifo_din.pc                     = BPU_pc_r;
    assign Frontend_fifo_din.inst                   = BPU_inst_r;
    assign Frontend_fifo_din.pc_next                = BPU_pc_next_r;
    assign Frontend_fifo_din.pred_flush             = BPU_pred_flush;
    assign Frontend_fifo_din.ras_ptr_snapshot       = BPU_ras_ptr_snapshot;
    assign Frontend_fifo_din.gshare_ghr_snapshot    = BPU_gsahre_ghr_snapshot_r;
    fifo #(
        .DEPTH  (8),
        .WIDTH  ($bits(prefetch_t))
    ) frontend_ifetch_FIFO (
        .clk        (clk),
        .rst        (rst | Frontend_flush),
        .wr_en      (BPU_valid_r),
        .rd_en      (Backend_ready_i),
        .data_in    (Frontend_fifo_din),
        .data_out   (Frontend_fifo_dout),
        .full       (Frontend_fifo_isfull),
        .empty      (Frontend_fifo_isempty)
    );

    assign data_pkg_o = Frontend_fifo_dout;
    assign valid_o = Backend_ready_i;

endmodule