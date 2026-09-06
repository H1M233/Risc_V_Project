`include "alu_def.svh"
`include "switch.svh"

module Frontend(
    input  logic                    clk                     ,
    input  logic                    rst                     ,

    // PC flush
    input  flush_t                  EX_mispred_flush_i      ,
    input  flush_t                  CSR_trap_flush_i        ,

    // to Backend
    output prefetch_t               data_pkg_o              ,
    output logic                    valid_o                 ,

    // from Backend
    input  BPU_data_t               BPU_data_pkg_i          ,
    input  logic                    Backend_ready_i         ,

    // to PerfCounter
    output PerfCounter_t            PerfCounter_pkg_o       ,

    // Perip Bridge side
    output logic [31:0]             ICACHE_perip_addr       ,
    output logic                    ICACHE_perip_arvalid    ,
    output logic                    ICACHE_perip_ren        ,
    input  logic                    ICACHE_perip_ready      ,
    input  logic [31:0]             ICACHE_perip_rdata      ,
    input  logic                    ICACHE_perip_rvalid     
);
    // flush
    wire Frontend_flush           = EX_mispred_flush_i.en | CSR_trap_flush_i.en;
    wire Frontend_flush_with_pred = Frontend_flush | BPU_pred_flush.en;

    // PC
    (* max_fanout = 64 *)
    logic [31:0]    PC_pc;
    logic [31:0]    PC_ICACHE_req_pc;
    logic           PC_stall;

    // I-Cache
    logic [255:0]   ICACHE_resp_line;
    logic           ICACHE_resp_valid;

    // IAB
    logic           IAB_prefetch;
    logic           IAB_update_line;
    logic [31:0]    IAB_pc;
    logic [31:0]    IAB_inst;
    logic           IAB_valid;
    logic [1:0]     IAB_update_offest;

    // BPU
    logic [31:0]                        BPU_pc_r;
    logic [31:0]                        BPU_inst_r;
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
    assign PC_stall = ~ICACHE_resp_valid | Frontend_fifo_isfull;
    pc PC(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (PC_stall),

        .IAB_update_offest      (IAB_update_offest),
        .IAB_prefetch           (IAB_prefetch),

        .BPU_pred_flush         (BPU_pred_flush),
        .EX_mispred_flush       (EX_mispred_flush_i),
        .CSR_trap_flush         (CSR_trap_flush_i),

        .pc_o                   (PC_pc),
        .ICACHE_req_pc_o        (PC_ICACHE_req_pc)
    );

    // I-Cache 例化
    icache ICACHE(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (Frontend_fifo_isfull),
        .pipe_flush             (Frontend_flush_with_pred),

        .cpu_req_addr           (PC_ICACHE_req_pc),
        .cpu_req_prefetch       (IAB_prefetch),
        .cpu_req_update         (IAB_update_line),
        .cpu_resp_line          (ICACHE_resp_line),
        .cpu_resp_valid         (ICACHE_resp_valid),

        .perip_addr             (ICACHE_perip_addr),
        .perip_arvalid          (ICACHE_perip_arvalid),
        .perip_ren              (ICACHE_perip_ren),
        .perip_ready            (ICACHE_perip_ready),
        .perip_rdata            (ICACHE_perip_rdata),
        .perip_rvalid           (ICACHE_perip_rvalid)
    );

    // IAB 例化
    IAB IAB(
        .clk                    (clk),
        .rst                    (rst),
        .pipe_hold              (Frontend_fifo_isfull),
        .pipe_flush             (Frontend_flush_with_pred),

        .pc_i                   (PC_pc),
        .PC_update_offest_o     (IAB_update_offest),
        .ICACHE_prefetch_o      (IAB_prefetch),
        .ICACHE_update_line_o   (IAB_update_line),
        
        .line_i                 (ICACHE_resp_line),
        .line_valid_i           (ICACHE_resp_valid),
        .pc_o                   (IAB_pc),
        .inst_o                 (IAB_inst),
        .valid_o                (IAB_valid)
    );

    // BPU 例化
    always_ff @(posedge clk) begin
        if (rst) begin
            BPU_pc_r                    <= 0;
            BPU_inst_r                  <= 0;
            BPU_pc_next_r               <= 0;
            BPU_valid_r                 <= 0;
            BPU_gsahre_ghr_snapshot_r   <= 0;
        end else if (Frontend_fifo_isfull) begin
            // ...
        end else if (Frontend_flush_with_pred) begin
            BPU_pc_r                    <= 0;
            BPU_inst_r                  <= 0;
            BPU_pc_next_r               <= 0;
            BPU_valid_r                 <= 0;
            BPU_gsahre_ghr_snapshot_r   <= 0;
        end else begin
            BPU_pc_r                    <= IAB_pc;
            BPU_inst_r                  <= IAB_inst;
            BPU_pc_next_r               <= PC_pc;
            BPU_valid_r                 <= IAB_valid;
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

        .pc_early_i         (PC_pc),
        .pc_i               (IAB_pc),
        .inst_i             (IAB_inst),
        .valid_i            (IAB_valid),

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

    logic Frontend_fifo_valid;
    always_ff @(posedge clk) begin
        if (rst | Frontend_flush) begin
            Frontend_fifo_valid <= 1'b1;
        end else if (~Backend_ready_i) begin
            // ...
        end else begin
            Frontend_fifo_valid <= ~Frontend_fifo_isempty;
        end
    end

    assign valid_o = Backend_ready_i & Frontend_fifo_valid;

    // PerfCounter
    assign PerfCounter_pkg_o.icache_miss = ~ICACHE_resp_valid;

endmodule