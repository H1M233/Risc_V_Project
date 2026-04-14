module DRAM(
    input   wire            clk,
    input   wire[16 - 1:0]  a,
    output  wire[32 - 1:0]  spo,
    input   wire[32 - 1:0]  d,
    input   wire            we
);

reg[32 - 1:0] memory[0:65536 - 1];
integer i;
initial begin
    for (i = 0; i < 65536; i = i + 1) begin
        memory[i] = 32'b0;
    end
end

assign spo = memory[a];

// 同步写
always @(posedge clk) begin
    if (we) begin
        memory[a] <= d;
    end
end

endmodule