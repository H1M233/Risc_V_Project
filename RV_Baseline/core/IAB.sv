`include "switch.svh"

module IAB(
    input  logic            clk                         ,
    input  logic            rst                         ,
    input  logic            pipe_hold                   ,
    input  logic            pipe_flush                  ,

    input  logic [31:0]     pc_i                        ,
    output logic [1:0]      PC_update_offest_o          ,
    output logic            ICACHE_prefetch_o           ,
    output logic            ICACHE_update_line_o        ,

    input  logic [255:0]    line_i                      ,
    input  logic            line_valid_i                ,
    output logic [31:0]     pc_o                        ,
    output logic [31:0]     inst_o                      ,
    output logic            valid_o                     
);
    logic        xline;
    logic        xline_valid;
    logic [15:0] xline_buffer;
    logic [3:0]  pc_offset;
    logic [31:0] cut_inst;

    assign xline              = pc_offset == 4'd15 && line_i[241:240] == 2'b11;
    assign pc_offset          = pc_i[4:1];
    assign cut_inst           = line_i[pc_offset*16 +: 32];
    assign PC_update_offest_o = (line_valid_i && !(xline && !xline_valid)) ? {cut_inst[1:0] == 2'b11 || xline_valid, 1'b1} : 2'b00;

    // 预取条件
    assign ICACHE_prefetch_o    = line_valid_i && (pc_offset >= 4'd8);
    assign ICACHE_update_line_o = ~line_valid_i | (cut_inst[1:0] == 2'b11 && pc_offset == 4'd14) | (pc_offset == 4'd15);

    // RVCExpander 例化
    logic [31:0] RVCE_expanded_inst;
    `ifdef ENABLE_C
        RVCExpander RVCExpander(
            .inst_i     (cut_inst),
            .inst_o     (RVCE_expanded_inst)
        );
    `else
        assign RVCE_expanded_inst = cut_inst;
    `endif

    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            xline_buffer    <= 16'b0;
            xline_valid     <= 1'b0;
        end else if (pipe_hold) begin
            // ...
        end else if (line_valid_i) begin
            xline_buffer    <= (!xline_valid) ? line_i[255:240] : 0;
            xline_valid     <= xline & !xline_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (rst | pipe_flush) begin
            pc_o            <= 32'b0;
            inst_o          <= 32'b0;
            valid_o         <= 1'b0;
        end else if (pipe_hold) begin
            // ...
        end else begin
            pc_o            <= pc_i;
            inst_o          <= (xline_valid) ? {line_i[15:0], xline_buffer} : RVCE_expanded_inst;
            valid_o         <= line_valid_i && !(xline && !xline_valid);
        end
    end

endmodule   