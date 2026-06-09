`include "rv32I.vh"
`include "alu.vh"

module id_ex(
    input logic         clk,
    input logic         rst,

    input logic         pred_flush,
    input logic         hazard_en,
    input logic         dcache_stall,
    input logic         ecall_mret_flush,
    input logic         dual_stall,
    output logic        dual_stall_finish,
    
    // from id
    input data_t        slot0_data_packaged_i,
    input data_t        slot1_data_packaged_i,
    
    input decode_t      slot0_inst_packaged_i,
    input decode_t      slot1_inst_packaged_i,
    
    input logic         slot0_regs_wen_i,
    input logic         slot1_regs_wen_i,

    // to ex
    output data_t       slot0_data_packaged_o,
    output data_t       slot1_data_packaged_o,
    output decode_t     slot0_inst_packaged_o,
    output decode_t     slot1_inst_packaged_o,
    output logic        slot0_regs_wen_o,
    output logic        slot1_regs_wen_o,
    output logic        slot0_valid_o,
    output logic        slot1_valid_o
);
    wire id_ex_hold_en  = dcache_stall;

    wire slot0_pred_taken_flush_slot1 = ~(dual_stall_send_slot1 & slot0_data_packaged_i.pred_taken);

    wire id_ex_flush_slot0_en_n = ~(pred_flush | hazard_en);
    wire id_ex_flush_slot1_en_n = ~(pred_flush | hazard_en | dual_stall | dual_stall_send_slot1 | slot0_data_packaged_i.pred_taken);

    logic dual_stall_send_slot0, dual_stall_send_slot1;
    assign dual_stall_send_slot0 = dual_stall;

    assign dual_stall_finish = ((dual_stall_swap_state == S_SWAP) & !dcache_stall & id_ex_flush_slot0_en_n) | pred_flush | ecall_mret_flush;
    
    logic [1:0] dual_stall_swap_state;
    localparam S_NORMAL = 1;
    localparam S_SWAP = 2;
    
    always_ff @(posedge clk) begin
        if (!rst) begin
            dual_stall_swap_state <= S_NORMAL;
            dual_stall_send_slot1 <= 0;
        end
        else if (ecall_mret_flush) begin
            dual_stall_swap_state <= S_NORMAL;
            dual_stall_send_slot1 <= 0;
        end
        else if (dcache_stall) begin
            // ...
        end
        else begin
            case (dual_stall_swap_state)
                S_NORMAL: begin
                    if (dual_stall & id_ex_flush_slot0_en_n) begin
                        dual_stall_send_slot1 <= 1;
                        dual_stall_swap_state <= S_SWAP;
                    end
                    else begin
                        dual_stall_send_slot1 <= 0;
                    end
                end
                S_SWAP: begin
                    if (id_ex_flush_slot0_en_n) begin
                        dual_stall_send_slot1 <= 0;
                        dual_stall_swap_state <= S_NORMAL;
                    end
                end
                default: dual_stall_swap_state <= S_NORMAL;
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_data_packaged_o <= 0;
            slot0_inst_packaged_o <= 0;
            slot0_regs_wen_o      <= 0;
            slot0_valid_o         <= 0;

            slot1_data_packaged_o <= 0;
            slot1_inst_packaged_o <= 0;
            slot1_regs_wen_o      <= 0;
            slot1_valid_o         <= 0;
        end
        else if (ecall_mret_flush) begin
            slot0_data_packaged_o <= 0;
            slot0_inst_packaged_o <= 0;
            slot0_regs_wen_o      <= 0;
            slot0_valid_o         <= 0;
            
            slot1_data_packaged_o <= 0;
            slot1_inst_packaged_o <= 0;
            slot1_regs_wen_o      <= 0;
            slot1_valid_o         <= 0;
        end
        else if (id_ex_hold_en) begin
            // ..
        end
        else begin
            slot0_data_packaged_o   <= (dual_stall_send_slot1) ? slot1_data_packaged_i : slot0_data_packaged_i;
            slot0_inst_packaged_o   <= (id_ex_flush_slot0_en_n & slot0_pred_taken_flush_slot1) ? (dual_stall_send_slot1) ? slot1_inst_packaged_i : slot0_inst_packaged_i : 0;
            slot0_regs_wen_o        <= (id_ex_flush_slot0_en_n & slot0_pred_taken_flush_slot1) ? (dual_stall_send_slot1) ? slot1_regs_wen_i : slot0_regs_wen_i : 0;
            slot0_valid_o           <= id_ex_flush_slot0_en_n & slot0_pred_taken_flush_slot1;

            slot1_data_packaged_o   <= slot1_data_packaged_i;
            slot1_inst_packaged_o   <= (id_ex_flush_slot1_en_n) ? slot1_inst_packaged_i : 0;
            slot1_regs_wen_o        <= (id_ex_flush_slot1_en_n) ? slot1_regs_wen_i : 0;
            slot1_valid_o           <= id_ex_flush_slot1_en_n;
        end
    end
endmodule