`include "switch.svh"
module Fsqrt(
    input  logic clk,
    input  logic rst,
    input  logic flush_i,

    input  logic        valid_i,
    input  logic [22:0] S_i,
    input  logic        mul2,

    output logic        valid_o,
    output logic [26:0] result_o // {1'b1, mant, G, R, S}
);
    // 查找表 P & N 表
    (* ram_style = "distributed" *) reg [14:0] PLUT [0:2047];
    (* ram_style = "distributed" *) reg [5:0]  NLUT [0:127];
    initial begin
        `ifndef VERILATOR
        $readmemb({`LUT_PATH, "/PLUT_sqrt.txt"}, PLUT);
        $readmemb({`LUT_PATH, "/NLUT_sqrt.txt"}, NLUT);
        `else
        $readmemb("../LUT/PLUT_sqrt.txt", PLUT);
        $readmemb("../LUT/NLUT_sqrt.txt", NLUT);
        `endif
    end

    wire [24:0] S_ext = (mul2) ? {1'b1, S_i, 1'b0} : {1'b0, 1'b1, S_i};

    wire [5:0] S_xh = S_ext[22:17];
    wire [4:0] S_xm = S_ext[16:12];
    wire       S_xl = S_ext[11];

    wire [10:0] PLUT_Query_Index      = {S_xh, S_xm};
    wire        PLUT_Query_Index_Eqz1 = (PLUT_Query_Index == 0) | (PLUT_Query_Index == 11'b1);

    wire [6:0] NLUT_Query_Index = {S_xh, S_xl};
    
    wire [16:0] PLUT_Query = {PLUT_Query_Index_Eqz1, ~PLUT_Query_Index_Eqz1, PLUT[PLUT_Query_Index]};
    wire [5:0]  NLUT_Query = NLUT[NLUT_Query_Index];

    wire [16:0] Approx_Recip_S = PLUT_Query - NLUT_Query;

    // Goldschmidt 算法迭代 3 次
    logic [35:0] D, F, N;   // 36 位刚好用完 2 个 DSP (18 x 2)

    (* use_dsp = "yes" *) 
    logic [107:0] D_next;
    logic [71:0] N_next, F_next;
    assign D_next = D * F * F;
    assign N_next = N * F;
    assign F_next = {5'b00011, 67'b0} - (D_next[105:34] >> 1);

    typedef enum {IDLE, QUERY, ITERATE} state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (!rst) begin
            valid_o <= 1'b0;
            state   <= IDLE;
        end
        else if (flush_i) begin
            valid_o <= 1'b0;
            state   <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    valid_o <= 1'b0;
                    if (valid_i) begin
                        D       <= {S_ext, 3'b0, 8'b0};
                        F       <= {1'b0, Approx_Recip_S, 10'b0, 8'b0};
                        N       <= {S_ext, 3'b0, 8'b0};
                        state   <= ITERATE;
                    end
                end

                ITERATE: begin
                    if (iter == Iend) begin
                        result_o    <= {N_next[68:43], |N_next[42:0]};
                        state       <= IDLE;
                        valid_o     <= 1'b1;
                    end
                    else begin
                        D <= D_next[103:68];
                        F <= F_next[69:34];
                        N <= N_next[69:34];
                    end
                end
                default : state <= IDLE;
            endcase
        end
    end

    // 迭代计数器
    typedef enum {IDLE_I, I1, I2, I3, I4, I5, I6, I7, I8, I9, Iend} Iter_t;
    Iter_t iter;
    always_ff @(posedge clk) begin
        if (!rst) begin
            iter <= IDLE_I;
        end
        else if (flush_i) begin
            iter <= IDLE_I;
        end
        else begin
            case (iter)
                IDLE_I: begin
                    if (valid_i) begin
                        iter <= I1;
                    end
                end
                Iend : begin
                    iter <= IDLE_I;
                end
                default: begin
                    iter <= Iter_t'(iter + 1);
                end
            endcase
        end
    end

endmodule