`include "alu_def.svh"

interface PerfCounter #(
    parameter COUNTER_WIDTH = 64
)(
    input  logic                        clk             , 
    input  logic                        rst             ,
    input  logic                        enable          ,
    input  logic                        event_pulse     ,
    input  logic                        wenl            ,
    input  logic                        wenh            ,
    input  logic [31:0]                 wdata           ,
    output logic [COUNTER_WIDTH - 1:0]  value           
);
    always_ff @(posedge clk) begin
        if (rst) begin
            value           <= 0;
        end else if (wenl) begin
            value[31:0]     <= wdata;
        end else if (wenh) begin
            value[63:32]    <= wdata;
        end else if (enable & event_pulse) begin
            value           <= value + 1'b1;
        end
    end

endinterface