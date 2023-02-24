`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/02/08 10:49:36
// Design Name: 
// Module Name: QPU_tb
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

module QPU_tb;

// for qpu output
wire [`RS_ELEM_WIDTH-1:0] rs_qpuout_data;
wire [`XB_ADDR_WIDTH-1:0] rs_qpuout_addr;
wire rs_qpuout_en;
// for the gate decoder
reg  [`QG_INFO_WIDTH-1:0] qg_info_data;
// for the rs buffer
reg  [`RS_INFO_WIDTH-1:0] rs_qpuin_data;
reg  [`RS_ADDR_WIDTH-1:0] rs_qpuin_addr;
reg  rs_qpuin_clr;
reg  rs_qpuin_en;

reg  qg_enable;
reg  rs_enable;

reg  clock;
reg  nreset;

// clock and reset
always #10 clock = ~clock;

initial begin
    clock = 1'b0;

    nreset = 1'b1; #20
    nreset = 1'b0; #20
    nreset = 1'b1;
end

// simulation of the QPU
initial begin

    qg_enable = 1'b0;
    rs_enable = 1'b0;

    // single qubit gate
    //qg_info_data = {4'd1, 10'd0, 10'd2};

    // multiple qubit gate
    qg_info_data = {4'd7, 10'd0, 10'd3};
    rs_qpuin_en = 1'b0;
    rs_qpuin_clr = 1'b0; 

    rs_qpuin_addr = `RS_ADDR_WIDTH'h0;
    rs_qpuin_data = `RS_INFO_WIDTH'h0;

    #80;

    rs_qpuin_clr = 1'b1;  #20
    rs_qpuin_clr = 1'b0;  #20  

    #40;

    // write rsv #0~#15
    rs_qpuin_en = 1'b1;
    rs_qpuin_addr = `RS_ADDR_WIDTH'h0;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h0, `RS_AMPL_WIDTH'h20, `RS_AMPL_WIDTH'hA0};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h1;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h1, `RS_AMPL_WIDTH'h21, `RS_AMPL_WIDTH'hA1};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h2;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h1, `RS_AMPL_WIDTH'h22, `RS_AMPL_WIDTH'hA2};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h3;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h3, `RS_AMPL_WIDTH'h23, `RS_AMPL_WIDTH'hA3};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h4;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h4, `RS_AMPL_WIDTH'h24, `RS_AMPL_WIDTH'hA4};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h5;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h5, `RS_AMPL_WIDTH'h25, `RS_AMPL_WIDTH'hA5};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h6;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h6, `RS_AMPL_WIDTH'h26, `RS_AMPL_WIDTH'hA6};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h7;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h7, `RS_AMPL_WIDTH'h27, `RS_AMPL_WIDTH'hA7};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h8;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h8, `RS_AMPL_WIDTH'h28, `RS_AMPL_WIDTH'hA8};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'h9;
    rs_qpuin_data = {`RS_ADDR_WIDTH'h9, `RS_AMPL_WIDTH'h29, `RS_AMPL_WIDTH'hA9};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hA;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hA, `RS_AMPL_WIDTH'h2A, `RS_AMPL_WIDTH'hAA};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hB;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hB, `RS_AMPL_WIDTH'h2B, `RS_AMPL_WIDTH'hAB};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hC;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hC, `RS_AMPL_WIDTH'h2C, `RS_AMPL_WIDTH'hAC};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hD;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hD, `RS_AMPL_WIDTH'h2D, `RS_AMPL_WIDTH'hAD};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hE;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hE, `RS_AMPL_WIDTH'h2E, `RS_AMPL_WIDTH'hAE};   #20
    rs_qpuin_addr = `RS_ADDR_WIDTH'hF;
    rs_qpuin_data = {`RS_ADDR_WIDTH'hF, `RS_AMPL_WIDTH'h2F, `RS_AMPL_WIDTH'hAF};   #20
    rs_qpuin_en = 1'b0;

    #40;

    qg_enable = 1'b1;  #20
    qg_enable = 1'b0;

    #160;

    rs_enable = 1'b1;  #20
    rs_enable = 1'b0;
end

QPU qpu(
    .rs_qpuout_data(rs_qpuout_data),
    .rs_qpuout_addr(rs_qpuout_addr),
    .rs_qpuout_en(rs_qpuout_en),  
    .qg_info_data(qg_info_data),
    .rs_qpuin_data(rs_qpuin_data),
    .rs_qpuin_addr(rs_qpuin_addr),
    .rs_qpuin_clr(rs_qpuin_clr),
    .rs_qpuin_en(rs_qpuin_en),      
    .qg_enable(qg_enable),
    .rs_enable(rs_enable),
    .clock(clock),
    .nreset(nreset));

endmodule
