`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module top_riscv(
    input           cpu_rst,
    input           cpu_clk,

    // from IROM
    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,

    // to DROM
    output  [31:0]  perip_addr,
    output  [3:0]   perip_we,
    output          perip_wen,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    // ============================================================
    // PC / I-cache
    // ============================================================
    wire [31:0]     pc_pc_addr_o;
    wire [31:0]     icache_inst;

    // ============================================================
    // pred_flusher
    // ============================================================
    (* max_fanout = 30 *)
    wire            pred_flush_en_r;
    (* max_fanout = 30 *)
    wire [31:0]     pred_flush_pc_r;

    // ============================================================
    // hazard / stall
    // ============================================================
    wire            hazard_hazard_en;
    wire            dcache_stall;

    // ============================================================
    // regs to id
    // ============================================================
    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    // ============================================================
    // if to if_id & bpu
    // ============================================================
    wire [31:0]     if1_pc_o;
    wire [31:0]     if2_pc_i;
    wire            if2_valid_i;
    wire [31:0]     if2_inst_o;
    wire [31:0]     if2_pc_o;

    // ============================================================
    // if_id to id
    // ============================================================
    wire [31:0]     id_inst_i;
    wire [31:0]     id_pc_i;

    // ============================================================
    // id to id_ex
    // ============================================================
    wire [31:0]     id_pc_addr_o;
    wire [31:0]     id_inst_o;
    wire [31:0]     id_value1_o;
    wire [31:0]     id_value2_o;
    wire [31:0]     id_jump1_o;
    wire [31:0]     id_jump2_o;
    wire            id_reg_wen;
    wire [31:0]     id_rs1_data_o;
    wire [31:0]     id_rs2_data_o;
    wire [4:0]      id_rs1_addr_o;
    wire [4:0]      id_rs2_addr_o;
    wire [4:0]      id_rd_addr_o;
    wire            id_pred_taken_o;
    wire [31:0]     id_pred_pc_o;
    wire [`OP_INST_NUM - 1:0] id_inst_packaged_o;

    // ============================================================
    // ex to dcache
    // ============================================================
    wire [31:0]     dcache_addr_i;
    wire            dcache_req_load_i;
    wire            dcache_req_store_i;
    wire [1:0]      dcache_mask_i;
    wire [31:0]     dcache_wdata_i;

    // ============================================================
    // id_ex to ex
    // ============================================================
    wire [31:0]     ex_pc_addr_i;
    wire            ex_regs_wen_i;
    wire [31:0]     ex_inst_i;
    wire [31:0]     ex_value1_i;
    wire [31:0]     ex_value2_i;
    wire [31:0]     ex_jump1_i;
    wire [31:0]     ex_jump2_i;
    wire [4:0]      ex_rd_addr_i;
    wire [4:0]      ex_rs1_addr_i;
    wire [4:0]      ex_rs2_addr_i;
    wire            ex_pred_taken_i;
    wire [31:0]     ex_pred_pc_i;
    wire            ex_valid_i;
    wire [`OP_INST_NUM - 1:0] ex_inst_packaged_i;

    wire            ex_fwd_rs1_hit_ex_i;
    wire            ex_fwd_rs2_hit_ex_i;
    wire [31:0]     ex_fwd_rs1_data_i;
    wire [31:0]     ex_fwd_rs2_data_i;
    wire [31:0]     ex_fwd_ex_rd_data_i;

    // ============================================================
    // ex to jump
    // ============================================================
    (* max_fanout = 30 *)
    wire            ex_pred_flush_en_o;
    (* max_fanout = 30 *)
    wire [31:0]     ex_pred_flush_pc_o;

    // ============================================================
    // ex to ex_mem
    // ============================================================
    wire            ex_regs_wen_o;
    wire [31:0]     ex_inst_o;
    wire [4:0]      ex_load_packaged_o;

    // ex to ex_mem & hazard
    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;
    wire            ex_req_load_o;

    // ============================================================
    // ex_mem to mem
    // ============================================================
    wire [31:0]     mem_inst_i;
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;
    wire            mem_req_load_i;
    wire [4:0]      mem_load_packaged_i;

    // ============================================================
    // mem to mem_wb
    // ============================================================
    wire [31:0]     mem_rd_data_o;
    wire [4:0]      mem_rd_addr_o;
    wire            mem_regs_wen_o;

    // ============================================================
    // mem to D-cache
    // ============================================================
    wire [31:0]     dcache_rdata;
    wire            dcache_ack_mem;

    // ============================================================
    // mem_wb to wb
    // ============================================================
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    // ============================================================
    // wb to regs
    // ============================================================
    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    // ============================================================
    // bpu to pc & id
    // ============================================================
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;

    // 流水线暂停条件
    (* max_fanout = 30 *)
    wire pipe_hold_icache = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_if1_if2 = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_if2_id = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_pred_flusher = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_bpu = dcache_stall | hazard_hazard_en;

    // ============================================================
    // ex to bpu
    // ============================================================
    wire            ex_pred_update_btb_en;
    wire            ex_pred_update_gshare_en;
    wire [31:0]     ex_pred_update_pc_o;
    wire [31:0]     ex_pred_update_target;
    wire            ex_actual_taken;

    // forwarding to id_ex
    wire            fwd_rs1_hit_ex_o;
    wire            fwd_rs2_hit_ex_o;
    wire [31:0]     fwd_rs1_data_o;
    wire [31:0]     fwd_rs2_data_o;
    wire [31:0]     fwd_ex_rd_data_o;

    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),

        .hazard_en          (hazard_hazard_en),

        .pred_flush_en      (pred_flush_en_r),
        .pred_flush_pc      (pred_flush_pc_r),

        .pc_addr_o          (pc_pc_addr_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken)
    );

    // ============================================================
    // I-cache
    // ============================================================
    `ifdef ENABLE_ICACHE
        icache ICACHE(
            .clk                (cpu_clk),
            .rst                (cpu_rst),

            .cpu_pc             (if1_pc_o),
            .cpu_inst           (icache_inst),
            .pipe_hold          (pipe_hold_icache),

            .mem_addr           (irom_addr),
            .mem_inst           (irom_data)
        );
    `else
        assign irom_addr = pc_pc_addr_o;

        reg [31:0] cpu_inst;
        always @(posedge cpu_clk) begin
            if (!pipe_hold_icache) begin
                cpu_inst <= irom_data;
            end
        end
        assign icache_inst = cpu_inst;
    `endif

    // ============================================================
    // Pred_flusher
    // ============================================================
    pred_flusher PRED_FLUSHER(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_pred_flusher),

        .pred_flush_en_i    (ex_pred_flush_en_o),
        .pred_flush_pc_i    (ex_pred_flush_pc_o),

        .pred_flush_en_r_o  (pred_flush_en_r),
        .pred_flush_pc_r_o  (pred_flush_pc_r)
    );

    // ============================================================
    // Hazard
    //
    // 关键修改：
    // mem_waddr_i 使用 mem_rd_addr_i
    // mem_wdata_i 使用 mem_rd_data_i
    //
    // 不再用 mem_rd_data_o，因为 mem_rd_data_o 对 load 会经过 DCache/DROM，
    // 那条路径就是现在的最差时序路径。
    // ============================================================
    hazard HAZARD(
        // from ex
        .ex_waddr_i         (ex_rd_addr_o),
        .ex_is_load         (ex_req_load_o),
        .ex_regs_wen_i      (ex_regs_wen_o),

        // from id
        .id_opcode_i        (id_inst_i[6:0]),
        .id_rs1_raddr_i     (id_rs1_addr_o),
        .id_rs2_raddr_i     (id_rs2_addr_o),

        // from mem
        .mem_waddr_i        (mem_rd_addr_i),
        .mem_regs_wen_i     (mem_regs_wen_i),

        // to if_id, id_ex, pc
        .hazard_en          (hazard_hazard_en)
    );

    // ============================================================
    // Regfile
    // ============================================================
    regs REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (wb_rd_addr_o),
        .rd_data_i          (wb_rd_data_o),
        .regs_wen           (wb_regs_wen_o),

        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),

        .rs1_data_o         (reg_rs1_data_o),
        .rs2_data_o         (reg_rs2_data_o)
    );

    // ============================================================
    // IF
    // ============================================================
    if1 IF1(
        .pc_i               (pc_pc_addr_o),
        .pred_flush         (pred_flush_en_r),

        .pc_o               (if1_pc_o)
    );

    if1_if2 IF1_IF2(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pred_taken         (bpu_pred_taken),
        .pred_flush         (pred_flush_en_r),
        .pipe_hold          (pipe_hold_if1_if2),

        .pc_i               (if1_pc_o),

        .if2_valid_o        (if2_valid_i),
        .pc_o               (if2_pc_i)
    );

    if2 IF2(
        .inst_i             (icache_inst),
        .pred_flush_r       (pred_flush_en_r),

        .if2_valid_i        (if2_valid_i),
        .pc_i               (if2_pc_i),

        .inst_o             (if2_inst_o),
        .pc_o               (if2_pc_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    if2_id IF2_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_if2_id),

        .inst_i             (if2_inst_o),
        .pc_i               (if2_pc_o),

        .pred_taken         (bpu_pred_taken),

        .inst_o             (id_inst_i),
        .pc_o               (id_pc_i)
    );

    // ============================================================
    // ID
    // ============================================================
    id ID(
        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_i),

        .pred_taken_i       (bpu_pred_taken),
        .pred_pc_i          (bpu_pred_pc),

        .rs1_data_i         (reg_rs1_data_o),
        .rs2_data_i         (reg_rs2_data_o),

        .pc_addr_o          (id_pc_addr_o),
        .inst_o             (id_inst_o),
        .jump1_o            (id_jump1_o),
        .jump2_o            (id_jump2_o),
        .rd_addr_o          (id_rd_addr_o),
        .reg_wen            (id_reg_wen),
        .rs1_data_o         (id_rs1_data_o),
        .rs2_data_o         (id_rs2_data_o),
        .value1_o           (id_value1_o),
        .value2_o           (id_value2_o),
        .pred_taken_o       (id_pred_taken_o),
        .pred_pc_o          (id_pred_pc_o),
        .inst_packaged_o    (id_inst_packaged_o),

        .rs1_addr_o         (id_rs1_addr_o),
        .rs2_addr_o         (id_rs2_addr_o)
    );

    // ============================================================
    // ID/EX
    // ============================================================
    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),

        .pred_flush         (ex_pred_flush_en_o),
        .pred_flush_r       (pred_flush_en_r),
        .hazard_en          (hazard_hazard_en),

        .pc_addr_i          (id_pc_addr_o),
        .inst_i             (id_inst_o),
        .jump1_i            (id_jump1_o),
        .jump2_i            (id_jump2_o),
        .rd_addr_i          (id_rd_addr_o),
        .regs_wen_i         (id_reg_wen),
        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),
        .value1_i           (id_value1_o),
        .value2_i           (id_value2_o),
        .pred_taken_i       (id_pred_taken_o),
        .pred_pc_i          (id_pred_pc_o),
        .inst_packaged_i    (id_inst_packaged_o),

        .fwd_rs1_hit_ex_i   (fwd_rs1_hit_ex_o),
        .fwd_rs2_hit_ex_i   (fwd_rs2_hit_ex_o),
        .fwd_rs1_data_i     (fwd_rs1_data_o),
        .fwd_rs2_data_i     (fwd_rs2_data_o),
        .fwd_ex_rd_data_i   (fwd_ex_rd_data_o),

        .pc_addr_o          (ex_pc_addr_i),
        .inst_o             (ex_inst_i),
        .jump1_o            (ex_jump1_i),
        .jump2_o            (ex_jump2_i),
        .rd_addr_o          (ex_rd_addr_i),
        .regs_wen_o         (ex_regs_wen_i),
        .rs1_addr_o         (ex_rs1_addr_i),
        .rs2_addr_o         (ex_rs2_addr_i),
        .value1_o           (ex_value1_i),
        .value2_o           (ex_value2_i),
        .pred_taken_o       (ex_pred_taken_i),
        .pred_pc_o          (ex_pred_pc_i),
        .inst_packaged_o    (ex_inst_packaged_i),
        .valid_o            (ex_valid_i),

        .fwd_rs1_hit_ex_o   (ex_fwd_rs1_hit_ex_i),
        .fwd_rs2_hit_ex_o   (ex_fwd_rs2_hit_ex_i),
        .fwd_rs1_data_o     (ex_fwd_rs1_data_i),
        .fwd_rs2_data_o     (ex_fwd_rs2_data_i),
        .fwd_ex_rd_data_o   (ex_fwd_ex_rd_data_i)
    );

    // ============================================================
    // EX
    // ============================================================
    ex EX(
        .pc_addr_i          (ex_pc_addr_i),
        .inst_i             (ex_inst_i),
        .jump1_i            (ex_jump1_i),
        .jump2_i            (ex_jump2_i),
        .rd_addr_i          (ex_rd_addr_i),
        .regs_wen_i         (ex_regs_wen_i),
        .value1_i           (ex_value1_i),
        .value2_i           (ex_value2_i),
        .pred_taken_i       (ex_pred_taken_i),
        .pred_pc_i          (ex_pred_pc_i),
        .inst_packaged_i    (ex_inst_packaged_i),
        .valid_i            (ex_valid_i),

        .inst_o             (ex_inst_o),
        .regs_wen_o         (ex_regs_wen_o),
        .load_packaged_o    (ex_load_packaged_o),

        .rd_addr_o          (ex_rd_addr_o),
        .rd_data_o          (ex_rd_data_o),
        .mem_req_load_o     (ex_req_load_o),

        .pred_flush_en      (ex_pred_flush_en_o),
        .pred_flush_pc      (ex_pred_flush_pc_o),

        .update_btb_en_o    (ex_pred_update_btb_en),
        .update_gshare_en_o (ex_pred_update_gshare_en),
        .update_pc_o        (ex_pred_update_pc_o),
        .update_target_o    (ex_pred_update_target),
        .actual_taken_o     (ex_actual_taken),

        .dcache_req_load    (dcache_req_load_i),
        .dcache_req_store   (dcache_req_store_i),
        .dcache_mask        (dcache_mask_i),
        .dcache_addr        (dcache_addr_i),
        .dcache_wdata       (dcache_wdata_i),

        .fwd_rs1_data_i     (ex_fwd_rs1_data_i),
        .fwd_rs2_data_i     (ex_fwd_rs2_data_i),
        .fwd_rs1_hit_ex_i   (ex_fwd_rs1_hit_ex_i),
        .fwd_rs2_hit_ex_i   (ex_fwd_rs2_hit_ex_i),
        .fwd_ex_rd_data_i   (ex_fwd_ex_rd_data_i)
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .inst_i             (ex_inst_o),
        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),
        .mem_req_load_i     (ex_req_load_o),
        .load_packaged_i    (ex_load_packaged_o),

        .inst_o             (mem_inst_i),
        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i),
        .mem_req_load_o     (mem_req_load_i),
        .load_packaged_o    (mem_load_packaged_i)
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM(
        .inst_i             (mem_inst_i),
        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),
        .mem_req_load_i     (mem_req_load_i),
        .load_packaged_i    (mem_load_packaged_i),

        .perip_rdata        (dcache_rdata),

        .rd_data_o          (mem_rd_data_o),
        .regs_wen_o         (mem_regs_wen_o),

        .rd_addr_o          (mem_rd_addr_o),

        .dcache_ack         (dcache_ack_mem)
    );

    // ============================================================
    // D-cache
    // ============================================================
    `ifdef ENABLE_DCACHE
        dcache DCACHE(
            .clk                (cpu_clk),
            .rst                (cpu_rst),

            .cpu_req_load       (dcache_req_load_i),
            .cpu_req_store      (dcache_req_store_i),
            .cpu_mask           (dcache_mask_i),
            .cpu_addr           (dcache_addr_i),
            .cpu_wdata          (dcache_wdata_i),
            .cpu_rdata          (dcache_rdata),
            .stall              (dcache_stall),

            .mem_addr           (perip_addr),
            .mem_we             (perip_we),
            .mem_wen            (perip_wen),
            .mem_wdata          (perip_wdata),
            .mem_rdata          (perip_rdata),

            .mem_ack            (dcache_ack_mem)
        );
    `else
        assign dcache_stall = 1'b0;

        wire [1:0] addr_low = dcache_addr_i[1:0];

        reg [1:0] mask_r;
        reg [1:0] addr_low_r;
        always @(posedge cpu_clk) begin
            mask_r <= dcache_mask_i;
            addr_low_r <= addr_low;
        end

        assign perip_addr = dcache_addr_i;
        assign perip_we = dcache_req_store_i ? unmask(dcache_mask_i, addr_low) : 4'b0;
        assign perip_wen = dcache_req_store_i;
        assign perip_wdata = store_merge(32'b0, dcache_wdata_i, addr_low, dcache_mask_i);
        assign dcache_rdata = load_shift(perip_rdata, addr_low_r, mask_r);

        assign dcache_ack_mem = 1'b1;

        // fuction
        function [3:0] unmask;
        input [1:0] mask;
        input [1:0] addr_low;
        begin
            case (mask)
                2'b00: begin
                    case (addr_low)
                        2'b00: unmask = 4'b0001;
                        2'b01: unmask = 4'b0010;
                        2'b10: unmask = 4'b0100;
                        2'b11: unmask = 4'b1000;
                    endcase
                end
                2'b01: begin
                    case (addr_low[1])
                        1'b0: unmask = 4'b0011;
                        1'b1: unmask = 4'b1100;
                    endcase
                end
                2'b10: unmask = 4'b1111;
            endcase
        end
    endfunction
    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            case(mask)
                // byte
                2'b00: begin
                    case(addr_low)
                        2'b00: load_shift = {24'b0, word[7:0]};
                        2'b01: load_shift = {24'b0, word[15:8]};
                        2'b10: load_shift = {24'b0, word[23:16]};
                        2'b11: load_shift = {24'b0, word[31:24]};
                    endcase
                end
                // half word
                2'b01: begin
                    if(addr_low[1])
                        load_shift = {16'b0, word[31:16]};
                    else
                        load_shift = {16'b0, word[15:0]};
                end
                // word
                2'b10: begin
                    load_shift = word;
                end
                default: begin
                    load_shift = word;
                end
            endcase
        end
    endfunction
    function [31:0] store_merge;
        input [31:0] old_word;
        input [31:0] wdata;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            store_merge = old_word;
            case(mask)
                // SB
                2'b00: begin
                    case(addr_low)
                        2'b00: store_merge[7:0]   = wdata[7:0];
                        2'b01: store_merge[15:8]  = wdata[7:0];
                        2'b10: store_merge[23:16] = wdata[7:0];
                        2'b11: store_merge[31:24] = wdata[7:0];
                    endcase
                end
                // SH
                2'b01: begin
                    if(addr_low[1])
                        store_merge[31:16] = wdata[15:0];
                    else
                        store_merge[15:0]  = wdata[15:0];
                end
                // SW
                2'b10: begin
                    store_merge = wdata;
                end
                default: begin
                    store_merge = old_word;
                end
            endcase
        end
    endfunction
    `endif

    // ============================================================
    // MEM/WB
    // ============================================================
    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (mem_rd_addr_o),
        .rd_data_i          (mem_rd_data_o),
        .regs_wen_i         (mem_regs_wen_o),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i)
    );

    // ============================================================
    // WB
    // ============================================================
    wb WB(
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),

        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o)
    );

    // ============================================================
    // BPU
    // ============================================================
    bpu_top #(
        .BHR_WIDTH  (10),
        .PHT_SIZE   (1024),
        .RAS_DEPTH  (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pc_addr            (if1_pc_o),
        .pc_inst            (if2_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .update_pc          (ex_pred_update_pc_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),

        .pipe_hold          (pipe_hold_bpu),
        .pred_flush_r       (pred_flush_en_r)
    );

    // forwarding
    forwarding FWD(
        // from id
        .id_rs1_addr_i      (id_rs1_addr_o),
        .id_rs2_addr_i      (id_rs2_addr_o),
        .id_rs1_data_i      (id_rs1_data_o),
        .id_rs2_data_i      (id_rs2_data_o),

        // from ex
        .ex_regs_wen_i      (ex_regs_wen_o),
        .ex_rd_addr_i       (ex_rd_addr_o),
        .ex_rd_data_i       (ex_rd_data_o),

        // from mem
        .mem_regs_wen_i     (mem_regs_wen_o),
        .mem_rd_addr_i      (mem_rd_addr_o),
        .mem_rd_data_i      (mem_rd_data_o),

        // from wb
        .wb_regs_wen_i      (wb_regs_wen_i), 
        .wb_rd_addr_i       (wb_rd_addr_i),
        .wb_rd_data_i       (wb_rd_data_i),

        // to ex
        .forwarding_rs1_data_o      (fwd_rs1_data_o),
        .forwarding_rs2_data_o      (fwd_rs2_data_o),
        .forwarding_rs1_hit_ex_o    (fwd_rs1_hit_ex_o),
        .forwarding_rs2_hit_ex_o    (fwd_rs2_hit_ex_o),
        .forwarding_ex_rd_data_o    (fwd_ex_rd_data_o)
);

endmodule