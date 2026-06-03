`include "rv32I.vh"
`include "alu.vh"

module id_ex(
    input logic         clk,
    input logic         rst,

    input logic         pred_flush,
    input logic         hazard_en,
    input logic         dcache_stall,
    input logic         ecall_flush,
    input logic         mret_flush,
    input logic         dual_stall,
    input logic         dual_stall_r,

    // from id
    input data_t        slot0_data_packaged_i,
    input data_t        slot1_data_packaged_i,

    input decode_t      slot0_inst_packaged_i,
    input decode_t      slot1_inst_packaged_i,

    // to ex
    output data_t       slot0_data_packaged_o,
    output data_t       slot1_data_packaged_o,
    output decode_t     slot0_inst_packaged_o,
    output decode_t     slot1_inst_packaged_o,
    output logic        slot0_valid_o,
    output logic        slot1_valid_o
);
    wire id_ex_ecall_mret_flush = (ecall_flush | mret_flush);
    wire id_ex_hold_en  = dcache_stall;
    wire id_ex_flush_slot0_en_n = ~(pred_flush | hazard_en);
    wire id_ex_flush_slot1_en_n = ~(pred_flush | hazard_en | dual_stall | dual_stall_r);

    data_t slot0_data_packaged_changed;
    data_t slot1_data_packaged_changed;
    always_comb begin
        slot0_data_packaged_changed = slot0_data_packaged_i;
        slot1_data_packaged_changed = slot1_data_packaged_i;

        // changed
        slot0_data_packaged_changed.regs_wen = slot0_data_packaged_i.regs_wen & id_ex_flush_slot0_en_n;
        slot1_data_packaged_changed.regs_wen = slot1_data_packaged_i.regs_wen & id_ex_flush_slot1_en_n;
    end
    
    always_ff @(posedge clk) begin
        if(!rst) begin
            slot0_data_packaged_o <= 0;
            slot0_inst_packaged_o <= 0;
            slot0_valid_o         <= 0;

            slot1_data_packaged_o <= 0;
            slot1_inst_packaged_o <= 0;
            slot1_valid_o         <= 0;
        end
        else if (id_ex_ecall_mret_flush) begin
            slot0_data_packaged_o <= 0;
            slot0_inst_packaged_o <= 0;
            slot0_valid_o         <= 0;
            
            slot1_data_packaged_o <= 0;
            slot1_inst_packaged_o <= 0;
            slot1_valid_o         <= 0;
        end
        else if (id_ex_hold_en) begin
            // ..
        end
        else begin
            slot0_data_packaged_o   <= (dual_stall_r) ? slot1_data_packaged_changed : slot0_data_packaged_changed;
            slot0_inst_packaged_o   <= (id_ex_flush_slot0_en_n) ? (dual_stall_r) ? slot1_inst_packaged_i : slot0_inst_packaged_i : 0;
            slot0_valid_o           <= id_ex_flush_slot0_en_n;

            slot1_data_packaged_o   <= slot1_data_packaged_changed;
            slot1_inst_packaged_o   <= (id_ex_flush_slot1_en_n) ? slot1_inst_packaged_i : 0;
            slot1_valid_o           <= id_ex_flush_slot1_en_n;
        end
    end
endmodule