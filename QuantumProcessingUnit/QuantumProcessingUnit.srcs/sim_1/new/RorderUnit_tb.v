`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/02/07 11:22:11
// Design Name: 
// Module Name: RorderUnit_tb
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

module RorderUnit_tb;

// reordered rs output
wire [`RS_ELEM_WIDTH-1:0] rs_reorder_data_0;
wire [`RS_ELEM_WIDTH-1:0] rs_reorder_data_1;
wire rs_reorder_busy;  // on reordering 
wire rs_reorder_flag;  // unreorder or reorder
wire rs_reorder_end;  // stop to reorder
// rs buffer access
wire [`RS_ADDR_WIDTH-1:0] rs_buffer_size;
wire [`RS_INFO_WIDTH-1:0] rs_buffer_data;
wire [`RS_ADDR_WIDTH-1:0] rs_buffer_addr;
wire rs_buffer_ren;
wire rs_buffer_cam;
reg  rs_buffer_clr;

reg  [`RS_INFO_WIDTH-1:0] rs_input_data;
reg  [`RS_ADDR_WIDTH-1:0] rs_input_addr;
reg  rs_input_wen;  // write enable
// gate scheduler input
reg  [`RS_ADDR_WIDTH-1:0] qb_ctrl_addr;   // control qubit index
reg  [`RS_ADDR_WIDTH-1:0] qb_targ_addr;   // target qubit index
reg  b_single_gate;   // single-qubit or not

reg  enable;
reg  clock;
reg  nreset;

RSVBuffer rsv_buffer(
    // rs output 
    .rs_buffer_size(rs_buffer_size),
    .rs_output_data(rs_buffer_data),
    .rs_output_addr(rs_buffer_addr),
    .rs_output_cam(rs_buffer_cam),
    .rs_output_ren(rs_buffer_ren),  
    .rs_buffer_clr(rs_buffer_clr),
    // rs input
    .rs_input_data(rs_input_data),
    .rs_input_addr(rs_input_addr),
    .rs_input_wen(rs_input_wen),  

    .clock(clock),
    .nreset(nreset));

ReorderUnit reorder_unit(
    // reordered rs 
    .rs_reorder_data_0(rs_reorder_data_0),
    .rs_reorder_data_1(rs_reorder_data_1),
    .rs_reorder_busy(rs_reorder_busy),  
    .rs_reorder_flag(rs_reorder_flag), 
    .rs_reorder_end(rs_reorder_end),
    // rs buffer
    .rs_buffer_size(rs_buffer_size),
    .rs_buffer_data(rs_buffer_data),
    .rs_buffer_addr(rs_buffer_addr),
    .rs_buffer_ren(rs_buffer_ren),
    .rs_buffer_cam(rs_buffer_cam),
    // gate scheduler
    .qb_ctrl_addr(qb_ctrl_addr),
    .qb_targ_addr(qb_targ_addr),
    .b_single_gate(b_single_gate),

    .enable(enable),
    .clock(clock),
    .nreset(nreset));

// clock and reset
always #10 clock = ~clock;

initial begin
    clock = 1'b0;
    enable = 1'b0;

    nreset = 1'b1; #20
    nreset = 1'b0; #20
    nreset = 1'b1;
end

// simulation of the reorder unit
initial begin
    // single gate 
    qb_ctrl_addr = `RS_ADDR_WIDTH'h0;
    qb_targ_addr = `RS_ADDR_WIDTH'h1;
    b_single_gate = 1'b0;

    rs_input_wen = 1'b0; 
    rs_buffer_clr = 1'b0; 
    
    #80;

    // write rsv #0~#15
    rs_input_wen = 1'b1;
    rs_input_addr = `RS_ADDR_WIDTH'h0;
    rs_input_data = {`RS_ADDR_WIDTH'h0, `RS_AMPL_WIDTH'h20, `RS_AMPL_WIDTH'hA0};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h1;
    rs_input_data = {`RS_ADDR_WIDTH'h1, `RS_AMPL_WIDTH'h21, `RS_AMPL_WIDTH'hA1};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h2;
    rs_input_data = {`RS_ADDR_WIDTH'h2, `RS_AMPL_WIDTH'h22, `RS_AMPL_WIDTH'hA2};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h3;
    rs_input_data = {`RS_ADDR_WIDTH'h3, `RS_AMPL_WIDTH'h23, `RS_AMPL_WIDTH'hA3};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h4;
    rs_input_data = {`RS_ADDR_WIDTH'h4, `RS_AMPL_WIDTH'h24, `RS_AMPL_WIDTH'hA4};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h5;
    rs_input_data = {`RS_ADDR_WIDTH'h5, `RS_AMPL_WIDTH'h25, `RS_AMPL_WIDTH'hA5};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h6;
    rs_input_data = {`RS_ADDR_WIDTH'h6, `RS_AMPL_WIDTH'h26, `RS_AMPL_WIDTH'hA6};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h7;
    rs_input_data = {`RS_ADDR_WIDTH'h7, `RS_AMPL_WIDTH'h27, `RS_AMPL_WIDTH'hA7};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h8;
    rs_input_data = {`RS_ADDR_WIDTH'h8, `RS_AMPL_WIDTH'h28, `RS_AMPL_WIDTH'hA8};   #20
    rs_input_addr = `RS_ADDR_WIDTH'h9;
    rs_input_data = {`RS_ADDR_WIDTH'h9, `RS_AMPL_WIDTH'h29, `RS_AMPL_WIDTH'hA9};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hA;
    rs_input_data = {`RS_ADDR_WIDTH'hA, `RS_AMPL_WIDTH'h2A, `RS_AMPL_WIDTH'hAA};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hB;
    rs_input_data = {`RS_ADDR_WIDTH'hB, `RS_AMPL_WIDTH'h2B, `RS_AMPL_WIDTH'hAB};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hC;
    rs_input_data = {`RS_ADDR_WIDTH'hC, `RS_AMPL_WIDTH'h2C, `RS_AMPL_WIDTH'hAC};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hD;
    rs_input_data = {`RS_ADDR_WIDTH'hD, `RS_AMPL_WIDTH'h2D, `RS_AMPL_WIDTH'hAD};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hE;
    rs_input_data = {`RS_ADDR_WIDTH'hE, `RS_AMPL_WIDTH'h2E, `RS_AMPL_WIDTH'hAE};   #20
    rs_input_addr = `RS_ADDR_WIDTH'hF;
    rs_input_data = {`RS_ADDR_WIDTH'hF, `RS_AMPL_WIDTH'h2F, `RS_AMPL_WIDTH'hAF};   #20
    rs_input_wen = 1'b0;

    #40;

    enable = 1'b1; #20
    enable = 1'b0;

    #160;

//    while(rs_reorder_busy) begin
//        $display("rs_buffer_addr = 0x%h", rs_buffer_addr);
//    end

    // multiple gate

end

endmodule
