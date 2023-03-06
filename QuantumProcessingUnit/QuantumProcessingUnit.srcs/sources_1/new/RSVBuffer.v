`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: RSVBuffer
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

module RSVBuffer(
    // rs output 
    output reg [`RS_ADDR_WIDTH-1:0] rs_buffer_size, // the number of valid rs
    output reg [`RS_INFO_WIDTH-1:0] rs_output_data,
    input wire [`RS_ADDR_WIDTH-1:0] rs_output_addr,  
    input wire rs_output_cam,  // index(0)- or content(1)-addressable mode
    input wire rs_output_ren,  // read enable
    input wire rs_buffer_clr,  // buffer clear
    // rs input
    input wire [`RS_INFO_WIDTH-1:0] rs_input_data,
    input wire [`RS_ADDR_WIDTH-1:0] rs_input_addr,
    input wire rs_input_wen,  // write enable

    input wire clock,
    input wire nreset);

integer i;
    
//////////////////////////////////////////////////////////////////////////////////
// Realized State Input 
//
// We use the following rs format for the buffer:
//   state (RS_ADDR_WIDTH), real ampl. (RS_AMPL_WIDTH), imag. ampl. (RS_AMPL_WIDTH)
//////////////////////////////////////////////////////////////////////////////////

// realized state buffer
reg [`RS_INFO_WIDTH-1:0] rs_buffer[0:`RS_BUFF_SIZE-1];

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // reset all the elements of the buffer
        for(i = 0; i < `RS_BUFF_SIZE; i = i + 1) begin
            rs_buffer[i] <= {`RS_INFO_WIDTH{1'b0}};
        end
    end
    else if(rs_input_wen) begin
        // write the input rs into the element of the buffer at the input address
        rs_buffer[rs_input_addr] <= rs_input_data;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Buffer Size Calculation
//////////////////////////////////////////////////////////////////////////////////

// valid bits of the rs buffer elements 
reg [`RS_BUFF_SIZE-1:0] rs_valid_bits;

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        // reset all the valid bits of the buffer
        rs_valid_bits <= {`RS_BUFF_SIZE{1'b0}};
    end
    else if(rs_buffer_clr) begin
        // reset all the valid bits of the buffer
        rs_valid_bits <= {`RS_BUFF_SIZE{1'b0}};
    end
    else if(rs_input_wen) begin
        // if the element at the input address is written, set the valid bit to 1.
        rs_valid_bits[rs_input_addr] <= 1'b1;
    end
    else begin
        rs_valid_bits <= rs_valid_bits;
    end
end

// return the number of valid rs as the buffer size
always @(*) begin
    rs_buffer_size = 0;

    // count the number of valid rs
    for (i = 0; i < `RS_BUFF_SIZE; i = i + 1) begin
        rs_buffer_size = rs_buffer_size + rs_valid_bits[i]; 
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Realized State Output 
//
// We can output one rs at a time in index- or content-addressable mode.
//////////////////////////////////////////////////////////////////////////////////

// output data
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_output_data <= {`RS_INFO_WIDTH{1'b0}};
    end
    else if(rs_output_ren) begin
        // content-addressable memory mode  
        if(rs_output_cam) begin
            for (i = 0; i < `RS_BUFF_SIZE; i = i + 1) begin
                if ((rs_buffer[i] >> `RS_ELEM_WIDTH) == rs_output_addr) begin
                    rs_output_data <= rs_buffer[i];
                end
            end
        end
        else begin
            // index-addressable memory mode  
            rs_output_data <= rs_buffer[rs_output_addr];
        end
    end
    else begin
        rs_output_data <= {`RS_INFO_WIDTH{1'b0}};
    end
end


    
endmodule