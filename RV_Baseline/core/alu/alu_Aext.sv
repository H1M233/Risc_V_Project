`include "../def/alu_def.svh"
`include "../def/switch.svh"

`ifdef ENABLE_A
module alu_Aext(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  decode_t     ipkg,

    input  logic        AXI_wen,
    input  logic        load_ready,
    input  logic        store_ready,
    input  logic [31:0] mem_rdata,

    output logic        atom_req_load,
    output logic        atom_req_store,
    output logic [31:0] atom_addr,
    output logic [31:0] atom_wdata,


    output logic        AXI_lock,
    output logic        ctrl,
    output logic [31:0] result
);
    typedef struct packed {
        logic [31:0] addr;
        logic        valid;
    } atom_t;
    atom_t atom_state;

    typedef enum {IDLE, LOAD_REQ, WAIT_RD, STORE_REQ, WAIT_WR} state_t;
    state_t state;
    
    // sc.w 命中
    wire sc_w_hit = (rs1 == atom_state.addr) & atom_state.valid & ipkg.sel_sc_w;

    // 对 LSU 的 Load & Store 请求
    assign atom_req_load  = ipkg.sel_lr_w | (state == LOAD_REQ);
    assign atom_req_store = sc_w_hit | (state == STORE_REQ);

    // lr.w / sc.w 寄存器
    wire set_atom   = ipkg.sel_lr_w;
    wire break_atom = ((rs1 == atom_state.addr) & (ipkg.is_store)) | (ipkg.is_Aext & ~ipkg.sel_lr_w) | AXI_wen;
    always_ff @(posedge clk) begin
        if (rst) begin
            atom_state       <= 0;
        end
        else if (set_atom) begin
            atom_state.valid <= 1;
            atom_state.addr  <= rs1;
        end
        else if (break_atom) begin
            atom_state.valid <= 0;
        end
    end

    wire amo_get_ctrl = (ipkg.is_Aext & ~ipkg.sel_lr_w & ~ipkg.sel_sc_w);
    logic [31:0] rs1_r, rs2_r;
    logic [31:0] load_data;
    always_ff @(posedge clk) begin
        if (rst | flush) begin
            state       <= IDLE;
            load_data   <= 0;
            rs1_r       <= 0;
            rs2_r       <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (amo_get_ctrl) begin
                        state   <= LOAD_REQ;
                        rs1_r   <= rs1;
                        rs2_r   <= rs2;
                    end
                end
                
                LOAD_REQ: begin
                    state <= WAIT_RD;
                end
                
                WAIT_RD: begin
                    if (load_ready) begin
                        state       <= STORE_REQ;
                        load_data   <= mem_rdata;
                    end
                end
                
                STORE_REQ: begin
                    state <= WAIT_WR;
                end
                
                WAIT_WR: begin
                    if (store_ready) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    assign atom_addr = (state == IDLE) ? rs1 : rs1_r;

    // 对 load_data 计算
    cmp_result_t cmp;
    assign cmp = fast_compare(load_data, rs2_r);

    wire [31:0] add_res  = load_data + rs2_r;
    wire [31:0] and_res  = load_data & rs2_r;
    wire [31:0] or_res   = load_data | rs2_r;
    wire [31:0] xor_res  = load_data ^ rs2_r;
    wire [31:0] max_res  = ( cmp.lts) ? rs2_r : load_data;
    wire [31:0] maxu_res = ( cmp.ltu) ? rs2_r : load_data;
    wire [31:0] min_res  = (~cmp.lts) ? rs2_r : load_data;
    wire [31:0] minu_res = (~cmp.ltu) ? rs2_r : load_data;

    // 写回 mem
    always_comb begin
        unique case (1'b1)
            ipkg.sel_sc_w      : atom_wdata = rs2;
            ipkg.sel_amoswap_w : atom_wdata = rs2_r;
            ipkg.sel_amoadd_w  : atom_wdata = add_res;
            ipkg.sel_amoand_w  : atom_wdata = and_res;
            ipkg.sel_amoor_w   : atom_wdata = or_res;
            ipkg.sel_amoxor_w  : atom_wdata = xor_res;
            ipkg.sel_amomax_w  : atom_wdata = max_res;
            ipkg.sel_amomaxu_w : atom_wdata = maxu_res;
            ipkg.sel_amomin_w  : atom_wdata = min_res;
            ipkg.sel_amominu_w : atom_wdata = minu_res;
            default            : atom_wdata = 32'b0;
        endcase
    end

    // 写回 regs
    assign result = (ipkg.sel_sc_w) ? {31'b0, ~sc_w_hit} : load_data;

    wire finished = (state == WAIT_WR) & store_ready;

    assign AXI_lock = (amo_get_ctrl) & ~finished;
    assign ctrl     = (amo_get_ctrl) & ~finished;
endmodule
`endif