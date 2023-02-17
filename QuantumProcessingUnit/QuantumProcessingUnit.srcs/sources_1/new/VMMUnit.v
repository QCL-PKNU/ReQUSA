`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: VMMUnit
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

module VMMUnit(
    // vmm output
    output reg [`RS_ELEM_WIDTH-1:0] rs_output_data,
    input wire [`XB_ADDR_WIDTH-1:0] rs_output_addr,
    input rs_output_ren,
    // gate decoder input
    input wire [`QG_AMPL_WIDTH-1:0] qg_real_data,   
    input wire [`QG_AMPL_WIDTH-1:0] qg_imag_data,   
    // reordered rs input
    input wire [`RS_AMPL_WIDTH-1:0] rs_real_data,
    input wire [`RS_AMPL_WIDTH-1:0] rs_imag_data,
    // qpu control
    input wire [`XB_ADDR_WIDTH-1:0] xbar_row_addr,
    input wire [`XB_ADDR_WIDTH-1:0] xbar_rsv_addr,
    input wire xbar_row_wen, // enable to load the gate info. to the row buffer
    input wire xbar_rsv_wen, // enable to load the rsv to the rsv buffer
    input wire xbar_vmm_men, // enable to perform the vmm
    
    input wire clock,
    input wire nreset);

parameter AMPL_WIDTH_0 = 0;
parameter AMPL_WIDTH_1 = `RS_AMPL_WIDTH;
parameter AMPL_WIDTH_2 = `RS_AMPL_WIDTH * 2;
parameter AMPL_WIDTH_3 = `RS_AMPL_WIDTH * 3;

parameter COL_OFFSET_0 = `XB_ADDR_WIDTH'd0;
parameter COL_OFFSET_1 = `XB_ADDR_WIDTH'd1;

// for loading the gate 
reg [`RS_AMPL_WIDTH-1:0] xbar_row_real_buffer[0:`XB_ELEM_WIDTH-1];
reg [`RS_AMPL_WIDTH-1:0] xbar_row_imag_buffer[0:`XB_ELEM_WIDTH-1];
reg [`XB_ADDR_WIDTH-1:0] xbar_col_addr;
reg xbar_row_wen_1d;

// for loading the rsv 
reg [`RS_AMPL_WIDTH-1:0] xbar_rsv_real_buffer[0:`XB_ELEM_WIDTH-1];
reg [`RS_AMPL_WIDTH-1:0] xbar_rsv_imag_buffer[0:`XB_ELEM_WIDTH-1];

integer i;

//////////////////////////////////////////////////////////////////////////////////
// Quantum Gate Loading
//
// We assume that the gate information can be loaded into the crossbar 
// independently of rsv via the row buffer of the vmm unit.
//////////////////////////////////////////////////////////////////////////////////

// row buffer write enable with 1 cycle delay
always @(posedge clock) begin
    xbar_row_wen_1d <= xbar_row_wen;
end

// calculate the column index using the row index
always @(*) begin
    xbar_col_addr <= xbar_row_addr & ~`XB_ADDR_WIDTH'b1; 
end

// copy the gate amplitudes to the row buffers (real, imag) respectively
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // clear the row buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            xbar_row_real_buffer[i] = {`RS_AMPL_WIDTH{1'b0}};
            xbar_row_imag_buffer[i] = {`RS_AMPL_WIDTH{1'b0}};
        end
    end
    else if(xbar_row_wen) begin
        // first, clear the row buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            xbar_row_real_buffer[i] = {`RS_AMPL_WIDTH{1'b0}};
            xbar_row_imag_buffer[i] = {`RS_AMPL_WIDTH{1'b0}};
        end

        // second, copy the gate amplitudes to the row buffers
        if(!(xbar_row_addr & 1'b1)) begin
            // for odd row address
            xbar_row_real_buffer[xbar_col_addr + COL_OFFSET_0] = (qg_real_data >> AMPL_WIDTH_3) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_real_buffer[xbar_col_addr + COL_OFFSET_1] = (qg_real_data >> AMPL_WIDTH_2) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_imag_buffer[xbar_col_addr + COL_OFFSET_0] = (qg_imag_data >> AMPL_WIDTH_3) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_imag_buffer[xbar_col_addr + COL_OFFSET_1] = (qg_imag_data >> AMPL_WIDTH_2) & {`RS_AMPL_WIDTH{1'b1}};
        end 
        else begin
            // for even row address
            xbar_row_real_buffer[xbar_col_addr + COL_OFFSET_0] = (qg_real_data >> AMPL_WIDTH_1) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_real_buffer[xbar_col_addr + COL_OFFSET_1] = (qg_real_data >> AMPL_WIDTH_0) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_imag_buffer[xbar_col_addr + COL_OFFSET_0] = (qg_imag_data >> AMPL_WIDTH_1) & {`RS_AMPL_WIDTH{1'b1}};
            xbar_row_imag_buffer[xbar_col_addr + COL_OFFSET_1] = (qg_imag_data >> AMPL_WIDTH_0) & {`RS_AMPL_WIDTH{1'b1}};
        end  
    end
    else begin
        // clear the row buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            xbar_row_real_buffer[i] = xbar_row_real_buffer[i];
            xbar_row_imag_buffer[i] = xbar_row_imag_buffer[i];
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Realized States Loading
//
// We assume to use a separate buffer for storing the rsv for the vector-matrix 
// multiplication. The stored rsv is assigned to the crossbar through the PWM array 
// and used to perform the multiplication operations.
//////////////////////////////////////////////////////////////////////////////////

// copy the realized states to the rsv buffer
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // clear the rsv buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            xbar_rsv_real_buffer[i] <= {`RS_AMPL_WIDTH{1'b0}};
            xbar_rsv_imag_buffer[i] <= {`RS_AMPL_WIDTH{1'b0}};
        end
    end
    else if(xbar_rsv_wen) begin
        // copy the given realized states to the rsv buffer
        xbar_rsv_real_buffer[xbar_rsv_addr] <= rs_real_data;
        xbar_rsv_imag_buffer[xbar_rsv_addr] <= rs_imag_data;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// VMM Result Output
//
// We assume that the VMM output of the crossbar is stored in the row buffer. 
// The QPU must obtain the multiplication result from the row buffer of the VMMUnit 
// and pass it to the OutBuffer.
//////////////////////////////////////////////////////////////////////////////////

always @(*) begin
    rs_output_data <= (xbar_row_real_buffer[rs_output_addr] << `RS_AMPL_WIDTH) | xbar_row_imag_buffer[rs_output_addr];
end

//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                        ReRAM Crossbar (Real, Imag)                           //
//                                                                              //
//         Imagine that there is two ReRAM crossbars (Real, Imag) here.         //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

endmodule
