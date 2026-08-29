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
    
    // to id
    output reg [31:0]   forward_rs1_data,
    output reg          forward_rs1_en,
    output reg [31:0]   forward_rs2_data,
    output reg          forward_rs2_en,

    // to if_id, id_ex, pc
    output reg          hazard_en
);
    always@(*) begin
        hazard_en           = 1'b0;
        forward_rs1_en      = 1'b0;
        forward_rs2_en      = 1'b0;
        forward_rs1_data    = 32'b0;
        forward_rs2_data    = 32'b0;

        if((ex_waddr_i != 5'b0) && (ex_waddr_i == id_rs1_raddr_i)) begin
            if(opcode == `TYPE_L) begin
                hazard_en           = 1'b1;     // load-use冒险，暂停流水线
            end
            else begin
                forward_rs1_en      = 1'b1;     // 数据转发，解决数据冒险
                forward_rs1_data    = ex_wdata_i; 
            end
        end

        if((ex_waddr_i != 5'b0) && (ex_waddr_i == id_rs2_raddr_i)) begin
            if(opcode == `TYPE_L) begin
                hazard_en           = 1'b1;     // load-use冒险，暂停流水线
            end
            else begin
                forward_rs2_en      = 1'b1;     // 数据转发，解决数据冒险
                forward_rs2_data    = ex_wdata_i; 
            end
        end

        if(!forward_rs1_en) begin
            if((mem_waddr_i != 5'b0) && (mem_waddr_i == id_rs1_raddr_i)) begin
                forward_rs1_en      = 1'b1;     // 数据转发，解决数据冒险
                forward_rs1_data    = mem_wdata_i; 
            end
        end

        if(!forward_rs2_en) begin
            if((mem_waddr_i != 5'b0) && (mem_waddr_i == id_rs2_raddr_i)) begin
                forward_rs2_en      = 1'b1;     // 数据转发，解决数据冒险
                forward_rs2_data    = mem_wdata_i; 
            end
        end 
    end
endmodule