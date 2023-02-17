`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: OutBuffer
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

module OutBuffer(
    // for QPU output
    output reg [`RS_ELEM_WIDTH-1:0] rs_concat_data, // concatenated output
    input wire [`XB_ADDR_WIDTH-1:0] rs_concat_addr,
    input wire rs_concat_ren,
    // vmm unit output 
    input wire [`RS_ELEM_WIDTH-1:0] rs_vmuout_data, // ordered rs input after vmm from VMMUnit
    // reorder unit output
    input wire [`RS_ELEM_WIDTH-1:0] rs_rouout_data, // non-reordered rs input from ReorderUnit
    input wire [`XB_ADDR_WIDTH-1:0] rs_rouout_addr,
    input wire rs_reorder_flag,
    input wire rs_rouout_wen,

    input wire clock,
    input wire nreset);

integer i;

//////////////////////////////////////////////////////////////////////////////////
// Realized State Input (Non-reordered) 
//////////////////////////////////////////////////////////////////////////////////

// non-reordered rs buffer
reg [`RS_ELEM_WIDTH-1:0] rou_buffer[0:`XB_ELEM_WIDTH-1];

// to keep the non-reordered rs outputs from the reorder unit
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // initialize the rou buffer
        for(i = 0; i < `XB_ELEM_WIDTH; i = i + 1) begin
            rou_buffer[i] <= {`RS_ELEM_WIDTH{1'b0}};
        end
    end 
    else if(rs_rouout_wen) begin
        rou_buffer[rs_rouout_addr] <= rs_rouout_data;
    end
end

// non-reordered rs flag
reg [`XB_ELEM_WIDTH-1:0] rou_flag_bits;

// to indicate whether the rs is reordered(1) or not(0)
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rou_flag_bits <= {`XB_ELEM_WIDTH{1'b0}};
    end 
    else if(rs_rouout_wen) begin
        rou_flag_bits[rs_rouout_addr] <= rs_reorder_flag;
    end
    else begin
        rou_flag_bits <= rou_flag_bits;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Concantenated Output 
//////////////////////////////////////////////////////////////////////////////////

// to return the output by selecting one from the vmm output and the non-reordered rs of the given address
always @(*) begin
    if(rs_concat_ren) begin
        if(rou_flag_bits[rs_concat_addr])  rs_concat_data <= rs_vmuout_data;
        else                               rs_concat_data <= rou_buffer[rs_concat_addr];
    end
    else begin
        rs_concat_data <= {`RS_ELEM_WIDTH{1'b0}};
    end
end

endmodule
