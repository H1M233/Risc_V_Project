`include "rv32I.vh"

module pc(
    input               clk,
    input               rst,

    // from hazard
    input               hazard_en,

    // from ex
    input               pred_flush,
    input      [31:0]   pred_flush_pc,
    input               dcache_stall,

    // from wb
    input               wb_ecall,
    input               wb_mret,

    // from csr_regs
    input      [31:0]   ecall_mret_addr,

    // to if
    (* max_fanout = 30 *)
    output reg [31:0]   pc_addr_o,

    // from bpu
    input      [31:0]   pred_pc,
    input               pred_taken
);
    wire        pc_hold_en       = (hazard_en | dcache_stall);
    wire        flush_or_trap    = (wb_ecall | wb_mret | pred_flush); // ecall 处理，跳转到 ecall 处理函数 / mret 处理，跳转到 mret 处理函数
    wire [31:0] flush_or_trap_pc = (wb_ecall | wb_mret) ? ecall_mret_addr : pred_flush_pc;
    wire [31:0] pc_plus_4        = pc_addr_o + 32'd4;
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'h8000_0000;
        end
        else begin
            (* parallel_case *)
            case (1'b1)
                flush_or_trap: pc_addr_o <= flush_or_trap_pc;  // 异常/陷阱
                pred_taken:    pc_addr_o <= pred_pc;           // 分支预测
                ~pc_hold_en:   pc_addr_o <= pc_plus_4;         // 顺序执行
                default:       ;                               // 暂停
            endcase
        end
    end
endmodule