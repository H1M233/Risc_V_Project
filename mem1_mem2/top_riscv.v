`include "rv32I.vh"

module top_riscv(
    input           cpu_rst,
    input           cpu_clk,

    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,

    output  [31:0]  perip_addr,
    output          perip_wen,
    output  [1:0]   perip_mask,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    wire [31:0]     pc_pc_addr_o;
    assign irom_addr = pc_pc_addr_o;

    wire            jump_jump_en_o;
    wire [31:0]     jump_jump_addr_o;

    wire            hazard_hazard_en;

    wire            hazard_forward_rs1_en;
    wire            hazard_forward_rs2_en;
    wire [31:0]     hazard_forward_rs1_data;
    wire [31:0]     hazard_forward_rs2_data;

    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    wire [31:0]     if_pc_addr_o;
    wire [31:0]     if_inst_o;

    wire [31:0]     id_pc_addr_i;
    wire [31:0]     id_inst_i;

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

    wire [31:0]     ex_pc_addr_i;
    wire            ex_regs_wen_i;
    wire [31:0]     ex_inst_i;
    wire [31:0]     ex_value1_i;
    wire [31:0]     ex_value2_i;
    wire [31:0]     ex_jump1_i;
    wire [31:0]     ex_jump2_i;
    wire [4:0]      ex_rd_addr_i;
    wire [31:0]     ex_rs1_data_i;
    wire [31:0]     ex_rs2_data_i;
    wire            ex_pred_taken_i;
    wire [31:0]     ex_pred_pc_i;

    wire            ex_jump_en_o;
    wire [31:0]     ex_jump_addr_o;

    wire            ex_regs_wen_o;
    wire [31:0]     ex_inst_o;
    wire            ex_mem_wen;
    wire            ex_mem_req;
    wire [31:0]     ex_mem_addr_o;
    wire [31:0]     ex_rs2_data_o;

    wire [6:0]      ex_hazard_opcode_o;

    wire [31:0]     ex_rs1_data_o;

    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;

    wire [31:0]     mem_inst_i;
    wire            mem_mem_wen_i;
    wire            mem_mem_req_i;
    wire [31:0]     mem_mem_addr_i;
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;
    wire [31:0]     mem_rs2_data_i;

    wire [31:0]     mem_inst_o;
    wire [4:0]      mem_rd_addr_o;
    wire [31:0]     mem_alu_data_o;
    wire [31:0]     mem_raw_data_o;
    wire            mem_regs_wen_o;

    wire [31:0]     mem2_inst_i;
    wire [4:0]      mem2_rd_addr_i;
    wire [31:0]     mem2_alu_data_i;
    wire [31:0]     mem2_raw_data_i;
    wire            mem2_regs_wen_i;

    wire [4:0]      mem2_rd_addr_o;
    wire [31:0]     mem2_rd_data_o;
    wire            mem2_regs_wen_o;

    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    reg  [4:0]      prev_wb_rd_addr;
    reg  [31:0]     prev_wb_rd_data;
    reg             prev_wb_regs_wen;

    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;

    wire            ex_pred_update_btb_en;
    wire            ex_pred_update_gshare_en;
    wire [31:0]     ex_pc_addr_o;
    wire [31:0]     ex_pred_update_target;
    wire            ex_actual_taken;
    wire            ex_pred_mispredict;

    always @(posedge cpu_clk) begin
        if (!cpu_rst) begin
            prev_wb_rd_addr  <= 5'b0;
            prev_wb_rd_data  <= 32'b0;
            prev_wb_regs_wen <= 1'b0;
        end
        else begin
            prev_wb_rd_addr  <= wb_rd_addr_i;
            prev_wb_rd_data  <= wb_rd_data_i;
            prev_wb_regs_wen <= wb_regs_wen_i;
        end
    end

    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .hazard_en          (hazard_hazard_en),

        .jump_addr_i        (jump_jump_addr_o),
        .jump_en            (jump_jump_en_o),

        .pc_addr_o          (pc_pc_addr_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken)
    );

    jump JUMP(
        .jump_addr_i        (ex_jump_addr_o),
        .jump_en_i          (ex_jump_en_o),

        .jump_addr_o        (jump_jump_addr_o),
        .jump_en_o          (jump_jump_en_o)
    );

    hazard HAZARD(
        .ex_waddr_i         (ex_rd_addr_o),
        .ex_wdata_i         (ex_rd_data_o),
        .opcode             (ex_hazard_opcode_o),

        .id_rs1_raddr_i     (id_rs1_addr_o),
        .id_rs2_raddr_i     (id_rs2_addr_o),

        .mem_waddr_i        (mem2_rd_addr_o),
        .mem_wdata_i        (mem2_rd_data_o),

        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        .hazard_en          (hazard_hazard_en)
    );

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

    ifif IFIF(
        .inst_i             (irom_data),

        .pc_addr_i          (pc_pc_addr_o),

        .inst_o             (if_inst_o),
        .pc_addr_o          (if_pc_addr_o)
    );

    if_id IF_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .hazard_en          (hazard_hazard_en),

        .inst_i             (if_inst_o),
        .pc_addr_i          (if_pc_addr_o),

        .jump_en            (jump_jump_en_o),

        .inst_o             (id_inst_i),
        .pc_addr_o          (id_pc_addr_i),

        .pred_taken         (bpu_pred_taken)
    );

    id ID(
        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_addr_i),

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

        .rs1_addr_o         (id_rs1_addr_o),
        .rs2_addr_o         (id_rs2_addr_o)
    );

    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .hazard_en          (hazard_hazard_en),

        .pc_addr_i          (id_pc_addr_o),
        .inst_i             (id_inst_o),
        .jump1_i            (id_jump1_o),
        .jump2_i            (id_jump2_o),
        .rd_addr_i          (id_rd_addr_o),
        .regs_wen_i         (id_reg_wen),
        .rs1_data_i         (id_rs1_data_o),
        .rs2_data_i         (id_rs2_data_o),
        .value1_i           (id_value1_o),
        .value2_i           (id_value2_o),
        .pred_taken_i       (id_pred_taken_o),
        .pred_pc_i          (id_pred_pc_o),

        .jump_en            (jump_jump_en_o),

        .pc_addr_o          (ex_pc_addr_i),
        .inst_o             (ex_inst_i),
        .jump1_o            (ex_jump1_i),
        .jump2_o            (ex_jump2_i),
        .rd_addr_o          (ex_rd_addr_i),
        .regs_wen_o         (ex_regs_wen_i),
        .rs1_data_o         (ex_rs1_data_i),
        .rs2_data_o         (ex_rs2_data_i),
        .value1_o           (ex_value1_i),
        .value2_o           (ex_value2_i),
        .pred_taken_o       (ex_pred_taken_i),
        .pred_pc_o          (ex_pred_pc_i)
    );

    ex EX(
        .pc_addr_i                  (ex_pc_addr_i),
        .inst_i                     (ex_inst_i),
        .jump1_i                    (ex_jump1_i),
        .jump2_i                    (ex_jump2_i),
        .rd_addr_i                  (ex_rd_addr_i),
        .regs_wen_i                 (ex_regs_wen_i),
        .rs1_data_i                 (ex_rs1_data_i),
        .rs2_data_i                 (ex_rs2_data_i),
        .value1_i                   (ex_value1_i),
        .value2_i                   (ex_value2_i),
        .pred_taken_i               (ex_pred_taken_i),
        .pred_pc_i                  (ex_pred_pc_i),

        .mem_forward_rd_addr_i      (mem_rd_addr_i),
        .mem_forward_rd_data_i      (mem_rd_data_i),
        .mem_forward_regs_wen_i     (mem_regs_wen_i),
        .mem_forward_opcode_i       (mem_inst_i[6:0]),

        .mem2_forward_rd_addr_i     (mem2_rd_addr_o),
        .mem2_forward_rd_data_i     (mem2_rd_data_o),
        .mem2_forward_regs_wen_i    (mem2_regs_wen_o),

        .wb_forward_rd_addr_i       (wb_rd_addr_i),
        .wb_forward_rd_data_i       (wb_rd_data_i),
        .wb_forward_regs_wen_i      (wb_regs_wen_i),

        .prev_wb_forward_rd_addr_i  (prev_wb_rd_addr),
        .prev_wb_forward_rd_data_i  (prev_wb_rd_data),
        .prev_wb_forward_regs_wen_i (prev_wb_regs_wen),

        .hazard_opcode              (ex_hazard_opcode_o),

        .inst_o                     (ex_inst_o),
        .mem_addr_o                 (ex_mem_addr_o),
        .mem_req                    (ex_mem_req),
        .mem_wen                    (ex_mem_wen),
        .regs_wen_o                 (ex_regs_wen_o),
        .rs2_data_o                 (ex_rs2_data_o),

        .rd_addr_o                  (ex_rd_addr_o),
        .rd_data_o                  (ex_rd_data_o),

        .jump_addr_o                (ex_jump_addr_o),
        .jump_en                    (ex_jump_en_o),

        .rs1_data_o                 (ex_rs1_data_o),

        .update_btb_en              (ex_pred_update_btb_en),
        .update_gshare_en           (ex_pred_update_gshare_en),
        .pc_addr_o                  (ex_pc_addr_o),
        .update_target              (ex_pred_update_target),
        .actual_taken               (ex_actual_taken),
        .pred_mispredict            (ex_pred_mispredict)
    );

    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .inst_i             (ex_inst_o),
        .mem_addr_i         (ex_mem_addr_o),
        .mem_req_i          (ex_mem_req),
        .mem_wen_i          (ex_mem_wen),
        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),
        .rs2_data_i         (ex_rs2_data_o),

        .inst_o             (mem_inst_i),
        .mem_addr_o         (mem_mem_addr_i),
        .mem_req_o          (mem_mem_req_i),
        .mem_wen_o          (mem_mem_wen_i),
        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i),
        .rs2_data_o         (mem_rs2_data_i)
    );

    mem MEM(
        .inst_i             (mem_inst_i),
        .mem_addr_i         (mem_mem_addr_i),
        .mem_req            (mem_mem_req_i),
        .mem_wen            (mem_mem_wen_i),
        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),
        .rs2_data_i         (mem_rs2_data_i),

        .perip_rdata        (perip_rdata),

        .perip_addr         (perip_addr),
        .perip_mask         (perip_mask),
        .perip_wdata        (perip_wdata),
        .perip_wen          (perip_wen),

        .inst_o             (mem_inst_o),
        .rd_addr_o          (mem_rd_addr_o),
        .alu_data_o         (mem_alu_data_o),
        .mem_data_o         (mem_raw_data_o),
        .regs_wen_o         (mem_regs_wen_o)
    );

    mem1_mem2 MEM1_MEM2(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .inst_i             (mem_inst_o),
        .rd_addr_i          (mem_rd_addr_o),
        .alu_data_i         (mem_alu_data_o),
        .mem_data_i         (mem_raw_data_o),
        .regs_wen_i         (mem_regs_wen_o),

        .inst_o             (mem2_inst_i),
        .rd_addr_o          (mem2_rd_addr_i),
        .alu_data_o         (mem2_alu_data_i),
        .mem_data_o         (mem2_raw_data_i),
        .regs_wen_o         (mem2_regs_wen_i)
    );

    mem2 MEM2(
        .inst_i             (mem2_inst_i),
        .rd_addr_i          (mem2_rd_addr_i),
        .alu_data_i         (mem2_alu_data_i),
        .mem_data_i         (mem2_raw_data_i),
        .regs_wen_i         (mem2_regs_wen_i),

        .rd_addr_o          (mem2_rd_addr_o),
        .rd_data_o          (mem2_rd_data_o),
        .regs_wen_o         (mem2_regs_wen_o)
    );

    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (mem2_rd_addr_o),
        .rd_data_i          (mem2_rd_data_o),
        .regs_wen_i         (mem2_regs_wen_o),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i)
    );

    wb WB(
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),

        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o)
    );

    bpu_top #(
        .BHR_WIDTH          (10),
        .PHT_SIZE           (1024),
        .RAS_DEPTH          (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pc_addr            (if_pc_addr_o),
        .pc_inst            (if_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .update_pc          (ex_pc_addr_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),
        .pred_mispredict    (ex_pred_mispredict),
        .hazard_en          (hazard_hazard_en)
    );

endmodule