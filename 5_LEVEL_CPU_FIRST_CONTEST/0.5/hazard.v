`include "rv32I.vh"

module hazard(
    input      [4:0]    ex_waddr_i,
    input      [31:0]   ex_wdata_i,
    input      [6:0]    opcode,

    input      [4:0]    id_rs1_raddr_i,
    input      [4:0]    id_rs2_raddr_i,

    input      [4:0]    mem_waddr_i,
    input      [31:0]   mem_wdata_i,
    
    output reg [31:0]   forward_rs1_data,
    output reg          forward_rs1_en,
    output reg [31:0]   forward_rs2_data,
    output reg          forward_rs2_en,

    output reg          hazard_en
);

    wire ex_is_load;
    wire rs1_hit_ex;
    wire rs2_hit_ex;

    assign ex_is_load = opcode == `TYPE_L;

    assign rs1_hit_ex = (ex_waddr_i != 5'b0) &&
                        (ex_waddr_i == id_rs1_raddr_i);

    assign rs2_hit_ex = (ex_waddr_i != 5'b0) &&
                        (ex_waddr_i == id_rs2_raddr_i);

    always @(*) begin
        forward_rs1_en   = 1'b0;
        forward_rs2_en   = 1'b0;
        forward_rs1_data = 32'b0;
        forward_rs2_data = 32'b0;

        hazard_en = ex_is_load && (rs1_hit_ex || rs2_hit_ex);
    end

endmodule