`include "switch.svh"
module Fdivider(
    input  logic clk,
    input  logic rst,
    input  logic flush_i,

    input  logic        valid_i,
    input  logic [22:0] dividend_i,
    input  logic [22:0] divisor_i,

    output logic        valid_o,
    output logic [26:0] result_o // {1'b1, mant, G, R, S}
);
    // 查找表 P & N 表
    (* ram_style = "distributed" *) reg [14:0] PLUT [0:2047];
    (* ram_style = "distributed" *) reg [5:0]  NLUT [0:127];
    initial begin
        `ifndef VERILATOR
        $readmemb({`LUT_PATH, "/PLUT_div.txt"}, PLUT);
        $readmemb({`LUT_PATH, "/NLUT_div.txt"}, NLUT);
        `else
        $readmemb("../Fext_LUT/PLUT_div.txt", PLUT);
        $readmemb("../Fext_LUT/NLUT_div.txt", NLUT);
        `endif
    end

    wire [5:0] divisor_xh = divisor_i[22:17];
    wire [4:0] divisor_xm = divisor_i[16:12];
    wire       divisor_xl = divisor_i[11];

    wire [10:0] PLUT_Query_Index     = {divisor_xh, divisor_xm};
    wire        PLUT_Query_Index_Eqz = (PLUT_Query_Index == 0);

    wire [6:0] NLUT_Query_Index = {divisor_xh, divisor_xl};
    
    wire [16:0] PLUT_Query = {PLUT_Query_Index_Eqz, ~PLUT_Query_Index_Eqz, PLUT[PLUT_Query_Index]};
    wire [5:0]  NLUT_Query = NLUT[NLUT_Query_Index];

    wire [16:0] Approx_Recip_Divisor = PLUT_Query - NLUT_Query;

    // Goldschmidt 算法迭代 3 次
    logic [35:0] D, F, N;   // 36 位刚好用完 2 个 DSP (18 x 2)

    (* use_dsp = "yes" *) 
    logic [71:0] D_next, F_next;
    logic [71:0] N_next;
    assign D_next = D * F;
    assign N_next = N * F;
    assign F_next = {1'b1, 71'b0} - D_next;

    typedef enum {IDLE, QUERY, ITERATE} state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
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
                        D       <= {1'b1, divisor_i, 3'b0, 9'b0};
                        F       <= {Approx_Recip_Divisor, 10'b0, 9'b0};
                        N       <= {1'b1, dividend_i, 3'b0, 9'b0};
                        state   <= ITERATE;
                    end
                end

                ITERATE: begin
                    if (iter == Iend) begin
                        result_o    <= {N_next[70:45], |N_next[44:0]};
                        state       <= IDLE;
                        valid_o     <= 1'b1;
                    end
                    else begin
                        D <= D_next[70:35];
                        F <= F_next[70:35];
                        N <= N_next[70:35];
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
        if (rst) begin
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