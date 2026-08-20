module plic #(
    parameter NUM_SOURCES = 32  // 中断源数量
) (
    input  logic                            clk         ,
    input  logic                            rst         ,
    
    // 外设中断输入
    input  logic [NUM_SOURCES - 1:0]        irq_lines   ,       // 中断请求线
    input  logic [NUM_SOURCES - 1:0][31:0]  irq_ids     ,       // 每个中断源的ID
    
    // CPU 中断输出
    output logic                            cpu_irq     ,       // 外部中断信号
    output logic [31:0]                     cpu_irq_id          // 选中中断的ID
);
    // 中断优先级（0 = 禁用，7 = 最高）
    logic [2:0] irq_priority [NUM_SOURCES - 1:0];   // 每个中断源的优先级
    logic       irq_enable   [NUM_SOURCES - 1:0];   // 每个中断源的使能
    logic       irq_pending  [NUM_SOURCES - 1:0];   // 每个中断源的挂起
    
    // CPU 配置
    logic [2:0]  priority_threshold;    // 优先级阈值
    logic [31:0] claim_id;              // Claim寄存器值
    
    // 内部信号
    logic [NUM_SOURCES - 1:0] valid_interrupts;
    logic [31:0] highest_priority_source;
    logic [31:0] highest_priority_id;
    logic [2:0]  highest_priority_level;
    
    // 中断挂起检测
    logic [NUM_SOURCES - 1:0] irq_lines_prev;
    always_ff @(posedge clk) begin : pending
        if (rst) begin
            irq_lines_prev <= '0;
            for (int i = 0; i < NUM_SOURCES; i++) begin
                irq_pending[i] <= '0;
            end
        end else begin
            irq_lines_prev <= irq_lines;
            
            for (int i = 0; i < NUM_SOURCES; i++) begin
                if (irq_lines[i] && !irq_lines_prev[i] && 
                    irq_priority[i] > priority_threshold) begin
                    irq_pending[i] <= 1'b1;
                end
            end
        end
    end
    
    // 优先级仲裁
    always_comb begin
        // 找出优先级最高的挂起中断
        valid_interrupts        = '0;
        highest_priority_source = 32'b0;
        highest_priority_id     = 32'b0;
        highest_priority_level  = 3'b0;
        
        for (int i = 0; i < NUM_SOURCES; i++) begin
            if (irq_pending[i] && irq_priority[i] > priority_threshold) begin
                valid_interrupts[i] = 1'b1;
                
                // 选择最高优先级（数值越大优先级越高）
                if (irq_priority[i] > highest_priority_level) begin
                    highest_priority_level  = irq_priority[i];
                    highest_priority_source = i;
                    highest_priority_id     = irq_ids[i];
                end
            end
        end
        
        // 如果有有效中断，输出
        if (|valid_interrupts) begin
            cpu_irq    = 1'b1;
            cpu_irq_id = highest_priority_id;
            claim_id   = highest_priority_source;  // 返回中断源编号
        end else begin
            cpu_irq    = 1'b0;
            cpu_irq_id = 32'h0;
            claim_id   = 32'h0;
        end
    end
    
endmodule