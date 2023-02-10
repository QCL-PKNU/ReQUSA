`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: GateDecoder
// Project Name: ReQUSA (Reram-based QUantum computer Simulation Accelerator)
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "Params.vh"

module GateDecoder(
    // to the reorder unit
    output reg [`RS_ADDR_WIDTH-1:0] qb_ctrl_addr,   // control qubit index
    output reg [`RS_ADDR_WIDTH-1:0] qb_targ_addr,   // target qubit index
    output reg b_single_gate,
    // to the vmm unit
    output reg [`QG_AMPL_WIDTH-1:0] qg_real_data,   // quantum gate amplitude (real) 
    output reg [`QG_AMPL_WIDTH-1:0] qg_imag_data,   // quantum gate amplitude (imag)
    // from the qpu controller
    input wire [`QG_INFO_WIDTH-1:0] qg_info_data,

    input wire nreset,
    input wire clock);

//////////////////////////////////////////////////////////////////////////////////
// Gate Lookup Tables (Real, Imag)
//////////////////////////////////////////////////////////////////////////////////

reg [`QG_AMPL_WIDTH  :0] lut_real[0:`QG_GLUT_SIZE-1];
reg [`QG_AMPL_WIDTH-1:0] lut_imag[0:`QG_GLUT_SIZE-1];

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        lut_real[ 0] <= {`RS_AMPL_WIDTH'h01, `RS_AMPL_WIDTH'h02, `RS_AMPL_WIDTH'h03, `RS_AMPL_WIDTH'h04, 1'b1};  // H
        lut_real[ 1] <= {`RS_AMPL_WIDTH'h11, `RS_AMPL_WIDTH'h12, `RS_AMPL_WIDTH'h13, `RS_AMPL_WIDTH'h14, 1'b1};  // I
        lut_real[ 2] <= {`RS_AMPL_WIDTH'h21, `RS_AMPL_WIDTH'h22, `RS_AMPL_WIDTH'h23, `RS_AMPL_WIDTH'h24, 1'b1};  // X
        lut_real[ 3] <= {`RS_AMPL_WIDTH'h31, `RS_AMPL_WIDTH'h32, `RS_AMPL_WIDTH'h33, `RS_AMPL_WIDTH'h34, 1'b1};  // Y
        lut_real[ 4] <= {`RS_AMPL_WIDTH'h41, `RS_AMPL_WIDTH'h42, `RS_AMPL_WIDTH'h43, `RS_AMPL_WIDTH'h44, 1'b1};  // Z
        lut_real[ 5] <= {`RS_AMPL_WIDTH'h51, `RS_AMPL_WIDTH'h52, `RS_AMPL_WIDTH'h53, `RS_AMPL_WIDTH'h54, 1'b1};  // T
        lut_real[ 6] <= {`RS_AMPL_WIDTH'h61, `RS_AMPL_WIDTH'h62, `RS_AMPL_WIDTH'h63, `RS_AMPL_WIDTH'h64, 1'b1};  // Tdg
        lut_real[ 7] <= {`RS_AMPL_WIDTH'h71, `RS_AMPL_WIDTH'h72, `RS_AMPL_WIDTH'h73, `RS_AMPL_WIDTH'h74, 1'b0};  // CX
        lut_real[ 8] <= {`RS_AMPL_WIDTH'h81, `RS_AMPL_WIDTH'h82, `RS_AMPL_WIDTH'h83, `RS_AMPL_WIDTH'h84, 1'b0};  // CZ
        lut_real[ 9] <= {`RS_AMPL_WIDTH'h91, `RS_AMPL_WIDTH'h92, `RS_AMPL_WIDTH'h93, `RS_AMPL_WIDTH'h94, 1'b0};  // CCX
    end
end

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        lut_imag[ 0] <= {`RS_AMPL_WIDTH'h05, `RS_AMPL_WIDTH'h06, `RS_AMPL_WIDTH'h07, `RS_AMPL_WIDTH'h08};  // H
        lut_imag[ 1] <= {`RS_AMPL_WIDTH'h15, `RS_AMPL_WIDTH'h16, `RS_AMPL_WIDTH'h17, `RS_AMPL_WIDTH'h18};  // I
        lut_imag[ 2] <= {`RS_AMPL_WIDTH'h25, `RS_AMPL_WIDTH'h26, `RS_AMPL_WIDTH'h27, `RS_AMPL_WIDTH'h28};  // X
        lut_imag[ 3] <= {`RS_AMPL_WIDTH'h35, `RS_AMPL_WIDTH'h36, `RS_AMPL_WIDTH'h37, `RS_AMPL_WIDTH'h38};  // Y
        lut_imag[ 4] <= {`RS_AMPL_WIDTH'h45, `RS_AMPL_WIDTH'h46, `RS_AMPL_WIDTH'h47, `RS_AMPL_WIDTH'h48};  // Z
        lut_imag[ 5] <= {`RS_AMPL_WIDTH'h55, `RS_AMPL_WIDTH'h56, `RS_AMPL_WIDTH'h57, `RS_AMPL_WIDTH'h58};  // T
        lut_imag[ 6] <= {`RS_AMPL_WIDTH'h65, `RS_AMPL_WIDTH'h66, `RS_AMPL_WIDTH'h67, `RS_AMPL_WIDTH'h68};  // Tdg
        lut_imag[ 7] <= {`RS_AMPL_WIDTH'h75, `RS_AMPL_WIDTH'h76, `RS_AMPL_WIDTH'h77, `RS_AMPL_WIDTH'h78};  // CX
        lut_imag[ 8] <= {`RS_AMPL_WIDTH'h85, `RS_AMPL_WIDTH'h86, `RS_AMPL_WIDTH'h87, `RS_AMPL_WIDTH'h88};  // CZ
        lut_imag[ 9] <= {`RS_AMPL_WIDTH'h95, `RS_AMPL_WIDTH'h96, `RS_AMPL_WIDTH'h97, `RS_AMPL_WIDTH'h98};  // CCX
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Gate Decoder 
//////////////////////////////////////////////////////////////////////////////////

// gate opcode
reg [`QG_OPCD_WIDTH-1:0] gate_opcode;

always @(*) begin
    gate_opcode <= qg_info_data[`QG_INFO_WIDTH-1:`QG_INFO_WIDTH-`QG_OPCD_WIDTH];
end

// control qubit index
always @(*) begin
    qb_ctrl_addr <= (qg_info_data >> `RS_ADDR_WIDTH) & {`RS_ADDR_WIDTH{1'b1}};
end

// target qubit index
always @(*) begin
    qb_targ_addr <= (qg_info_data) & {`RS_ADDR_WIDTH{1'b1}};
end

// gate amplitude
always @(*) begin
    qg_real_data <= (lut_real[gate_opcode] >> 1);
    qg_imag_data <= (lut_imag[gate_opcode]);
end

// single- or multiple-gate
always @(*) begin
    b_single_gate <= lut_real[gate_opcode][0];
end

endmodule
