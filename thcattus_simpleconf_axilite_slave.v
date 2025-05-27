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
// thcattus_simpleconf_axilite_slave.v:
// Generic purpose AXI-Lite slave
//

module thcattus_simpleconf_axilite_slave #(
    parameter REG_WIDTH = 4,
    parameter REG_NUMBER = 16,
    
    parameter REG_NUMBER_WIDTH = $clog2(REG_NUMBER)
)(
    // AXI-Lite Slave bus
    input   aclk,
    input   aresetn,
    
    input   [31:0]  awaddr,
    input   [2:0]   awprot, // unchecked
    input           awvalid,
    output          awready,
    
    input   [31:0]  wdata,
    input   [3:0]   wstrb, // only 8, 16, 32 from lower address allowed
    input           wvalid,
    output          wready,
    
    output  [1:0]   bresp,
    output          bvalid,
    input           bready,
    
    input   [31:0]  araddr,
    input   [2:0]   arprot, // unchecked
    input           arvalid,
    output          arready,
    
    output  [31:0]  rdata,
    output  [1:0]   rresp,
    output          rvalid,
    input           rready,
    
    input   [REG_NUMBER_WIDTH:0] regfile_sel,
    output  [REG_WIDTH*8-1:0]    regfile_data
);
reg [REG_WIDTH*8-1:0] regfile [0:REG_NUMBER-1];

assign regfile_data = regfile[regfile_sel];
//
// write transcation aka wtrans
//

reg awready_r;
assign awready = awready_r;
reg [31:0] wtrans_addr;
always @(posedge aclk) begin
    if (!aresetn) begin
        wtrans_addr <= 32'b0;
        awready_r   <= 1;
    end else begin
        if (awvalid == 1 && awready == 1) begin
            wtrans_addr <= awaddr;
            awready_r   <= 0;
        end else if (awready_r == 0) begin
            awready_r   <= 1;
        end
    end
end

reg wready_r;
assign wready = wready_r;
reg [31:0]  wtrans_data;
reg [3:0]   wtrans_strb;
always @(posedge aclk) begin
    if (!aresetn) begin
        wtrans_data <= 32'b0;
        wtrans_strb <= 4'b0;
        wready_r    <= 1;
    end else begin
        if (wvalid == 1 && wready == 1) begin
            wtrans_data <= wdata;
            wtrans_strb <= wstrb;
            wready_r    <= 0;
        end else if (wready_r == 0) begin
            wready_r    <= 1;
        end
    end
end

wire [3:0] strb_excepted =  REG_WIDTH == 4 ? 4'b1111 :
                            REG_WIDTH == 3 ? 4'b0111 :
                            REG_WIDTH == 2 ? 4'b0011 :
                                             4'b0001 ;
localparam BRESP_OKAY   = 2'b00;
localparam BRESP_EXOKAY = 2'b01;
localparam BRESP_SLVERR = 2'b10;
localparam BRESP_DECERR = 2'b11;

reg bvalid_r;
assign bvalid = bvalid_r;
reg [1:0] bresp_r;
assign bresp = bresp_r;
always @(posedge aclk) begin
    if (!aresetn) begin
        bvalid_r    <= 1;
        bresp_r     <= BRESP_SLVERR;
    end else begin
        if (awready == 0 && wready == 0 && bready == 1) begin
            if (wtrans_addr[REG_NUMBER_WIDTH-1:0] < REG_NUMBER) begin 
                regfile[wtrans_addr[REG_NUMBER_WIDTH-1:0]] <= wtrans_data[REG_WIDTH*8-1:0];
                bresp_r     <= wtrans_strb == strb_excepted ? BRESP_OKAY : BRESP_SLVERR;
            end else begin
                // register do not exists
                bresp_r     <= BRESP_SLVERR;
            end
            bvalid_r    <= 0;
        end else if (bvalid == 0) begin
            bvalid_r    <= 1;
        end
    end
end

//
// read transcation aka rtrans
//

reg arready_r;
assign arready = arready_r;
reg [31:0] rtrans_addr;
reg [REG_WIDTH*8-1:0] read_data;

always @(posedge aclk) begin
    if (!aresetn) begin
        rtrans_addr <= 32'b0;
        arready_r   <= 1;
        read_data   <= {(REG_WIDTH*8){1'b0}};
    end else begin
        if (arvalid == 1 && arready == 1) begin
            rtrans_addr <= araddr;
            read_data   <= regfile[araddr[REG_NUMBER_WIDTH-1:0]];
            arready_r   <= 0;
        end else if (arready == 0) begin
            arready_r   <= 1;
        end
    end
end

reg rvalid_r;
assign rvalid = rvalid_r;
reg [1:0] rresp_r;
assign rresp = rresp_r;
reg [31:0] rdata_r;
assign rdata = rdata_r;
always @(posedge aclk) begin
    if (!aresetn) begin
        rvalid_r    <= 1;
        rresp_r     <= BRESP_SLVERR;
        rdata_r     <= 0;
    end else if (arready == 0 && rready == 1) begin
        if (rtrans_addr[REG_NUMBER_WIDTH-1:0] < REG_NUMBER) begin 
            rdata_r     <= regfile[wtrans_addr[REG_NUMBER_WIDTH-1:0]];
            rresp_r     <= BRESP_OKAY;
        end else begin
            // register do not exists
            rresp_r     <= BRESP_SLVERR;
        end
        rvalid_r    <= 0;
    end else if (rvalid == 0) begin
        rvalid_r    <= 1;
    end
end


endmodule