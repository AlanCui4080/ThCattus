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
// therm_v1_processor.v:
// A 5 stages RV32I soft microprocessor
//

module therm_v1_processor(
    // instruction bus
    output          instbus_hclk,
    output          instbus_hresetn,
    output  [31:0]  instbus_haddr,
    output  [1:0]   instbus_htrans,
    output          instbus_hwrite,
    output  [2:0]   instbus_hsize, 
    output  [2:0]   instbus_hbrust,
    output  [3:0]   instbus_hprot,
    output  [31:0]  instbus_hwdata,
    input   [31:0]  instbus_hrdata,
    input           instbus_hready,
    input   [1:0]   instbus_hresp,

    // data bus
    output          databus_hclk,
    output          databus_hresetn, 
    output  [31:0]  databus_haddr,
    output  [1:0]   databus_htrans,
    output          databus_hwrite,
    output  [2:0]   databus_hsize,
    output  [2:0]   databus_hbrust,
    output  [3:0]   databus_hprot,
    output  [31:0]  databus_hwdata,
    input   [31:0]  databus_hrdata,
    input           databus_hready,
    input   [1:0]   databus_hresp,
    
    input   processor_clk,
    input   processor_resetn
);

//
// bus facilities 
//

// Instruction bus
assign instbus_hclk = processor_clk;
assign instbus_hresetn = processor_resetn;
reg  [31:0]  instbus_haddr_r;
assign instbus_haddr = instbus_haddr_r;
reg  [1:0]   instbus_htrans_r;
assign instbus_htrans = instbus_htrans_r;
reg          instbus_hwrite_r;
assign instbus_hwrite = instbus_hwrite_r;
reg  [2:0]   instbus_hsize_r;
assign instbus_hsize = instbus_hsize_r;
reg  [2:0]   instbus_hbrust_r;
assign instbus_hbrust = instbus_hbrust_r;
reg  [3:0]   instbus_hprot_r;
assign instbus_hprot = instbus_hprot_r;
reg  [31:0]  instbus_hwdata_r;
assign instbus_hwdata = instbus_hwdata_r;

// Data bus
assign databus_hclk = processor_clk;
assign databus_hresetn = processor_resetn;
reg  [31:0]  databus_haddr_r;
assign databus_haddr = databus_haddr_r;
reg  [1:0]   databus_htrans_r;
assign databus_htrans = databus_htrans_r;
reg          databus_hwrite_r;
assign databus_hwrite = databus_hwrite_r;
reg  [2:0]   databus_hsize_r;
assign databus_hsize = databus_hsize_r;
reg  [2:0]   databus_hbrust_r;
assign databus_hbrust = databus_hbrust_r;
reg  [3:0]   databus_hprot_r;
assign databus_hprot = databus_hprot_r;
reg  [31:0]  databus_hwdata_r;
assign databus_hwdata = databus_hwdata_r;

localparam BUS_HTRANS_IDLE      = 2'b00;
localparam BUS_HTRANS_BUSY      = 2'b01;
localparam BUS_HTRANS_NONSEQ    = 2'b10;
localparam BUS_HTRANS_SEQ       = 2'b11;

localparam BUS_HWRITE_WRITE     = 1'b1;
localparam BUS_HWRITE_READ      = 1'b0;

localparam BUS_HBRUST_SINGLE    = 3'b000;
localparam BUS_HBRUST_INCR      = 3'b001;
localparam BUS_HBRUST_WARP4     = 3'b010;
localparam BUS_HBRUST_INCR4     = 3'b011;
localparam BUS_HBRUST_WARP8     = 3'b100;
localparam BUS_HBRUST_INCR8     = 3'b101;
localparam BUS_HBRUST_WARP16    = 3'b110;
localparam BUS_HBRUST_INCR16    = 3'b111;

localparam BUS_HRESP_OKAY     = 2'b00;
localparam BUS_HRESP_ERROR    = 2'b01;
localparam BUS_HRESP_RETRY    = 2'b10;
localparam BUS_HRESP_SPLIT    = 2'b11;

//
// register file
//

reg             [31:0] reg_pc_r = 0;

(* ramstyle = "mlab" *) reg             [31:0] regfile_r      [0:31];
integer i;
initial for(i=0; i<32; i=i+1) begin:regfile_gen_init
    regfile_r[i] = 32'b0;
end

wire signed     [31:0] regfile_out    [0:31];
wire            [31:0] regfile_uout   [0:31];

assign regfile_out[0]   = 32'b0;
assign regfile_uout[0]  = 32'b0;

genvar regfile_gv;
generate
for(regfile_gv=1; regfile_gv<32; regfile_gv=regfile_gv+1) begin:regfile_gen
    assign regfile_out[regfile_gv] = regfile_r[regfile_gv];
end
for(regfile_gv=1; regfile_gv<32; regfile_gv=regfile_gv+1) begin:regfile_gen_unsigned
    assign regfile_uout[regfile_gv] = regfile_r[regfile_gv];
end
endgenerate

//
// pipeline general
//

localparam ALU_OP_SEL_ZERO = 4'd0;
localparam ALU_OP_SEL_REG  = 4'd1;
localparam ALU_OP_SEL_IMMI = 4'd2;
localparam ALU_OP_SEL_IMMS = 4'd3;
localparam ALU_OP_SEL_IMMB = 4'd4; // if acu result is true!
localparam ALU_OP_SEL_IMMU = 4'd5;
localparam ALU_OP_SEL_IMMJ = 4'd6;
localparam ALU_OP_SEL_PC   = 4'd7;

localparam ALU_RESULT_SEL_REG   = 4'd0; // save result to reg
localparam ALU_RESULT_SEL_PC    = 4'd1; // save result to pc
localparam ALU_RESULT_SEL_PCREG = 4'd2; // save result to pc and result + 4 to rd
localparam ALU_RESULT_SEL_MEM   = 4'd3; // result as memory address and store rs2 to memory 
localparam ALU_RESULT_SEL_MEMREG= 4'd4; // result as memory address and read memory to rd

localparam ALU_SEL_ADD     = 8'd0;
localparam ALU_SEL_SUB     = 8'd1;
localparam ALU_SEL_SLESS   = 8'd2;
localparam ALU_SEL_ULESS   = 8'd3;
localparam ALU_SEL_SGRETER = 8'd4;
localparam ALU_SEL_UGRETER = 8'd5;
localparam ALU_SEL_XOR     = 8'd6;
localparam ALU_SEL_OR      = 8'd7;
localparam ALU_SEL_AND     = 8'd8;
localparam ALU_SEL_LLSHIFT = 8'd9;
localparam ALU_SEL_LRSHIFT = 8'd10;
localparam ALU_SEL_ARSHIFT = 8'd11;
//
localparam ALU_SEL_SET     = 8'd13; // apply right as mask to left
localparam ALU_SEL_RESET   = 8'd14; // apply right as mask to left
localparam ALU_SEL_EQU     = 8'd15;
localparam ALU_SEL_NEQU    = 8'd16;

localparam ACU_SEL_EQU     = 4'd1; // 
localparam ACU_SEL_NEQU    = 4'd2;
localparam ACU_SEL_SLESS   = 4'd3;
localparam ACU_SEL_ULESS   = 4'd4;
localparam ACU_SEL_SGREATER = 4'd5;
localparam ACU_SEL_UGREATER = 4'd6;
// pipeline stage instructionfetch0
//

reg [31:0] inst_r;
reg [31:0] inst_pc_r;

reg if0_bubble_r;
wire stage_ae1_stall_if;
always @(posedge processor_clk) begin
    if (!processor_resetn) begin
        instbus_haddr_r    <= 32'b0;
        instbus_htrans_r   <= BUS_HTRANS_IDLE;
        instbus_hwrite_r   <= 1'b0;
        instbus_hsize_r    <= 3'b0;
        instbus_hbrust_r   <= 3'b0;
        instbus_hprot_r    <= 4'b0;
        instbus_hwdata_r   <= 32'b0;
        inst_r             <= 32'h00000033;
        inst_pc_r          <= 32'h00B0BB1E;
        if0_bubble_r       <= 1;
    end else begin
        if (stage_ae1_stall_if) begin
            instbus_htrans_r   <= BUS_HTRANS_IDLE;
            inst_r             <= 32'h00000033; // NOP
            inst_pc_r          <= 32'h00B0BB1E;
            if0_bubble_r       <= 1;
        end else begin
            if (instbus_htrans_r == BUS_HTRANS_IDLE) begin
                instbus_haddr_r     <= reg_pc_r;
                instbus_htrans_r    <= BUS_HTRANS_NONSEQ;
                instbus_hwrite_r    <= BUS_HWRITE_READ;
                instbus_hsize_r     <= 3'b010; // a word
                instbus_hbrust_r    <= BUS_HBRUST_SINGLE;
                instbus_hprot_r     <= 4'b0000; // not used
                instbus_hwdata_r    <= 32'b0; // not used

                inst_r              <= instbus_hrdata;
                inst_pc_r           <= instbus_haddr_r;
                if0_bubble_r <= 1;
            end else if (instbus_htrans_r == BUS_HTRANS_NONSEQ && instbus_hready == 1 && instbus_hresp == BUS_HRESP_OKAY ) begin
                instbus_htrans_r    <= BUS_HTRANS_IDLE;
                if0_bubble_r <= 0;
            end else if (instbus_htrans_r == BUS_HTRANS_NONSEQ && instbus_hready == 1 && instbus_hresp == BUS_HRESP_RETRY) begin
                instbus_htrans_r    <= BUS_HTRANS_IDLE;
                if0_bubble_r <= 1;
            end
        end
    end
end

//
// pipeline stage instructiondecode0
// decode and determine data path
//

reg [31:0] inst_id0_r;
reg [31:0] inst_pc_id0_r;

reg [3:0]  alu_leftop_sel_r;
reg [3:0]  alu_rightop_sel_r;
reg [3:0]  alu_result_sel_r;
reg [4:0]  alu_result_reg_sel_r;
reg [7:0]  alu_sel_r;
reg [3:0]  acu_sel_r;

reg signed [31:0] inst_immi_r;
reg signed [31:0] inst_imms_r;
reg signed [31:0] inst_immb_r;
reg signed [31:0] inst_immu_r;
reg signed [31:0] inst_immj_r;

reg id0_bubble_r;
always @(posedge processor_clk) begin
    if (!processor_resetn) begin
        inst_id0_r           <= 32'b0;
        inst_pc_id0_r        <= 32'b0;
        alu_leftop_sel_r     <= 4'b0;
        alu_rightop_sel_r    <= 4'b0;
        alu_result_sel_r     <= 4'b0;
        alu_result_reg_sel_r <= 5'b0;
        alu_sel_r            <= 8'b0;
        acu_sel_r            <= 4'b0;
        inst_immi_r          <= 32'b0;
        inst_imms_r          <= 32'b0;
        inst_immb_r          <= 32'b0;
        inst_immu_r          <= 32'b0;
        inst_immj_r          <= 32'b0;
        id0_bubble_r         <= 1;
    end else begin
        id0_bubble_r <= 0;
        alu_result_reg_sel_r <= inst_r[11:7];
        inst_id0_r           <= inst_r;
        inst_pc_id0_r        <= inst_pc_r;
        if (if0_bubble_r) begin
            $display("Info: ID0 bubbled at PC=0x%x, INST=0x%x", inst_pc_r, inst_r);
            id0_bubble_r <= 1;
        end else begin
            $display("Info: ID0 instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r);
            inst_immi_r <= {{20{inst_r[31]}}, inst_r[31:20]};
            inst_imms_r <= {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};
            inst_immb_r <= {{19{inst_r[31]}}, inst_r[31], inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0};
            inst_immu_r <= {inst_r[31:12], 12'b0};
            inst_immj_r <= {{12{inst_r[31]}}, inst_r[19:12], inst_r[20], inst_r[30:21], 1'b0};
            case(inst_r[6:0])
                7'b0110111: begin // lui
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMU;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    alu_sel_r            <= ALU_SEL_ADD;
                end
                7'b0010111: begin // auipc
                    alu_leftop_sel_r     <= ALU_OP_SEL_PC;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMU;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    alu_sel_r            <= ALU_SEL_ADD;
                end
                7'b1101111: begin // jal
                    alu_leftop_sel_r     <= ALU_OP_SEL_PC;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMJ;
                    alu_result_sel_r     <= ALU_RESULT_SEL_PCREG;
                    alu_sel_r            <= ALU_SEL_ADD;
                end
                7'b1100111: begin // jalr
                    alu_leftop_sel_r     <= ALU_OP_SEL_REG;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMI;
                    alu_result_sel_r     <= ALU_RESULT_SEL_PCREG;
                    alu_sel_r            <= ALU_SEL_ADD;
                end
                7'b0010011: begin // imm-reg operation group
                    alu_leftop_sel_r     <= ALU_OP_SEL_REG;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMI;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    case(inst_r[14:12])
                        3'b000: alu_sel_r        <= ALU_SEL_ADD;     // addi
                        3'b001: alu_sel_r        <= ALU_SEL_LLSHIFT; // slli
                        3'b010: alu_sel_r        <= ALU_SEL_SLESS;   // slti
                        3'b011: alu_sel_r        <= ALU_SEL_ULESS;   // sltiu
                        3'b100: alu_sel_r        <= ALU_SEL_XOR;     // xori
                        3'b110: alu_sel_r        <= ALU_SEL_OR;      // ori
                        3'b111: alu_sel_r        <= ALU_SEL_AND;     // andi
                        3'b101: begin
                            if (inst_r[30] == 1) begin
                                alu_sel_r        <= ALU_SEL_ARSHIFT; // srli
                            end else begin
                                alu_sel_r        <= ALU_SEL_LRSHIFT; // srai
                            end
                        end
                    endcase 
                end
                7'b0110011: begin // reg-reg operation group
                    alu_leftop_sel_r     <= ALU_OP_SEL_REG;
                    alu_rightop_sel_r    <= ALU_OP_SEL_REG;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    case(inst_r[14:12])
                        3'b000: begin
                            if (inst_r[30] == 1) begin
                                alu_sel_r        <= ALU_SEL_SUB; // sub
                            end else begin
                                alu_sel_r        <= ALU_SEL_ADD; // add
                            end
                        end
                        3'b001: alu_sel_r        <= ALU_SEL_LLSHIFT; // sll
                        3'b010: alu_sel_r        <= ALU_SEL_SLESS;   // slt
                        3'b011: alu_sel_r        <= ALU_SEL_ULESS;   // sltu
                        3'b100: alu_sel_r        <= ALU_SEL_XOR;     // xor
                        3'b110: alu_sel_r        <= ALU_SEL_OR;      // or
                        3'b111: alu_sel_r        <= ALU_SEL_AND;     // and
                        3'b101: begin
                            if (inst_r[30] == 1) begin
                                alu_sel_r        <= ALU_SEL_ARSHIFT; // srl
                            end else begin
                                alu_sel_r        <= ALU_SEL_LRSHIFT; // sra
                            end
                        end
                    endcase 
                end
                7'b0001111: begin // fence{.i}
                    // make bubble, we dont have to fence :)
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO;
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    alu_sel_r            <= ALU_SEL_ADD; // NOP
                end
                7'b1110011: begin // ecall/ebrak
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO; // jump to zero
                    alu_rightop_sel_r    <= ALU_OP_SEL_ZERO;
                    alu_result_sel_r     <= ALU_RESULT_SEL_PC;
                    alu_sel_r            <= ALU_SEL_ADD;
                end
                7'b1100011: begin // branch commands
                    alu_leftop_sel_r     <= ALU_OP_SEL_PC;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMB;
                    alu_result_sel_r     <= ALU_RESULT_SEL_PC;
                    alu_sel_r            <= ALU_SEL_ADD;
                    case(inst_r[14:12])
                        3'b000: acu_sel_r        <= ACU_SEL_EQU;         // beq
                        3'b001: acu_sel_r        <= ACU_SEL_NEQU;        // bne
                        3'b100: acu_sel_r        <= ACU_SEL_SLESS;       // blt
                        3'b110: acu_sel_r        <= ACU_SEL_ULESS;       // bltu
                        3'b101: acu_sel_r        <= ACU_SEL_SGREATER;    // bge
                        3'b111: acu_sel_r        <= ACU_SEL_UGREATER;    // bgeu
                    endcase
                end
                7'b0000011: begin // load
                    alu_leftop_sel_r     <= ALU_OP_SEL_REG;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMI;
                    alu_result_sel_r     <= ALU_RESULT_SEL_MEMREG;
                    alu_sel_r            <= ALU_SEL_ADD;
                    case(inst_r[14:12])
                        3'b000: $display("Error: Unsupported LOAD instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r); // lb
                        3'b001: $display("Error: Unsupported LOAD instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r);// lh
                        3'b010: acu_sel_r        <= ACU_SEL_SLESS;       // lw
                        3'b100: $display("Error: Unsupported LOAD instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r); // lbu
                        3'b101: $display("Error: Unsupported LOAD instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r); // lhu
                    endcase
                end
                7'b0100011: begin // store
                    alu_leftop_sel_r     <= ALU_OP_SEL_REG;
                    alu_rightop_sel_r    <= ALU_OP_SEL_IMMS;
                    alu_result_sel_r     <= ALU_RESULT_SEL_MEM;
                    alu_sel_r            <= ALU_SEL_ADD;
                    case(inst_r[14:12])
                        3'b000: $display("Error: Unsupported STORE instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r); // sb
                        3'b001: $display("Error: Unsupported STORE instruction at PC=0x%x, INST=0x%x", inst_pc_r, inst_r); // sh
                        3'b010: acu_sel_r        <= ACU_SEL_SLESS;       // sw
                    endcase
                end
                default: begin
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO;
                    alu_leftop_sel_r     <= ALU_OP_SEL_ZERO;
                    alu_result_sel_r     <= ALU_RESULT_SEL_REG;
                    alu_sel_r            <= ALU_SEL_ADD; // NOP
                end
            endcase
        end
    end
end

//
// pipeline stage instructiondecode1
// fetch operand's actual value
//

//
// imm number unit
wire signed [31:0] inst_imm;


assign inst_imm = alu_rightop_sel_r == ALU_OP_SEL_IMMI ? inst_immi_r :
                  alu_rightop_sel_r == ALU_OP_SEL_IMMS ? inst_imms_r :
                  alu_rightop_sel_r == ALU_OP_SEL_IMMB ? inst_immb_r :
                  alu_rightop_sel_r == ALU_OP_SEL_IMMU ? inst_immu_r :
                  alu_rightop_sel_r == ALU_OP_SEL_IMMJ ? inst_immj_r : 
                  32'b0;
//
// result fast backfeed for rs1/2
wire [4:0] alu_result_reg_sel_ae0_backfeed;
wire signed [31:0] backfeed_last_inst_result;

reg [31:0] ae1_fast_backfeed_rs1_r;
reg [31:0] ae1_fast_backfeed_rs2_r;
reg [31:0] ae1_fast_backfeed_rs1u_r;
reg [31:0] ae1_fast_backfeed_rs2u_r;

wire [31:0] ae1_fast_backfeed_rs1   = inst_id0_r[19:15] == alu_result_reg_sel_ae0_backfeed ? backfeed_last_inst_result : regfile_out[inst_id0_r[19:15]];
wire [31:0] ae1_fast_backfeed_rs2   = inst_id0_r[24:20] == alu_result_reg_sel_ae0_backfeed ? backfeed_last_inst_result : regfile_out[inst_id0_r[24:20]];

wire [31:0] ae1_fast_backfeed_rs1u  = inst_id0_r[19:15] == alu_result_reg_sel_ae0_backfeed ? backfeed_last_inst_result : regfile_uout[inst_id0_r[19:15]];
wire [31:0] ae1_fast_backfeed_rs2u  = inst_id0_r[24:20] == alu_result_reg_sel_ae0_backfeed ? backfeed_last_inst_result : regfile_uout[inst_id0_r[24:20]];
//
// auxiliary comparison unit for branch instructions
reg acu_out;
reg acu_equ_r;
reg acu_nequ_r;
reg acu_sless_r;
reg acu_uless_r;
reg acu_sgreater_r;
reg acu_ugreater_r;
               
reg  signed     [31:0] inst_leftop_r;
wire            [31:0] inst_leftop_uout;
assign inst_leftop_uout = inst_leftop_r;
reg  signed     [31:0] inst_rightop_r;
wire            [31:0] inst_rightop_uout;
assign inst_rightop_uout = inst_rightop_r;

reg [3:0]  alu_result_sel_id1_r;
reg [4:0]  alu_result_reg_sel_id1_r;
reg [31:0] alu_rs2regbypass_id1_r; // bypass for store instructions
reg [7:0]  alu_sel_id1_r;

reg [31:0] inst_pc_id1_r;

reg id1_bubble_r;
always @(posedge processor_clk) begin
    if (!processor_resetn) begin
    inst_leftop_r               <= 32'b0;
    inst_rightop_r              <= 32'b0;
    alu_result_sel_id1_r        <= 4'b0;
    alu_result_reg_sel_id1_r    <= 5'b0;
    alu_rs2regbypass_id1_r      <= 32'b0;
    alu_sel_id1_r               <= 8'b0;
    ae1_fast_backfeed_rs1_r     <= 32'b0;
    ae1_fast_backfeed_rs2_r     <= 32'b0;
    ae1_fast_backfeed_rs1u_r    <= 32'b0;
    ae1_fast_backfeed_rs2u_r    <= 32'b0;
    id1_bubble_r                <= 1;
    end else begin
        ae1_fast_backfeed_rs1_r     <= ae1_fast_backfeed_rs1;
        ae1_fast_backfeed_rs2_r     <= ae1_fast_backfeed_rs2;
        ae1_fast_backfeed_rs1u_r    <= ae1_fast_backfeed_rs1u;
        ae1_fast_backfeed_rs2u_r    <= ae1_fast_backfeed_rs2u;
        alu_result_sel_id1_r        <= alu_result_sel_r;
        alu_result_reg_sel_id1_r    <= alu_result_reg_sel_r;
        alu_rs2regbypass_id1_r      <= ae1_fast_backfeed_rs2;
        alu_sel_id1_r               <= alu_sel_r;
        inst_pc_id1_r               <= inst_pc_id0_r;
        if (id0_bubble_r) begin
            $display("Info: ID1 bubbled at PC=0x%x, INST=0x%x", inst_pc_id0_r, inst_id0_r);
            id1_bubble_r <= 1;
        end else begin
            $display("Info: ID1 instruction at PC=0x%x, INST=0x%x", inst_pc_id0_r, inst_id0_r);
            id1_bubble_r <= 0;
            case (alu_leftop_sel_r)
                ALU_OP_SEL_ZERO: inst_leftop_r <= 32'b0;
                ALU_OP_SEL_REG:  inst_leftop_r <= ae1_fast_backfeed_rs1;
                ALU_OP_SEL_PC:   inst_leftop_r <= inst_pc_id0_r;
                ALU_OP_SEL_IMMI: inst_leftop_r <= inst_imm;
                ALU_OP_SEL_IMMS: inst_leftop_r <= inst_imm;
                ALU_OP_SEL_IMMB: inst_leftop_r <= inst_imm;
                ALU_OP_SEL_IMMU: inst_leftop_r <= inst_imm;
                ALU_OP_SEL_IMMJ: inst_leftop_r <= inst_imm;
            endcase
            case (alu_rightop_sel_r)
                ALU_OP_SEL_ZERO: inst_rightop_r <= 32'b0;
                ALU_OP_SEL_REG:  inst_rightop_r <= ae1_fast_backfeed_rs2;
                ALU_OP_SEL_PC:   inst_rightop_r <= inst_pc_id0_r;
                ALU_OP_SEL_IMMI: inst_rightop_r <= inst_imm;
                ALU_OP_SEL_IMMS: inst_rightop_r <= inst_imm;
                ALU_OP_SEL_IMMB: inst_rightop_r <= inst_imm;
                ALU_OP_SEL_IMMU: inst_rightop_r <= inst_imm;
                ALU_OP_SEL_IMMJ: inst_rightop_r <= inst_imm;
            endcase
        end
    end
end

//
// pipeline stage arithmeticexecution0
// execute arithmetic operations
//
wire signed [31:0] inst_result;
wire        acu_out_ae0;
assign backfeed_last_inst_result = inst_result;

reg [3:0]  alu_result_sel_ae0_r;
reg [4:0]  alu_result_reg_sel_ae0_r;
reg [31:0] alu_rs2regbypass_ae0_r;
reg [31:0] inst_pc_ae0_r;
reg        ae0_bubble_r;

assign alu_result_reg_sel_ae0_backfeed = alu_result_reg_sel_ae0_r;

reg [31:0] alu_add_r;
reg [31:0] alu_sub_r; 
reg [31:0] alu_sless_r;
reg [31:0] alu_uless_r;
reg [31:0] alu_sgreter_r;
reg [31:0] alu_ugreter_r;
reg [31:0] alu_xor_r;
reg [31:0] alu_or_r;
reg [31:0] alu_and_r;
reg [31:0] alu_llshift_r;
reg [31:0] alu_lrshift_r;
reg [31:0] alu_arshift_r;
reg [31:0] alu_set_r;
reg [31:0] alu_reset_r;
reg [31:0] alu_equ_r;
reg [31:0] alu_nequ_r;
always @(posedge processor_clk) begin
    if (!processor_resetn) begin
        alu_add_r        <= 32'b0;
        alu_sub_r        <= 32'b0;
        alu_sless_r      <= 32'b0;
        alu_uless_r      <= 32'b0;
        alu_sgreter_r    <= 32'b0;
        alu_ugreter_r    <= 32'b0;
        alu_xor_r        <= 32'b0;
        alu_or_r         <= 32'b0;
        alu_and_r        <= 32'b0;
        alu_llshift_r    <= 32'b0;
        alu_lrshift_r    <= 32'b0;
        alu_arshift_r    <= 32'b0;
        alu_set_r        <= 32'b0;
        alu_reset_r      <= 32'b0;
        alu_equ_r        <= 32'b0;
        alu_nequ_r       <= 32'b0;
        acu_out          <= 1'b0;
        acu_equ_r        <= 1'b0;
        acu_nequ_r       <= 1'b0;
        acu_sless_r      <= 1'b0;
        acu_uless_r      <= 1'b0;
        acu_sgreater_r   <= 1'b0;
        acu_ugreater_r   <= 1'b0;
        ae0_bubble_r     <= 1;
    end else begin
        alu_result_sel_ae0_r        <= alu_result_sel_id1_r;
        alu_result_reg_sel_ae0_r    <= alu_result_reg_sel_id1_r;
        alu_rs2regbypass_ae0_r      <= alu_rs2regbypass_id1_r;
        inst_pc_ae0_r               <= inst_pc_id1_r;
        if (id1_bubble_r) begin
            $display("Info: AE0 bubbled at PC=0x%x", inst_pc_id1_r);
            ae0_bubble_r <= 1;
        end else begin
            $display("Info: AE0 instruction at PC=0x%x", inst_pc_id1_r);
            ae0_bubble_r <= 0;
            acu_equ_r       <= (ae1_fast_backfeed_rs1_r  == ae1_fast_backfeed_rs2_r);
            acu_nequ_r      <= (ae1_fast_backfeed_rs1_r  != ae1_fast_backfeed_rs2_r);
            acu_sless_r     <= (ae1_fast_backfeed_rs1_r  <  ae1_fast_backfeed_rs2_r);
            acu_uless_r     <= (ae1_fast_backfeed_rs1u_r <  ae1_fast_backfeed_rs2u_r);
            acu_sgreater_r  <= (ae1_fast_backfeed_rs1_r  >  ae1_fast_backfeed_rs2_r); 
            acu_ugreater_r  <= (ae1_fast_backfeed_rs1u_r >  ae1_fast_backfeed_rs2u_r);
            alu_add_r     <= inst_leftop_r + inst_rightop_r;
            alu_sub_r     <= inst_leftop_r - inst_rightop_r;
            alu_sless_r   <= {31'b0, inst_leftop_r < inst_rightop_r};
            alu_uless_r   <= {31'b0, inst_leftop_uout < inst_rightop_uout};
            alu_sgreter_r <= {31'b0, inst_leftop_r > inst_rightop_r};
            alu_ugreter_r <= {31'b0, inst_leftop_uout > inst_rightop_uout};
            alu_equ_r     <= {31'b0, inst_leftop_r == inst_rightop_r};
            alu_nequ_r    <= {31'b0, inst_leftop_r != inst_rightop_r};
            alu_xor_r     <= inst_leftop_r ^ inst_rightop_r;
            alu_or_r      <= inst_leftop_r | inst_rightop_r;
            alu_and_r     <= inst_leftop_r & inst_rightop_r;
            alu_llshift_r <= inst_leftop_r << inst_rightop_uout[4:0];
            alu_lrshift_r <= inst_leftop_r >> inst_rightop_uout[4:0];
            alu_arshift_r <= inst_leftop_r >>> inst_rightop_uout[4:0];
            alu_set_r     <= inst_leftop_r | inst_rightop_r;
            alu_reset_r   <= inst_leftop_r & ~inst_rightop_r;
        end
    end
end

assign inst_result = 
    (alu_sel_id1_r == ALU_SEL_ADD)     ? alu_add_r :
    (alu_sel_id1_r == ALU_SEL_SUB)     ? alu_sub_r :
    (alu_sel_id1_r == ALU_SEL_SLESS)   ? alu_sless_r :
    (alu_sel_id1_r == ALU_SEL_ULESS)   ? alu_uless_r :
    (alu_sel_id1_r == ALU_SEL_SGRETER) ? alu_sgreter_r :
    (alu_sel_id1_r == ALU_SEL_UGRETER) ? alu_ugreter_r :
    (alu_sel_id1_r == ALU_SEL_XOR)     ? alu_xor_r :
    (alu_sel_id1_r == ALU_SEL_OR)      ? alu_or_r :
    (alu_sel_id1_r == ALU_SEL_AND)     ? alu_and_r :
    (alu_sel_id1_r == ALU_SEL_LLSHIFT) ? alu_llshift_r :
    (alu_sel_id1_r == ALU_SEL_LRSHIFT) ? alu_lrshift_r :
    (alu_sel_id1_r == ALU_SEL_ARSHIFT) ? alu_arshift_r :
    (alu_sel_id1_r == ALU_SEL_SET)     ? alu_set_r :
    (alu_sel_id1_r == ALU_SEL_RESET)   ? alu_reset_r :
    (alu_sel_id1_r == ALU_SEL_EQU)     ? alu_equ_r :
    (alu_sel_id1_r == ALU_SEL_NEQU)    ? alu_nequ_r :
    32'b0;

assign acu_out_ae0 = 
    (acu_sel_r == ACU_SEL_EQU)      ? acu_equ_r :
    (acu_sel_r == ACU_SEL_NEQU)     ? acu_nequ_r :
    (acu_sel_r == ACU_SEL_SLESS)    ? acu_sless_r :
    (acu_sel_r == ACU_SEL_ULESS)    ? acu_uless_r :
    (acu_sel_r == ACU_SEL_SGREATER) ? acu_sgreater_r :
    (acu_sel_r == ACU_SEL_UGREATER) ? acu_ugreater_r :
    1'b0;

//
// pipeline stage arithmeticexecution1
// execute control operations
//
reg [31:0]  inst_memory_address_r;
reg [31:0]  inst_memory_data_r;     // when inst_memory_access=0, this field bypassed register data
reg [4:0]   inst_memory_reg_sel_r;  // when inst_memory_access=0, this field bypassed register sel
reg         inst_memory_write;
reg         inst_memory_access;

reg [3:0]   stage_ae1_stall_if_r;
assign  stage_ae1_stall_if = stage_ae1_stall_if_r > 0;

always @(posedge processor_clk) begin
    if (!processor_resetn) begin
        stage_ae1_stall_if_r        <= 0;
        inst_memory_address_r       <= 32'b0;
        inst_memory_data_r          <= 32'b0;
        inst_memory_reg_sel_r       <= 5'b0;
        inst_memory_write           <= 1'b0;
        inst_memory_access          <= 1'b0;
        reg_pc_r                    <= 1'b0;
    end else begin
        if (ae0_bubble_r || stage_ae1_stall_if) begin
            // bubble and do nothing
            $display("Info: AE1 bubbled at PC=0x%x", inst_pc_ae0_r);
            inst_memory_access      <= 0;
            inst_memory_reg_sel_r   <= 0;
            inst_memory_data_r      <= 32'h0B0BB1E; // aka. BUBBLE
            inst_memory_address_r   <= 32'h0B0BB1E;
            
            if (stage_ae1_stall_if) begin
                stage_ae1_stall_if_r <= stage_ae1_stall_if_r - 4'b1;
            end 
        end else begin
            $display("Info: AE1 instruction at PC=0x%x", inst_pc_ae0_r);
            case (alu_result_sel_ae0_r)
                ALU_RESULT_SEL_REG: begin
                    reg_pc_r                <= reg_pc_r + 4;
                    inst_memory_data_r      <= inst_result;
                    inst_memory_reg_sel_r   <= alu_result_reg_sel_ae0_r;
                    inst_memory_access      <= 0;
                end
                ALU_RESULT_SEL_PC: begin
                    if (acu_out_ae0) begin
                        $display("Info: ALU_RESULT_SEL_PC to %x", inst_result);
                        reg_pc_r                <= inst_result;
                        stage_ae1_stall_if_r    <= 4; // flush the pipeline
                    end else begin
                        reg_pc_r                <= inst_pc_ae0_r + 4;
                    end
                    inst_memory_reg_sel_r   <= 0;
                    inst_memory_access      <= 0;
                end
                ALU_RESULT_SEL_PCREG: begin
                    $display("Info: ALU_RESULT_SEL_PCREG to %x", inst_result);
                    reg_pc_r                <= inst_result;
                    stage_ae1_stall_if_r    <= 4; // flush the pipeline
                    inst_memory_data_r      <= inst_pc_ae0_r + 4; // Use original PC+4
                    inst_memory_reg_sel_r   <= alu_result_reg_sel_ae0_r;
                    inst_memory_access      <= 0;
                end
                ALU_RESULT_SEL_MEM: begin
                    reg_pc_r                <= reg_pc_r + 4;
                    inst_memory_write       <= 1;
                    inst_memory_data_r      <= alu_rs2regbypass_ae0_r;
                    inst_memory_address_r   <= inst_result;
                    inst_memory_access      <= 1;
                    
                end
                ALU_RESULT_SEL_MEMREG: begin
                    reg_pc_r                <= reg_pc_r + 4;
                    inst_memory_write       <= 0;
                    inst_memory_reg_sel_r   <= alu_result_reg_sel_ae0_r;
                    inst_memory_address_r   <= inst_result;
                    inst_memory_access      <= 1;
                end
            endcase
        end
    end
end

//
// pipeline stage memoryaccess0
//

always @(posedge processor_clk) begin
    if (!processor_resetn) begin
        databus_haddr_r             <= 32'b0;
        databus_htrans_r            <= BUS_HTRANS_IDLE;
        databus_hwrite_r            <= 1'b0;
        databus_hsize_r             <= 3'b0;
        databus_hbrust_r            <= 3'b0;
        databus_hprot_r             <= 4'b0;
        databus_hwdata_r            <= 32'b0;
    end else begin
        if (0) begin // bubble statement is present on arithmeticexecution0
            // bubble and do nothing
        end else begin
        
            // memory access channel
            if (databus_htrans_r == BUS_HTRANS_IDLE && inst_memory_access) begin
                databus_haddr_r     <= inst_memory_address_r;
                databus_htrans_r    <= BUS_HTRANS_NONSEQ;
                databus_hwrite_r    <= inst_memory_write ? BUS_HWRITE_WRITE : BUS_HWRITE_READ;
                databus_hsize_r     <= 3'b010; // a word
                databus_hbrust_r    <= BUS_HBRUST_SINGLE;
                databus_hprot_r     <= 4'b0000; // not used
                databus_hwdata_r    <= inst_memory_data_r;
            end else if (databus_htrans_r == BUS_HTRANS_NONSEQ && databus_hready == 1) begin
                databus_htrans_r    <= BUS_HTRANS_IDLE;
                if (databus_hresp == BUS_HRESP_OKAY) begin
                    if (!inst_memory_write) begin
                        regfile_r[inst_memory_reg_sel_r] <= databus_hrdata;
                    end
                end else begin
                    databus_htrans_r    <= BUS_HTRANS_IDLE;
                end
            end else begin
                // register access channel
                regfile_r[inst_memory_reg_sel_r] <= inst_memory_data_r;
            end
        end
    end
end

endmodule