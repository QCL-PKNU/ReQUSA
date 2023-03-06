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
// s
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "Params.vh"

module VMMUnit(
    // vmm output
    output reg [`RS_INFO_WIDTH-1:0] xbar_out_data,
    output reg xbar_out_done,
    output reg xbar_out_en,
    // gate decoder input
    input wire [`QG_AMPL_WIDTH-1:0] qg_real_data,   
    input wire [`QG_AMPL_WIDTH-1:0] qg_imag_data,   
    // reordered rs input
    input wire [`RS_INFO_WIDTH-1:0] rs_data_info_0,
    input wire [`RS_INFO_WIDTH-1:0] rs_data_info_1,
    // qpu control
    input wire [`XB_ADDR_WIDTH-1:0] xbar_row_addr,
    input wire [`XB_ADDR_WIDTH-1:0] xbar_rsv_addr,
    input wire xbar_row_wen, // enable to load the gate info. to the row buffer
    input wire xbar_rsv_wen, // enable to load the rsv to the rsv buffer
    input wire xbar_vmm_en,  // start to multiply
    
    input wire clock,
    input wire nreset);

parameter AMPL_WIDTH_0 = 0;
parameter AMPL_WIDTH_1 = `RS_AMPL_WIDTH;
parameter AMPL_WIDTH_2 = `RS_AMPL_WIDTH * 2;
parameter AMPL_WIDTH_3 = `RS_AMPL_WIDTH * 3;

parameter COL_OFFSET_0 = `XB_ADDR_WIDTH'd0;
parameter COL_OFFSET_1 = `XB_ADDR_WIDTH'd1;

parameter STATE_VMM_IDLE = 1'd0;
parameter STATE_VMM_BUSY = STATE_VMM_IDLE + 1'd1;

// for loading the gate 
reg [`RS_AMPL_WIDTH-1:0] xbar_row_real_buffer[0:`XB_ELEM_WIDTH-1];
reg [`RS_AMPL_WIDTH-1:0] xbar_row_imag_buffer[0:`XB_ELEM_WIDTH-1];
reg [`XB_ADDR_WIDTH-1:0] xbar_col_addr;

// for loading the rsv 
reg [`RS_ADDR_WIDTH-1:0] xbar_rsv_addr_buffer[0:`XB_ELEM_WIDTH-1];
reg [`RS_AMPL_WIDTH-1:0] xbar_rsv_real_buffer[0:`XB_ELEM_WIDTH-1];
reg [`RS_AMPL_WIDTH-1:0] xbar_rsv_imag_buffer[0:`XB_ELEM_WIDTH-1];
reg [`XB_ADDR_WIDTH  :0] xbar_rsv_count;
reg [`XB_ADDR_WIDTH  :0] xbar_rsv_size;

// to output the vmm results
reg [`XB_ADDR_WIDTH-1:0] xbar_out_addr;

//////////////////////////////////////////////////////////////////////////////////
// Quantum Gate Loading
//
// We assume that the gate information can be loaded into the crossbar 
// independently of rsv via the row buffer of the vmm unit.
//////////////////////////////////////////////////////////////////////////////////

// calculate the column index using the row index
always @(*) begin
    xbar_col_addr <= xbar_row_addr & ~`XB_ADDR_WIDTH'b1; 
end

// copy the gate amplitudes to the row buffers (real, imag) respectively
integer i;

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
        if(~(xbar_row_addr & 1'b1)) begin
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

wire [`RS_ADDR_WIDTH-1:0] rs_data_addr_0 = (rs_data_info_0 >> `RS_ELEM_WIDTH);
wire [`RS_AMPL_WIDTH-1:0] rs_real_data_0 = (rs_data_info_0 >> `RS_AMPL_WIDTH) & {`RS_AMPL_WIDTH{1'b1}};
wire [`RS_AMPL_WIDTH-1:0] rs_imag_data_0 = (rs_data_info_0                  ) & {`RS_AMPL_WIDTH{1'b1}};

wire [`RS_ADDR_WIDTH-1:0] rs_data_addr_1 = (rs_data_info_1 >> `RS_ELEM_WIDTH);
wire [`RS_AMPL_WIDTH-1:0] rs_real_data_1 = (rs_data_info_1 >> `RS_AMPL_WIDTH) & {`RS_AMPL_WIDTH{1'b1}};
wire [`RS_AMPL_WIDTH-1:0] rs_imag_data_1 = (rs_data_info_1                  ) & {`RS_AMPL_WIDTH{1'b1}};

// copy the realized states to the rsv buffer
wire [`XB_ADDR_WIDTH-1:0] xbar_rsv_addr_nx = xbar_rsv_addr + `XB_ADDR_WIDTH'd1;

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // clear the rsv buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            xbar_rsv_addr_buffer[i] <= {`RS_ADDR_WIDTH{1'b0}};
            xbar_rsv_real_buffer[i] <= {`RS_AMPL_WIDTH{1'b0}};
            xbar_rsv_imag_buffer[i] <= {`RS_AMPL_WIDTH{1'b0}};
        end
    end
    else if(xbar_rsv_wen) begin
        // copy the given realized states to the rsv buffer
        xbar_rsv_addr_buffer[xbar_rsv_addr   ] <= rs_data_addr_0;
        xbar_rsv_real_buffer[xbar_rsv_addr   ] <= rs_real_data_0;
        xbar_rsv_imag_buffer[xbar_rsv_addr   ] <= rs_imag_data_0;

        xbar_rsv_addr_buffer[xbar_rsv_addr_nx] <= rs_data_addr_1;
        xbar_rsv_real_buffer[xbar_rsv_addr_nx] <= rs_real_data_1;
        xbar_rsv_imag_buffer[xbar_rsv_addr_nx] <= rs_imag_data_1;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// VMM Result Output
//
// We assume that the VMM output of the crossbar is stored in the row buffer. 
// The QPU must obtain the multiplication result from the row buffer of the VMMUnit 
// and return it out of the qpu.
//////////////////////////////////////////////////////////////////////////////////

// the state of the vmm unit
reg state;

wire b_state_idle = (state == STATE_VMM_IDLE);
wire b_state_busy = (state == STATE_VMM_BUSY);

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        state <= STATE_VMM_IDLE;
    end 
    else begin
        case(state) 
            STATE_VMM_IDLE: begin
                if(xbar_vmm_en) state <= STATE_VMM_BUSY;
                else              state <= state;
            end
            STATE_VMM_BUSY: begin
                if(xbar_out_addr == xbar_rsv_size - `XB_ADDR_WIDTH'd1) begin
                    state <= STATE_VMM_IDLE;
                end
                else begin
                    state <= state;
                end
            end 
        endcase
    end
end

// to indicate whether all the vmm output are returned 
always @(*) begin
    xbar_out_done <= (xbar_out_addr == xbar_rsv_size - `XB_ADDR_WIDTH'd1) & b_state_busy;
end

// count the number of buffered realized states
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_rsv_count <= `XB_ADDR_WIDTH'd0;
    end
    else if(b_state_idle & xbar_vmm_en) begin
        xbar_rsv_count <= `XB_ADDR_WIDTH'd0;
    end
    else if(xbar_rsv_wen) begin
        xbar_rsv_count <= xbar_rsv_count + `XB_ADDR_WIDTH'd2;
    end
    else begin
        xbar_rsv_count <= xbar_rsv_count;
    end
end

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_rsv_size <= `XB_ADDR_WIDTH'd0;
    end
    else if(b_state_idle & xbar_vmm_en) begin
        xbar_rsv_size <= xbar_rsv_count;
    end
end

// output address
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_out_addr <= `XB_ADDR_WIDTH'd0;
    end
    else if(b_state_busy) begin
        xbar_out_addr <= xbar_out_addr + `XB_ADDR_WIDTH'd1;
    end
    else begin
        xbar_out_addr <= `XB_ADDR_WIDTH'd0;
    end
end

// output from the vmm unit
wire [`RS_ADDR_WIDTH-1:0] rsv_addr = xbar_rsv_addr_buffer[xbar_out_addr];
wire [`RS_AMPL_WIDTH-1:0] rsv_real = xbar_row_real_buffer[xbar_out_addr];
wire [`RS_AMPL_WIDTH-1:0] rsv_imag = xbar_row_imag_buffer[xbar_out_addr];

always @(*) begin
    xbar_out_data <= {rsv_addr, rsv_real, rsv_imag};
end

always @(*) begin
    if(rsv_real != {`RS_AMPL_WIDTH{1'b0}} || rsv_imag != {`RS_AMPL_WIDTH{1'b0}}) begin
        xbar_out_en <= 1'b1 & b_state_busy;
    end
    else begin
        xbar_out_en <= 1'b0;
    end
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
