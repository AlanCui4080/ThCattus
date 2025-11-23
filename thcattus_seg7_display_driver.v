// Copyright 2025 AlanCui4080
//
// Licensed under the Apache License, Version 2.0 (the "License"): you may
// not use this file except in compliance with the License. You may obtain
// a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.

// 
// thcattus_seg7_display_driver.v:
// Generic purpose 7-Segment display driver
//

module thcattus_seg7_display_driver #(
    parameter PART_NUMBER = 2, 			// number of display
    parameter CLOCK_FREQ  = 25_000_000, // clock frequency in HZ
	parameter REFESH_RATE = 10_000 		// switch frequency between each display in HZ
)(
    input clk,
    input reset_n,
	
    input  [PART_NUMBER*4-1:0] data,
    
    output [7:0] 			   segment,
    output [PART_NUMBER-1:0]   common
);

localparam REG_REFRESH_WIDTH = $clog2(CLOCK_FREQ/REFESH_RATE);
localparam REG_DISPLAY_SELECTOR_WIDTH = $clog2(PART_NUMBER);

reg [PART_NUMBER-1:0] common_r;
reg [7:0] segment_r;
assign common  = common_r;
assign segment = segment_r;

reg [3:0] segment_4bit_r;
always @(*) begin
    case (segment_4bit_r)
        4'h0: segment_r = 7'b0000001;
        4'h1: segment_r = 7'b1001111;
        4'h2: segment_r = 7'b0010010;
        4'h3: segment_r = 7'b0000110;
        4'h4: segment_r = 7'b1001100;
        4'h5: segment_r = 7'b0100100;
        4'h6: segment_r = 7'b0100000;
        4'h7: segment_r = 7'b0001111;
        4'h8: segment_r = 7'b0000000;
        4'h9: segment_r = 7'b0000100;
        4'hA: segment_r = 7'b0001000;
        4'hB: segment_r = 7'b1100000;
        4'hC: segment_r = 7'b0110001;
        4'hD: segment_r = 7'b1000010;
        4'hE: segment_r = 7'b0110000;
        4'hF: segment_r = 7'b0111000;
    endcase
end

wire [3:0] common_muxed_input [PART_NUMBER-1:0];
genvar i;
generate
	for (i=0; i<PART_NUMBER; i=i+1) begin: generate_common_muxed_input_r
		assign common_muxed_input[i] = data[(i*4+3)-:4];
    end
endgenerate

reg [REG_DISPLAY_SELECTOR_WIDTH-1:0] display_selector;
reg [REG_REFRESH_WIDTH-1:0] refresh_count_r;
always @(posedge clk) begin
	if (!reset_n) begin
        refresh_count_r  <= 0;
        display_selector <= 0;
        common_r		 <= 0;
    end else begin
    	if (refresh_count_r == CLOCK_FREQ/REFESH_RATE) begin
        	refresh_count_r  <= 0;
            display_selector <= display_selector == PART_NUMBER ? 0 : display_selector + 1;
            segment_4bit_r   <= common_muxed_input[display_selector];
            common_r 		 <= (1'b1 << display_selector);
        end else begin
	    	refresh_count_r <= refresh_count_r + 1'b1;
        end
    end
end
	
endmodule