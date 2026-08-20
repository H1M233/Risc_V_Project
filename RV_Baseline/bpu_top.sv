`include "rv32I.svh"
`include "alu_def.svh"
module bpu_top #(
    // 分支预测
    parameter BHR_WIDTH = 10,            // BHR宽度：PHT索引根据
    parameter PHT_IDX_WIDTH = 12,       // PHT宽度，应略大于 BHR 宽度

    // BTB
    parameter BTB_INDEX_WIDTH = 4
)(
    input  logic            clk                 ,
    input  logic            rst                 ,
    input  logic            pipe_hold           ,
    input  logic            pipe_flush          ,
    input  logic            outer_flush         ,
    
    input  logic [31:0]     pc_early_i          ,
    input  logic [31:0]     pc_i                ,
    input  logic [31:0]     inst_i              ,
    input  logic [31:0]     pc_next_i           ,

    // from ex
    input  BPU_data_t       data_pkg_i          ,

    // to pc & id
    output flush_t          pred_flush_o        ,
    output logic [4:0]      ptr_o               
);
    // connect gshare with bpu
    logic [BHR_WIDTH - 1:0]  gshare_pht_index_i;
    logic                    gshare_pred_taken_o;
    logic                    gshare_prev_b_i;
    logic [BHR_WIDTH - 1:0]  gshare_ghr_o;
    logic [BHR_WIDTH - 1:0]  gshare_ghr_update_o;

    logic                    gshare_update_en_i;
    logic [BHR_WIDTH - 1:0]  gshare_update_pht_index_i;
    logic                    gshare_actual_taken_i;

    // connect ras with bpu
    logic                    ras_push_en_i;
    logic                    ras_pop_en_i;
    logic [31:0]             ras_push_addr_i;
    logic                    ras_rollback_ptr_en_i;
    logic [4:0]              ras_rollback_ptr_i;

    logic [31:0]             ras_pop_addr_o;
    logic                    ras_isempty_o;
    logic                    ras_isfull_o;

    // connect btb with bpu
    logic [BTB_INDEX_WIDTH - 1:0]        btb_query_index_i;
    logic [31 - BTB_INDEX_WIDTH - 2:0]   btb_query_tag_i;
    logic                                btb_hit_o;
    logic [31:0]                         btb_target_pc_o;

    logic                                btb_update_en_i;
    logic [BTB_INDEX_WIDTH - 1:0]        btb_update_index_i;
    logic [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_i;
    logic [31:0]                         btb_update_target_i;

    // 更新解码
    BPU_data_t bpkg;
    assign bpkg = data_pkg_i;

    // 取出 rd 和 rs1 的地址
    wire    [4:0]   rd_addr     = inst_i[11:7];
    wire    [4:0]   rs1_addr    = inst_i[19:15];

    // 处理 TYPE_B
    wire            is_B_type   = (inst_i[6:0] == `TYPE_B);
    wire    [31:0]  B_imm       = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};

    // 处理 JALR
    wire            is_JALR     = (inst_i[6:0] == `JALR);
    wire    [11:0]  JALR_imm_u  = inst_i[31:20];
    wire            check_ret   = (rd_addr == 5'b0 && rs1_addr == 5'b00001 && JALR_imm_u == 12'b0);
    wire            is_ret_JALR = (is_JALR && check_ret);
    wire            is_btb_JALR = (is_JALR && !check_ret);
    wire            ras_can_pop = (is_ret_JALR && !ras_isempty_o);

    // 处理 JAL
    wire            is_JAL      = (inst_i[6:0] == `JAL);
    wire    [31:0]  JAL_imm     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
    wire            is_ret_JAL  = (is_JAL && rd_addr == 5'b00001);
    wire            is_ras_push = (is_ret_JAL && !ras_isfull_o);

    wire    [31:0]  pc_add_JAL  = pc_i + JAL_imm;
    wire    [31:0]  pc_add_B    = pc_i + B_imm;

    // Gshare索引：取PC中间位与BHR异或
    wire [PHT_IDX_WIDTH - 1:0]  pht_index        = pc_early_i[PHT_IDX_WIDTH + 1:2] ^ {{(PHT_IDX_WIDTH - BHR_WIDTH){1'b0}}, gshare_ghr_o};
    wire [PHT_IDX_WIDTH - 1:0]  update_pht_index = bpkg.update_pc[PHT_IDX_WIDTH + 1:2] ^ {{(PHT_IDX_WIDTH - BHR_WIDTH){1'b0}}, gshare_ghr_update_o};

    // BTB索引和tag（tag取pc高位，用于区分映射到同一索引的不同地址）
    wire [BTB_INDEX_WIDTH - 1:0]        btb_query_index_w   = pc_early_i[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_query_tag_w     = pc_early_i[31:BTB_INDEX_WIDTH + 2];
    wire [BTB_INDEX_WIDTH - 1:0]        btb_update_index_w  = bpkg.update_pc[BTB_INDEX_WIDTH + 1:2];
    wire [31 - BTB_INDEX_WIDTH - 2:0]   btb_update_tag_w    = bpkg.update_pc[31:BTB_INDEX_WIDTH + 2];

    // 查询
    assign gshare_pht_index_i = (pipe_flush) ? 0 : pht_index;     // 预测跳转后屏蔽查询入口
    always_ff @(posedge clk) begin
        if (rst) begin
            // RAS
            ras_push_addr_i   <= 0;

            // BTB
            btb_query_index_i <= 0;
            btb_query_tag_i   <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else begin
            // RAS
            ras_push_addr_i   <= pc_next_i;

            // BTB
            btb_query_index_i <= btb_query_index_w;
            btb_query_tag_i   <= btb_query_tag_w;
        end
    end

    // 查询更新使能 - 受冲刷影响
    always_ff @(posedge clk) begin
        if (rst) begin
            // RAS
            ras_pop_en_i      <= 0;
            ras_push_en_i     <= 0;

            // GSHARE
            gshare_prev_b_i   <= 0;
        end
        else if (pipe_flush) begin
            // RAS
            ras_pop_en_i      <= 0;
            ras_push_en_i     <= 0;

            // GSHARE
            gshare_prev_b_i   <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else begin
            // RAS
            ras_pop_en_i      <= ras_can_pop;
            ras_push_en_i     <= is_ras_push;

            // GSHARE
            gshare_prev_b_i   <= is_B_type;
        end
    end
    
    // 预测结果
    reg sel_pred_taken;
    reg [31:0] sel_pred_pc;
    always_comb begin
        unique case (1'b1)
            ras_can_pop: begin
                sel_pred_taken  = 1'b1;
                sel_pred_pc     = ras_pop_addr_o;
            end
            is_btb_JALR: begin
                sel_pred_taken  = btb_hit_o;
                sel_pred_pc     = btb_target_pc_o;
            end
            is_B_type: begin
                sel_pred_taken  = gshare_pred_taken_o;
                sel_pred_pc     = pc_add_B;
            end
            is_JAL: begin
                sel_pred_taken  = 1'b1;
                sel_pred_pc     = pc_add_JAL;
            end
            default: begin
                sel_pred_taken  = 1'b0;
                sel_pred_pc     = 32'b0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pred_flush_o.en     <= 0;
            pred_flush_o.pc     <= 0;
        end
        else if (pipe_hold) begin   // 当暂停时预测器的结果需要保存
            // ...
        end
        else if (pipe_flush) begin
            pred_flush_o.en     <= 0;
            pred_flush_o.pc     <= 0;
        end
        else begin
            pred_flush_o.en     <= sel_pred_taken;
            pred_flush_o.pc     <= sel_pred_pc;
        end
    end

    // Gshare 更新
    assign gshare_update_en_i         = bpkg.update_gshare_en;
    assign gshare_update_pht_index_i  = update_pht_index;
    assign gshare_actual_taken_i      = bpkg.actual_taken;
    
    // BTB 更新
    assign btb_update_en_i            = bpkg.update_btb_en;
    assign btb_update_index_i         = btb_update_index_w;
    assign btb_update_tag_i           = btb_update_tag_w;
    assign btb_update_target_i        = bpkg.update_target;

    // RAS 指针回滚
    assign ras_rollback_ptr_en_i      = outer_flush;
    assign ras_rollback_ptr_i         = bpkg.rollback_ras_ptr;

    gshare #(
        .BHR_WIDTH      (BHR_WIDTH),
        .PHT_IDX_WIDTH  (PHT_IDX_WIDTH)
    ) GSHARE(
        .clk                        (clk),
        .rst                        (rst),
        .pipe_hold                  (pipe_hold),
    
        // 查询
        .pht_index_i                (gshare_pht_index_i),
        .prev_b                     (gshare_prev_b_i),
        .pred_taken_o               (gshare_pred_taken_o),
        .gshare_ghr_o               (gshare_ghr_o),
        .gshare_ghr_update_o        (gshare_ghr_update_o),

        // 更新
        .update_en_i                (gshare_update_en_i),
        .update_pht_index_i         (gshare_update_pht_index_i),
        .actual_taken_i             (gshare_actual_taken_i)
    );

    ras RAS(
        .clk                        (clk),
        .rst                        (rst),

        // from bpu_controller
        .push_en_i                  (ras_push_en_i),
        .pop_en_i                   (ras_pop_en_i),
        .push_addr_i                (ras_push_addr_i),
        .rollback_en_i              (ras_rollback_ptr_en_i),
        .rollback_ptr_i             (ras_rollback_ptr_i),

        // to bpu_controller
        .pop_addr_o                 (ras_pop_addr_o),
        .isempty_o                  (ras_isempty_o),
        .isfull_o                   (ras_isfull_o),
        .ptr_o                      (ptr_o)
    );

    btb #(
        .INDEX_WIDTH (BTB_INDEX_WIDTH)
    ) BTB(
        .clk                        (clk),
        .rst                        (rst),
    
        // 查询
        .query_index_i              (btb_query_index_i),
        .query_tag_i                (btb_query_tag_i),
        .hit_o                      (btb_hit_o),
        .target_pc_o                (btb_target_pc_o),
    
        // 更新
        .update_en_i                (btb_update_en_i),
        .update_index_i             (btb_update_index_i),
        .update_tag_i               (btb_update_tag_i),
        .update_target_i            (btb_update_target_i)
    );

endmodule