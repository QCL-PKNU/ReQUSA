`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: ReorderUnit
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

module ReorderUnit(
    // reordered rs output
    output reg [`RS_INFO_WIDTH-1:0] rs_reorder_data_0,
    output reg [`RS_INFO_WIDTH-1:0] rs_reorder_data_1,
    output reg rs_reorder_hold, // to let the vmm unit perform a vmm operation
    output reg rs_reorder_busy, // to indicate whether the reordered rs is outputting
    output reg rs_reorder_flag, // to indicate whether the rs was reordered (1) or not (0)
    output reg rs_reorder_end,  // to indicate that all the rs have been reordered
    input wire rs_reorder_resume, 
    // rs buffer access
    input wire [`RS_ADDR_WIDTH-1:0] rs_buffer_size,
    input wire [`RS_INFO_WIDTH-1:0] rs_buffer_data, // rs output from the rs buffer 
    output reg [`RS_ADDR_WIDTH-1:0] rs_buffer_addr, // rs read address
    output reg rs_buffer_ren,   // to read a rs from the rs buffer
    output reg rs_buffer_cam,
    // gate scheduler input
    input wire [`RS_ADDR_WIDTH-1:0] qb_ctrl_addr,   // control qubit index
    input wire [`RS_ADDR_WIDTH-1:0] qb_targ_addr,   // target qubit index
    input wire b_single_gate,   // single-qubit or not

    input wire enable,
    input wire clock,
    input wire nreset);

parameter STATE_REORDER_IDLE = 2'd0;
parameter STATE_REORDER_BUSY = STATE_REORDER_IDLE + 2'd1;
parameter STATE_REORDER_HOLD = STATE_REORDER_BUSY + 2'd1;

reg [`RS_ADDR_WIDTH-1:0] rs_index; 

// to indicate the end of buffer reading
reg rs_buffer_end;
reg rs_buffer_end_1d;

// to count the number of reordered rs
reg [`XB_ADDR_WIDTH-1:0] rs_xbar_count;

// rs control flag with 1 cycle delay
reg b_controlled;
reg b_controlled_1d;

// pair state
reg b_pair_state;
reg b_pair_state_1d;

//////////////////////////////////////////////////////////////////////////////////
// Reorder State Machine
//
// We use the following rs format:
//   state (RS_ADDR_WIDTH), real ampl. (RS_AMPL_WIDTH), imag. ampl. (RS_AMPL_WIDTH)
//////////////////////////////////////////////////////////////////////////////////

// reorder state
reg [1:0] state;

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        state <= STATE_REORDER_IDLE;
    end
    else begin
        case(state)
            STATE_REORDER_IDLE: begin
                if(enable) begin
                    state <= STATE_REORDER_BUSY;
                end 
                else begin
                    state <= state;
                end
            end
            // to perform reordering of the realized states 
            STATE_REORDER_BUSY: begin
                if(rs_buffer_end) begin
                    state <= STATE_REORDER_IDLE;
                end 
                else if(rs_xbar_count == `XB_GATE_COUNT) begin
                    // to change the state to stop reordering for a single cycle 
                    // if the rsv buffer of the VMMUnit is ready for the multiplication
                    if(~b_pair_state) begin
                        state <= STATE_REORDER_BUSY;
                    end
                    else begin
                        state <= STATE_REORDER_HOLD;
                    end 
                end
                else begin
                    state <= state;
                end
            end
            // to stop reordering while the VMM operation of the VMMUnit is performed
            STATE_REORDER_HOLD: begin       
                if(rs_reorder_resume) begin
                    // to change the state to resume reordering if the VMM operations complete.
                    state <= STATE_REORDER_BUSY;
                end
                else begin
                    state <= state;
                end
            end
            default: state <= state;
        endcase
    end
end

// reordering state
wire b_state_idle = (state == STATE_REORDER_IDLE);  
wire b_state_busy = (state == STATE_REORDER_BUSY);  
wire b_state_hold = (state == STATE_REORDER_HOLD);

//////////////////////////////////////////////////////////////////////////////////
// Reordering Stop/Resume
//
// We need to stop reordering and outputting the rs while the vector-matrix 
// multiplication operations are performed on the VMMUnit.
//////////////////////////////////////////////////////////////////////////////////

// an enable signal to read one rs from the rsv buffer
always @(*) begin
    rs_buffer_ren <= b_state_busy;
end

always @(*) begin
    rs_reorder_hold <= b_state_hold;
end

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_xbar_count <= `XB_ADDR_WIDTH'd0;
    end
    else if(b_state_busy & (b_single_gate | b_controlled_1d) & ~b_pair_state) begin
        rs_xbar_count <= rs_xbar_count + `XB_ADDR_WIDTH'd1;
    end
    else if(b_state_hold) begin
        rs_xbar_count <= `XB_ADDR_WIDTH'd0;
    end
    else begin
        rs_xbar_count <= rs_xbar_count;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Reordering 
//
// We follow Algorithm 2 to reorder the realized states.
//////////////////////////////////////////////////////////////////////////////////

// to indicate the rs is the selected state (0) or its pair state (1)
always @(posedge clock) begin
    b_pair_state_1d <= b_pair_state;
end

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        b_pair_state <= 1'b0;
    end
    else if(b_state_busy) begin
        b_pair_state <= ~b_pair_state;
    end
    else begin
        b_pair_state <= 1'b0;
    end
end

// to indicate whether the rs is controlled(1) or not(0)
always @(*) begin
    b_controlled <= ((rs_buffer_data >> `RS_ELEM_WIDTH) >> qb_ctrl_addr) & b_pair_state;
end

// rs control flag with 1 cycle delay
always @(posedge clock) begin
    b_controlled_1d <= b_controlled;
end

// temporary rs index 
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_index <= `RS_ADDR_WIDTH'd0;
    end
    else if(rs_buffer_end) begin
        rs_index <= `RS_ADDR_WIDTH'd0;
    end
    else if(b_state_busy & b_pair_state) begin
        rs_index <= rs_index + `RS_ADDR_WIDTH'd1;
    end
    else begin
        rs_index <= rs_index;
    end
end

// rs cam mode
always @(*) begin
    rs_buffer_cam <= (b_single_gate | b_controlled) & b_pair_state;
end

// rs buffer access 
always @(*) begin
    if(~b_pair_state) begin
        rs_buffer_addr <= rs_index;
    end
    else begin
        rs_buffer_addr <= (rs_buffer_data >> `RS_ELEM_WIDTH) ^ (`RS_ADDR_WIDTH'b1 << qb_targ_addr);
    end
end

always @(*) begin
    rs_buffer_end <= (rs_index == rs_buffer_size - `RS_ADDR_WIDTH'd1) & b_pair_state;
end

always @(posedge clock) begin
    rs_buffer_end_1d <= rs_buffer_end;
end

//////////////////////////////////////////////////////////////////////////////////
// Reordering Output
//////////////////////////////////////////////////////////////////////////////////

// read enable with 1 cycle delay
reg rs_buffer_ren_1d;
 
// read enable with 1 cycle delay
always @(posedge clock) begin
    rs_buffer_ren_1d <= rs_buffer_ren;
end

// to indicate the end of the reordering process 
always @(posedge clock) begin
    rs_reorder_end <= rs_buffer_end_1d;
end

// to indicate whether the reordered rs is outputting or not
always @(posedge clock) begin
    rs_reorder_busy <= b_pair_state_1d;
end

// to indicate whether the rs is reordered(1) or not(0)
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_reorder_flag <= 1'b0;
    end 
    else if(b_pair_state_1d) begin
        if(b_single_gate | b_controlled_1d) begin
            rs_reorder_flag <= 1'b1;
        end
        else begin
            rs_reorder_flag <= 1'b0;
        end
    end
    else begin
        rs_reorder_flag <= 1'b0;
    end
end

// rs reordered data
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_reorder_data_0 <= {`RS_INFO_WIDTH{1'b0}};
        rs_reorder_data_1 <= {`RS_INFO_WIDTH{1'b0}};
    end 
    else if(rs_buffer_ren_1d) begin
        if(~b_pair_state_1d) begin
            rs_reorder_data_0 <= rs_buffer_data;
            rs_reorder_data_1 <= rs_reorder_data_1;
        end
        else begin
            rs_reorder_data_0 <= rs_reorder_data_0;
            rs_reorder_data_1 <= rs_buffer_data;
        end
    end
    else begin
        rs_reorder_data_0 <= {`RS_INFO_WIDTH{1'b0}};
        rs_reorder_data_1 <= {`RS_INFO_WIDTH{1'b0}};
    end
end

endmodule