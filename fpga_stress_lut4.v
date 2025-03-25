module top(
    input clk,
    output out
    );
    
wire mclk;
    
mainpll mainpll_inst(
    .inclk0(clk),
    .c0(mclk)
);
    
parameter LUT_NUMBER = 8000;
parameter DSP_NUMBER = 48;
    
reg ff_stress[LUT_NUMBER+4-1:0] /* synthesis keep */;
    
always @(posedge mclk) begin
    integer i;
    ff_stress[0] <= ~ff_stress[0];
    ff_stress[1] <= ~ff_stress[0];
    ff_stress[2] <= ff_stress[0] ^ ff_stress[1];
    ff_stress[3] <= ff_stress[0] ^ ff_stress[1] ^ ff_stress[2];
    for (i=4; i<LUT_NUMBER+4; i=i+1) begin
        ff_stress[i] <= ff_stress[i-1] ^ ff_stress[i-2] ^ ff_stress[i-3] ^ ff_stress[i-4];
    end
end

assign out = ff_stress[LUT_NUMBER+4-1];

endmodule
