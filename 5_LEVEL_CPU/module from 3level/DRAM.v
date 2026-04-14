module DRAM(
    input   wire            clk,
    input   wire[16 - 1:0]  a,
    output  reg[32 - 1:0]   spo,
    input   wire[32 - 1:0]  d,
    input   wire            we
);

wire[11:0]  addr = a[13:2];

reg[32 - 1:0] memory[0:4096 - 1];

always@(posedge clk) begin
    spo <= memory[addr];
    if(we)
        memory[addr] <= d;
end
endmodule