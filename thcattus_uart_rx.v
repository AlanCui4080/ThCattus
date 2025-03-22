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
// thcattus_uart_rx.v:
// Generic purpose UART receiver with AXI-Stream interface
//
module thcattus_uart_rx #(
	parameter DATA_WIDTH = 4,			// bus width in bytes
	parameter CLOCK_FREQ = 50_000_000, 	// clock frequency in HZ
	parameter BAUD_RATE  = 115200 		// baudrate
)(
	input 	axis_aclk,
	input 	axis_arestn,
	
	output  	axis_tvalid,
	input 	axis_tready,
	output 	[DATA_WIDTH*8-1:0] 	axis_tdata,
	// not support any "advanced" data mode of AXIS
	//output [DATA_WIDTH    :0] 	axis_tstrb,
	//output [DATA_WIDTH    :0] 	axis_tkeep,
	//output axis_tlast,
	
	input   uart_rx
);

localparam CYCLE_PER_BAUD 		= CLOCK_FREQ / BAUD_RATE;
localparam CYCLE_PER_BAUD_DIV2 	= CYCLE_PER_BAUD / 2;

wire uart_finished;
wire uart_invalid_start;
reg [DATA_WIDTH*8-1:0] 	axis_tdata_r;
reg axis_tvalid_r;
reg [7:0] byte_counter;

// main status machine

localparam STATUS_RESET        = 8'd0;
localparam STATUS_IDLE  	   = 8'd1;
localparam STATUS_UART_START   = 8'd2;
localparam STATUS_UART_END     = 8'd3;
localparam STATUS_AXIS_WAIT	   = 8'd4;


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
			if (~uart_rx) begin
				status_next = STATUS_UART_START;
			end else begin
				status_next = status_current;
			end
		end
		
		STATUS_UART_START: begin
			if (uart_finished) begin
				status_next = STATUS_UART_END;
			end else if (uart_invalid_start) begin
				status_next = STATUS_IDLE;
			end else begin
				status_next = status_current;
			end
		end
		
		STATUS_UART_END: begin
			if (byte_counter < DATA_WIDTH-1) begin
				status_next = STATUS_IDLE;
			end else begin
				status_next = STATUS_AXIS_WAIT;
			end
		end
		
		STATUS_AXIS_WAIT: begin
			if (axis_tready) begin
				status_next = STATUS_IDLE;
			end else begin
				status_next = status_current;
			end
		end
        
        default: begin
            status_next = STATUS_RESET;
        end
	endcase
end

reg latched_start_bit;
reg latched_stop_bit;
reg [7:0]  latched_axis_tdata [0:DATA_WIDTH-1];
reg [31:0] baudrate_counter;

integer i;
always @(posedge axis_aclk) begin
	case (status_current)
        STATUS_RESET: begin
            byte_counter 	  <= 8'b0;
        end
    
		STATUS_IDLE: begin
			baudrate_counter  <= 32'b0;
			axis_tvalid_r	  <= 1'b0;
		end
		
		STATUS_UART_START: begin
			baudrate_counter <= baudrate_counter + 32'b1;
			case(1'b1)
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*1): 	 latched_start_bit <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*3): 	 latched_axis_tdata[byte_counter][0] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*5): 	 latched_axis_tdata[byte_counter][1] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*7): 	 latched_axis_tdata[byte_counter][2] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*9): 	 latched_axis_tdata[byte_counter][3] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*11):    latched_axis_tdata[byte_counter][4] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*13):    latched_axis_tdata[byte_counter][5] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*15):    latched_axis_tdata[byte_counter][6] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*17):    latched_axis_tdata[byte_counter][7] <= uart_rx;
				(baudrate_counter == CYCLE_PER_BAUD_DIV2*19):    latched_stop_bit <= uart_rx;
                default: latched_stop_bit <= uart_rx;
			endcase
		end
		
		STATUS_UART_END: begin
			baudrate_counter <= 32'b0;
			byte_counter     <= byte_counter + 8'b1;
		end
		
		STATUS_AXIS_WAIT: begin
			for (i=0; i<DATA_WIDTH; i=i+1) begin: generate_tdata
				axis_tdata_r[i*8+:8] <= latched_axis_tdata[i];
			end
            axis_tvalid_r 	  <= 1'b1;
            byte_counter 	  <= 8'b0;
		end
	endcase
end

// internal signal assignment

assign uart_invalid_start = ((baudrate_counter > CYCLE_PER_BAUD) && (latched_start_bit));
assign uart_finished = (baudrate_counter > CYCLE_PER_BAUD_DIV2*19);

// external signal assignment

assign axis_tvalid = axis_tvalid_r;
assign axis_tdata = axis_tdata_r;
endmodule