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
// thcattus_uart_tx.v:
// Generic purpose UART transmitter with AXI-Stream interface
//
module thcattus_uart_tx #(
	parameter DATA_WIDTH = 4,				// bus width in bytes
	parameter CLOCK_FREQ = 50_000_000, 	// clock frequency in HZ
	parameter BAUD_RATE  = 115200,		// baudrate
	
	parameter IDLE_BIT   = 3 // actually avoiding misinterpretation of an busy UART port,
									 // a number greater than 3 can avoid most of the situations
)(
	input 	axis_aclk,
	input 	axis_arestn,
	
	input  	axis_tvalid,
	output 	axis_tready,
	input 	[DATA_WIDTH*8-1:0] 	axis_tdata,
	// not support any "advanced" data mode of AXIS
	//input 	[DATA_WIDTH    :0] 	axis_tstrb,
	//input 	[DATA_WIDTH    :0] 	axis_tkeep,
	//input  axis_tlast,
	
	output   uart_tx
);

localparam CYCLE_PER_BAUD = CLOCK_FREQ / BAUD_RATE;

wire uart_finished;
reg [7:0] byte_counter;

// main status machine

localparam STATUS_RESET 			= 8'd0;
localparam STATUS_IDLE  			= 8'd1;
localparam STATUS_AXIS_LATCH     = 8'd2;
localparam STATUS_UART_START     = 8'd3;
localparam STATUS_UART_END       = 8'd4;

reg [7:0] status_current;
reg [7:0] status_next;

always @(posedge axis_aclk or negedge axis_arestn) begin
	if (!axis_arestn) begin
		status_current <= STATUS_RESET;
	end else begin
		status_current <= status_next;
	end
end

always @(*) begin
	case (status_current)
	
		STATUS_RESET: begin
			status_next = STATUS_IDLE;
		end
		
		STATUS_IDLE: begin
			if (axis_tvalid) begin
				status_next = STATUS_AXIS_LATCH;
			end else begin
				status_next = status_current;
			end
		end
		
		STATUS_AXIS_LATCH: begin
			status_next = STATUS_UART_START;
		end
		
		STATUS_UART_START: begin
			if (uart_finished) begin
				status_next = STATUS_UART_END;
			end else begin
				status_next = status_current;
			end
		end
		
		STATUS_UART_END: begin
			if (byte_counter < DATA_WIDTH-1) begin
				status_next = STATUS_UART_START;
			end else begin
				status_next = STATUS_IDLE;
			end
		end
	endcase
end

reg [7:0] 	latched_axis_tdata [0:DATA_WIDTH-1];
reg [31:0]	baudrate_counter;

always @(posedge axis_aclk) begin
	case (status_current)
	
		STATUS_IDLE: begin
			baudrate_counter <= 32'b0;
			byte_counter     <= 8'b0;
		end
		
		STATUS_AXIS_LATCH: begin
			integer i;
			for (i=0; i<DATA_WIDTH; i=i+1) begin
				latched_axis_tdata[i] <= axis_tdata[i*8+:8];
			end
		end
		
		STATUS_UART_START: begin
			baudrate_counter <= baudrate_counter + 32'b1;
		end
		
		STATUS_UART_END: begin
			baudrate_counter <= 32'b0;
			byte_counter     <= byte_counter + 8'b1;
		end
	endcase
end

// internal signal assignment

assign uart_finished = (baudrate_counter > CYCLE_PER_BAUD*(10+IDLE_BIT));

// external signal assignment

assign axis_tready = (status_current == STATUS_IDLE);

reg uart_tx_r;
assign uart_tx = uart_tx_r;

always @(*) begin
	case(1'b1)
		(baudrate_counter < CYCLE_PER_BAUD*1): uart_tx_r = 1'b0;
		(baudrate_counter < CYCLE_PER_BAUD*2): uart_tx_r = latched_axis_tdata[byte_counter][0];
		(baudrate_counter < CYCLE_PER_BAUD*3): uart_tx_r = latched_axis_tdata[byte_counter][1];
		(baudrate_counter < CYCLE_PER_BAUD*4): uart_tx_r = latched_axis_tdata[byte_counter][2];
		(baudrate_counter < CYCLE_PER_BAUD*5): uart_tx_r = latched_axis_tdata[byte_counter][3];
		(baudrate_counter < CYCLE_PER_BAUD*6): uart_tx_r = latched_axis_tdata[byte_counter][4];
		(baudrate_counter < CYCLE_PER_BAUD*7): uart_tx_r = latched_axis_tdata[byte_counter][5];
		(baudrate_counter < CYCLE_PER_BAUD*8): uart_tx_r = latched_axis_tdata[byte_counter][6];
		(baudrate_counter < CYCLE_PER_BAUD*9): uart_tx_r = latched_axis_tdata[byte_counter][7];
		(baudrate_counter < CYCLE_PER_BAUD*10): uart_tx_r = 1'b1;
		default: uart_tx_r = 1'b1;
	endcase
end

endmodule
