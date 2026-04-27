`include "rv32I.vh"

module hazard(
    // from ex
    input      [4:0]    ex_waddr_i,
    input      [31:0]   ex_wdata_i,
    input      [6:0]    opcode,

    // from id
    input      [4:0]    id_rs1_raddr_i,
    input      [4:0]    id_rs2_raddr_i,

    // from mem
    input      [4:0]    mem_waddr_i,
    input      [31:0]   mem_wdata_i,
    input               mem_is_load,
    
    // to id
    output reg [31:0]   forward_rs1_data,
    output reg          forward_rs1_en,
    output reg [31:0]   forward_rs2_data,
    output reg          forward_rs2_en,

    // to if_id, id_ex, pc
    output              hazard_en
);
    wire ex_is_load;

    wire ex_rs1_hit;
    wire ex_rs2_hit;
    wire mem_rs1_hit;
    wire mem_rs2_hit;

    assign ex_is_load = (opcode == `TYPE_L);

    assign ex_rs1_hit  = (ex_waddr_i  != 5'b0) && (ex_waddr_i  == id_rs1_raddr_i);
    assign ex_rs2_hit  = (ex_waddr_i  != 5'b0) && (ex_waddr_i  == id_rs2_raddr_i);

    assign mem_rs1_hit = (mem_waddr_i != 5'b0) && (mem_waddr_i == id_rs1_raddr_i);
    assign mem_rs2_hit = (mem_waddr_i != 5'b0) && (mem_waddr_i == id_rs2_raddr_i);

    // EX 阶段是 load，下一条要用，停顿
    // MEM 阶段是 load，也停顿，不再从 MEM 阶段把 load 数据前递回 ID
    assign hazard_en = (ex_is_load  && (ex_rs1_hit  || ex_rs2_hit)) ||
                       (mem_is_load && (mem_rs1_hit || mem_rs2_hit));

    always @(*) begin
        forward_rs1_en   = 1'b0;
        forward_rs1_data = 32'b0;

        // EX 阶段非 load 可以前递
        if(ex_rs1_hit && !ex_is_load) begin
            forward_rs1_en   = 1'b1;
            forward_rs1_data = ex_wdata_i;
        end
        // MEM 阶段非 load 可以前递
        // MEM 阶段 load 不前递，避免 RAM/DCache -> ID_EX 的长路径
        else if(mem_rs1_hit && !mem_is_load) begin
            forward_rs1_en   = 1'b1;
            forward_rs1_data = mem_wdata_i;
        end
    end

    always @(*) begin
        forward_rs2_en   = 1'b0;
        forward_rs2_data = 32'b0;

        if(ex_rs2_hit && !ex_is_load) begin
            forward_rs2_en   = 1'b1;
            forward_rs2_data = ex_wdata_i;
        end
        else if(mem_rs2_hit && !mem_is_load) begin
            forward_rs2_en   = 1'b1;
            forward_rs2_data = mem_wdata_i;
        end
    end

endmodule