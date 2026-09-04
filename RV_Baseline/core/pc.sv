`include "rv32I.svh"
`include "switch.svh"

module pc(
    input  logic        clk                     ,
    input  logic        rst                     ,
    input  logic        pipe_hold               ,

    // from RVCE
    `ifdef ENABLE_C
    input  logic        frontend_isCompressed   ,
    `endif

    // flush
    input  flush_t      BPU_pred_flush          ,
    input  flush_t      EX_mispred_flush        ,
    input  flush_t      CSR_trap_flush          ,

    // to I-Cache
    output logic [31:0] pc_o                    
);
    logic [31:0] pc_add_2_r;
    logic [31:0] pc_add_4_r;

    wire [31:0] pc_add_2 = pc_o + 32'd2;
    wire [31:0] pc_add_4 = pc_o + 32'd4;
    
    `ifdef ENABLE_C
    wire [31:0] pc_next  = (frontend_isCompressed) ? pc_add_2 : pc_add_4;
    `else
    wire [31:0] pc_next  = pc_add_4;
    `endif

    // 为冲刷 / 异常留的口
    logic        pc_flush_en;
    logic [31:0] pc_flush_sel;
    assign pc_flush_en = CSR_trap_flush.en | EX_mispred_flush.en | BPU_pred_flush.en;
    always_comb begin
        if (CSR_trap_flush.en) begin
            pc_flush_sel = CSR_trap_flush.pc;
        end else if (EX_mispred_flush.en) begin
            pc_flush_sel = EX_mispred_flush.pc;
        end else if (BPU_pred_flush.en) begin
            pc_flush_sel = BPU_pred_flush.pc;
        end else begin
            pc_flush_sel = 32'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pc_add_2_r  <= `IROM_ADDR_START;
            pc_add_4_r  <= `IROM_ADDR_START;
        end else begin
            if (pc_flush_en) begin
                pc_add_2_r <= pc_flush_sel;
                pc_add_4_r <= pc_flush_sel;
            end else if (pipe_hold) begin
                // ...
            end else begin
                pc_add_2_r <= pc_add_2;
                pc_add_4_r <= pc_add_4;
            end
        end
    end

    `ifdef ENABLE_C
    assign pc_o = (frontend_isCompressed) ? pc_add_2_r : pc_add_4_r;
    `else
    assign pc_o = pc_add_4_r;
    `endif
endmodule