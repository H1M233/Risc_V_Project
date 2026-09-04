`include "rv32I.svh"
module RVCExpander(
    input  logic [31:0]     inst_i      ,
    output logic [31:0]     inst_o      
);
    wire [15:0]  compressed_inst       = inst_i[15:0];
    wire [2:0]   compressed_inst_funct = inst_i[15:13];
    wire [1:0]   inst_low2             = inst_i[1:0];
    logic [31:0] translated_inst;

    assign inst_o = translated_inst;

    always_comb begin
        case (inst_low2)
            2'b00 : begin
                case (compressed_inst_funct)
                    3'b000 : begin
                        if (compressed_inst[12:2] == 0) begin
                            translated_inst = `NOP; // 非法指令
                        end else begin
                            translated_inst = {   // C.ADDI4SPN
                                2'b0,                           // imm[11:10]
                                compressed_inst[10:7],          // imm[9:6]
                                compressed_inst[12:11],         // imm[5:4]
                                compressed_inst[5],             // imm[3]
                                compressed_inst[6],             // imm[2]
                                2'b0,                           // imm[1:0]
                                5'd2,                           // rs1
                                3'b000,                         // funct3
                                2'b01, compressed_inst[4:2],    // rd
                                `TYPE_I                         // opcode
                            };
                        end
                    end

                    3'b010 : translated_inst = {   // C.LW
                        5'b0,                           // imm[11:7]
                        compressed_inst[5],             // imm[6]
                        compressed_inst[12:10],         // imm[5:3]
                        compressed_inst[6],             // imm[2]
                        2'b0,                           // imm[1:0]
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b010,                         // funct3
                        2'b01, compressed_inst[4:2],    // rd
                        `TYPE_L                         // opcode
                    };

                    3'b011 : translated_inst = {   // C.FLW
                        5'b0,                           // imm[11:7]
                        compressed_inst[5],             // imm[6]
                        compressed_inst[12:10],         // imm[5:3]
                        compressed_inst[6],             // imm[2]
                        2'b0,                           // imm[1:0]
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b010,                         // funct3
                        2'b01, compressed_inst[4:2],    // rd
                        `TYPE_LOAD_FP                   // opcode
                    };

                    3'b110 : translated_inst = {   // C.SW
                        5'b0,                           // imm[11:7]
                        compressed_inst[5],             // imm[6]
                        compressed_inst[12],            // imm[5]
                        2'b01, compressed_inst[4:2],    // rs2
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:10],         // imm[4:3]
                        compressed_inst[6],             // imm[2]
                        2'b0,                           // imm[1:0]
                        `TYPE_S                         // opcode
                    };

                    3'b111 : translated_inst = {   // C.FSW
                        5'b0,                           // imm[11:7]
                        compressed_inst[5],             // imm[6]
                        compressed_inst[12],            // imm[5]
                        2'b01, compressed_inst[4:2],    // rs2
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:10],         // imm[4:3]
                        compressed_inst[6],             // imm[2]
                        2'b0,                           // imm[1:0]
                        `TYPE_STORE_FP                  // opcode
                    };
                    default : translated_inst = 32'b0;
                endcase
            end

            2'b01 : begin
                case (compressed_inst_funct)
                    3'b000 : begin
                        if (compressed_inst[12:2] == 0) begin
                            translated_inst = `NOP;
                        end else begin
                            translated_inst = { // C.ADDI
                                {6{compressed_inst[12]}},   // imm[11:6]
                                compressed_inst[12],        // imm[5]
                                compressed_inst[6:2],       // imm[4:0]
                                compressed_inst[11:7],      // rs1
                                3'b000,                     // funct3
                                compressed_inst[11:7],      // rd
                                `TYPE_I                     // opcode
                            };
                        end
                    end

                    3'b001 : translated_inst = { // C.JAL
                        compressed_inst[12],            // imm[20]
                        compressed_inst[8],             // imm[10]
                        compressed_inst[10:9],          // imm[9:8]
                        compressed_inst[6],             // imm[7]
                        compressed_inst[7],             // imm[6]
                        compressed_inst[2],             // imm[5]
                        compressed_inst[11],            // imm[4]
                        compressed_inst[5:3],           // imm[3:1]
                        compressed_inst[12],            // imm[11]
                        {8{compressed_inst[12]}},       // imm[19:12]
                        5'd1,                           // rd
                        `JAL                            // opcode
                    };

                    3'b010 : translated_inst = { // C.LI
                        {6{compressed_inst[12]}},       // imm[11:6]
                        compressed_inst[12],            // imm[5]
                        compressed_inst[6:2],           // imm[4:0]
                        5'b0,                           // rs1
                        3'b000,                         // funct3
                        compressed_inst[11:7],          // rd
                        `TYPE_I                         // opcode
                    };

                    3'b011 : begin
                        if (compressed_inst[11:7] == 5'd2) begin
                            translated_inst = {   // C.ADDI16SP
                                {2{compressed_inst[12]}},   // imm[11:10]
                                compressed_inst[12],        // imm[9]
                                compressed_inst[4:3],       // imm[8:7]
                                compressed_inst[5],         // imm[6]
                                compressed_inst[2],         // imm[5]
                                compressed_inst[6],         // imm[4]
                                4'b0,                       // imm[3:0]
                                5'd2,                       // rs1
                                3'b000,                     // funct3
                                5'd2,                       // rd
                                `TYPE_I                     // opcode
                            };
                        end else begin
                            translated_inst = {   // C.LUI
                                {14{compressed_inst[12]}},  // imm[31:18]
                                compressed_inst[12],        // imm[17]
                                compressed_inst[6:2],       // imm[16:12]
                                compressed_inst[11:7],      // rd
                                `LUI                        // opcode
                            };
                        end
                    end

                    3'b100 : begin
                        case (compressed_inst[11:10])
                            2'b00 : translated_inst = {   // C.SRLI
                                7'b0000000,                     // funct7
                                // compressed_inst[12],            // imm[5]
                                compressed_inst[6:2],           // imm[4:0]
                                2'b01, compressed_inst[9:7],    // rs1
                                3'b101,                         // funct3
                                2'b01, compressed_inst[9:7],    // rd
                                `TYPE_I                         // opcode
                            };

                            2'b01 : translated_inst = {   // C.SRAI
                                7'b0100000,                     // funct7
                                // compressed_inst[12],            // imm[5]
                                compressed_inst[6:2],           // imm[4:0]
                                2'b01, compressed_inst[9:7],    // rs1
                                3'b101,                         // funct3
                                2'b01, compressed_inst[9:7],    // rd
                                `TYPE_I                         // opcode
                            };

                            2'b10 : translated_inst = {   // C.ANDI
                                {7{compressed_inst[12]}},       // funct7
                                compressed_inst[12],            // imm[5]
                                compressed_inst[6:2],           // imm[4:0]
                                2'b01, compressed_inst[9:7],    // rs1
                                3'b111,                         // funct3
                                2'b01, compressed_inst[9:7],    // rd
                                `TYPE_I                         // opcode
                            };

                            2'b11 : begin
                                if (compressed_inst[12] == 0) begin
                                    case (compressed_inst[6:5])
                                        2'b00 : translated_inst = {   // C.SUB
                                            7'b0100000,                     // funct7
                                            2'b01, compressed_inst[4:2],    // rs2
                                            2'b01, compressed_inst[9:7],    // rs1
                                            3'b000,                         // funct3
                                            2'b01, compressed_inst[9:7],    // rd
                                            `TYPE_R                         // opcode
                                        };

                                        2'b01 : translated_inst = {   // C.XOR
                                            7'b0000000,                     // funct7
                                            2'b01, compressed_inst[4:2],    // rs2
                                            2'b01, compressed_inst[9:7],    // rs1
                                            3'b100,                         // funct3
                                            2'b01, compressed_inst[9:7],    // rd
                                            `TYPE_R                         // opcode
                                        };

                                        2'b10 : translated_inst = {   // C.OR
                                            7'b0000000,                     // funct7
                                            2'b01, compressed_inst[4:2],    // rs2
                                            2'b01, compressed_inst[9:7],    // rs1
                                            3'b110,                         // funct3
                                            2'b01, compressed_inst[9:7],    // rd
                                            `TYPE_R                         // opcode
                                        };

                                        2'b11 : translated_inst = {   // C.AND
                                            7'b0000000,                     // funct7
                                            2'b01, compressed_inst[4:2],    // rs2
                                            2'b01, compressed_inst[9:7],    // rs1
                                            3'b111,                         // funct3
                                            2'b01, compressed_inst[9:7],    // rd
                                            `TYPE_R                         // opcode
                                        };

                                        default : translated_inst = 32'b0;
                                    endcase
                                end else begin
                                    translated_inst = 32'b0;
                                end
                            end
                            
                            default : translated_inst = 32'b0;
                        endcase
                    end

                    3'b101 : translated_inst = { // C.J
                        compressed_inst[12],            // imm[20]
                        compressed_inst[8],             // imm[10]
                        compressed_inst[10:9],          // imm[9:8]
                        compressed_inst[6],             // imm[7]
                        compressed_inst[7],             // imm[6]
                        compressed_inst[2],             // imm[5]
                        compressed_inst[11],            // imm[4]
                        compressed_inst[5:3],           // imm[3:1]
                        compressed_inst[12],            // imm[11]
                        {8{compressed_inst[12]}},       // imm[19:12]
                        5'd0,                           // rd
                        `JAL                            // opcode
                    };

                    3'b110 : translated_inst = { // C.BEQZ
                        compressed_inst[12],            // imm[12]
                        {2{compressed_inst[12]}},       // imm[10:9]
                        compressed_inst[12],            // imm[8]
                        compressed_inst[6:5],           // imm[7:6]
                        compressed_inst[2],             // imm[5]
                        5'd0,                           // rs2
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b000,                         // funct3
                        compressed_inst[11:10],         // imm[4:3]
                        compressed_inst[4:3],           // imm[2:1]
                        compressed_inst[12],            // imm[11]
                        `TYPE_B                         // opcode
                    };

                    3'b111 : translated_inst = { // C.BNEZ
                        compressed_inst[12],            // imm[12]
                        {2{compressed_inst[12]}},       // imm[10:9]
                        compressed_inst[12],            // imm[8]
                        compressed_inst[6:5],           // imm[7:6]
                        compressed_inst[2],             // imm[5]
                        5'd0,                           // rs2
                        2'b01, compressed_inst[9:7],    // rs1
                        3'b001,                         // funct3
                        compressed_inst[11:10],         // imm[4:3]
                        compressed_inst[4:3],           // imm[2:1]
                        compressed_inst[12],            // imm[11]
                        `TYPE_B                         // opcode
                    };

                    default : translated_inst = 32'b0;
                endcase
            end

            2'b10 : begin
                case (compressed_inst_funct)
                    3'b000 : translated_inst = {   // C.SLLI
                        7'b0000000,                     // imm[11:5]
                        // compressed_inst[12],            // imm[5]
                        compressed_inst[6:2],           // imm[4:0]
                        compressed_inst[11:7],          // rs1
                        3'b001,                         // funct3
                        compressed_inst[11:7],          // rd
                        `TYPE_I                         // opcode
                    };

                    3'b010 : translated_inst = {   // C.LWSP
                        4'b0,                           // imm[11:8]
                        compressed_inst[3:2],           // imm[7:6]
                        compressed_inst[12],            // imm[5]
                        compressed_inst[6:4],           // imm[4:2]
                        2'b0,                           // imm[1:0]
                        5'd2,                           // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:7],          // rd
                        `TYPE_L                         // opcode
                    };

                    3'b011 : translated_inst = {   // C.FLWSP
                        4'b0,                           // imm[11:8]
                        compressed_inst[3:2],           // imm[7:6]
                        compressed_inst[12],            // imm[5]
                        compressed_inst[6:4],           // imm[4:2]
                        2'b0,                           // imm[1:0]
                        5'd2,                           // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:7],          // rd
                        `TYPE_LOAD_FP                   // opcode
                    };

                    3'b100 : begin
                        if (compressed_inst[12] == 0) begin
                            if (compressed_inst[6:2] == 0) begin
                                translated_inst = {   // C.JR
                                    12'b0,                      // imm[11:0]
                                    compressed_inst[11:7],      // rs1
                                    3'b000,                     // funct3
                                    5'd0,                       // rd
                                    `JALR                       // opcode
                                };
                            end else begin
                                translated_inst = {   // C.MV
                                    7'b0,                       // funct7
                                    compressed_inst[6:2],       // rs2
                                    5'd0,                       // rs1
                                    3'b000,                     // funct3
                                    compressed_inst[11:7],      // rd
                                    `TYPE_R                     // opcode
                                };
                            end
                        end else begin
                            if (compressed_inst[6:2] == 0) begin
                                if (compressed_inst[11:7] == 0) begin
                                    translated_inst = `EBREAK;
                                end else begin
                                    translated_inst = {   // C.JALR
                                        12'b0,                      // imm[11:0]
                                        compressed_inst[11:7],      // rs1
                                        3'b000,                     // funct3
                                        5'd1,                       // rd
                                        `JALR                       // opcode
                                    };
                                end
                            end else begin
                                translated_inst = {   // C.ADD
                                    7'b0000000,                     // funct7
                                    compressed_inst[6:2],           // rs2
                                    compressed_inst[11:7],          // rs1
                                    3'b000,                         // funct3
                                    compressed_inst[11:7],          // rd
                                    `TYPE_R                         // opcode
                                };
                            end
                        end
                    end

                    3'b110 : translated_inst = {   // C.SWSP
                        4'b0,                           // imm[11:8]
                        compressed_inst[8:7],           // imm[7:6]
                        compressed_inst[12],            // imm[5]
                        compressed_inst[6:2],           // rs2
                        5'd2,                           // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:9],          // imm[4:2]
                        2'b0,                           // imm[1:0]
                        `TYPE_S                         // opcode
                    };

                    3'b111 : translated_inst = {   // C.FSWSP
                        4'b0,                           // imm[11:8]
                        compressed_inst[8:7],           // imm[7:6]
                        compressed_inst[12],            // imm[5]
                        compressed_inst[6:2],           // rs2
                        5'd2,                           // rs1
                        3'b010,                         // funct3
                        compressed_inst[11:9],          // imm[4:2]
                        2'b0,                           // imm[1:0]
                        `TYPE_STORE_FP                  // opcode
                    };

                    default : translated_inst = 32'b0;
                endcase
            end

            2'b11   : translated_inst = inst_i;
            default : translated_inst = 32'b0;
        endcase
    end
endmodule