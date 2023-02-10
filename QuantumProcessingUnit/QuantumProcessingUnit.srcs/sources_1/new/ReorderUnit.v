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
    output reg [`RS_ELEM_WIDTH-1:0] rs_reorder_data,
    output reg [`RS_ADDR_WIDTH-1:0] rs_reorder_addr,
    output reg rs_reorder_busy, // to indicate whether the reordered rs is outputting
    output reg rs_reorder_flag, // to indicate whether the rs was reordered (1) or not (0)
    output reg rs_reorder_end,  // to indicate that all the rs have been reordered
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

integer i; 
   
// valid bits of the rs buffer entries
reg [`RS_BUFF_SIZE-1:0] rs_valid_bits;
reg [`RS_ADDR_WIDTH-1:0] rs_valid_count;

// the index of the first 0 occurrence
reg [`RS_ADDR_WIDTH-1:0] rs_index; 
reg [`RS_ADDR_WIDTH-1:0] rs_index_1d;

// to determine whether to hold reordering for the VMM unit
reg [`RS_ADDR_WIDTH-1:0] rs_hold_count;

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
                if(rs_hold_count == `XB_ELEM_WIDTH-1) begin
                    // to change the state to stop reordering if the rsv buffer of the VMMUnit is full
                    state <= STATE_REORDER_HOLD;
                end
                else begin
                    state <= state;
                end
            end
            // to stop reordering while the VMM operation of the VMMUnit is performed
            STATE_REORDER_HOLD: begin       
                if(rs_reorder_end) begin
                    state <= STATE_REORDER_IDLE;
                end 
                else if(rs_hold_count == `XB_ELEM_WIDTH-1) begin
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

// an enable signal to read one rs from the rsv buffer
always @(posedge clock or negedge nreset) begin
    if(!nreset)             rs_buffer_ren <= 1'b0;
    else if(b_state_busy)   rs_buffer_ren <= 1'b1;
    else                    rs_buffer_ren <= 1'b0;
end

//////////////////////////////////////////////////////////////////////////////////
// Reordering Stop/Resume
//
// We need to stop reordering and outputting the rs while the vector-matrix 
// multiplication operations are performed on the VMMUnit.
//////////////////////////////////////////////////////////////////////////////////

// to determine whether to stop reordering for the VMMUnit
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_hold_count <= `RS_ADDR_WIDTH'd0;
    end
    else if(b_state_busy || b_state_hold) begin
        // to increase the hold count up to the row width of the crossbar
        if(rs_hold_count == `XB_ELEM_WIDTH-1) begin
            rs_hold_count <= `RS_ADDR_WIDTH'd0;
        end 
        else begin
            rs_hold_count <= rs_hold_count + `RS_ADDR_WIDTH'd1;
        end
    end
    else begin
        rs_hold_count <= `RS_ADDR_WIDTH'd0;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// Reordering 
//
// We follow Algorithm 2 to reorder the realized states.
//////////////////////////////////////////////////////////////////////////////////

// to calculate the index of the rs to be reordered
always @(*) begin
    for (i = `RS_BUFF_SIZE-1; i >= 0; i = i - 1) begin
        if(rs_valid_bits[i] == 1'b0) begin
            rs_index = i;
        end
    end
end

// rs index signal with 1 cycle delay
always @(posedge clock) begin
    rs_index_1d <= rs_index;
end

// to calculate the rs index stride using a target qubit index
wire [`RS_ADDR_WIDTH-1:0] rs_stride = 1 << qb_targ_addr;

// to indicate the rs is the lower(1) or upper(0) state
reg b_lower_state;

always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        b_lower_state <= 1'b1;
    end 
    else if(rs_buffer_ren) begin
        b_lower_state <= ~b_lower_state;
    end
    else begin
        b_lower_state <= b_lower_state;
    end
end

// to indicate whether the rs is controlled(1) or not(0)
wire b_controlled = ((rs_buffer_data >> `RS_ELEM_WIDTH) >> qb_ctrl_addr) & ~b_lower_state;

// rs control flag with 1 cycle delay
reg b_controlled_1d;

always @(posedge clock) begin
    b_controlled_1d <= b_controlled;
end

// rs cam mode
always @(*) begin
    rs_buffer_cam <= (b_single_gate | b_controlled) & ~b_lower_state;
end

// rs buffer access 
always @(*) begin
    if(b_lower_state) begin
        rs_buffer_addr <= rs_index;
    end
    else if(b_single_gate || b_controlled) begin
        rs_buffer_addr <= rs_index_1d + rs_stride;
    end 
    else begin
        rs_buffer_addr <= rs_index;
    end
end

// to check whether the addressed rs has been already reordered
always @(posedge clock or negedge nreset) begin
    if(!nreset || enable) begin
        // reset all the valid bits 
        rs_valid_bits <= {`RS_BUFF_SIZE{1'b0}};
    end
    else if(rs_buffer_ren) begin
        // set the valid bit of the reordered rs
        rs_valid_bits[rs_buffer_addr] <= 1'b1;
    end
    else begin
        rs_valid_bits <= rs_valid_bits;
    end
end

// to calculate the number of reordered rs 
always @(*) begin
    rs_valid_count = 0;

    for (i = 0; i < `RS_BUFF_SIZE; i = i + 1) begin
        rs_valid_count = rs_valid_count + rs_valid_bits[i]; 
    end
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
always @(*) begin
    rs_reorder_end <= (rs_reorder_addr == rs_buffer_size-`RS_ADDR_WIDTH'd1);
end

// to indicate whether the reordered rs is outputting or not
always @(posedge clock) begin
    rs_reorder_busy <= rs_buffer_ren_1d;
end

// to indicate whether the rs is reordered(1) or not(0)
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_reorder_flag <= 1'b0;
    end 
    else if(b_single_gate | b_controlled | b_controlled_1d) begin
        rs_reorder_flag <= 1'b1;
    end
    else begin
        rs_reorder_flag <= 1'b0;
    end
end

// rs reordered data
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_reorder_data <= {`RS_ELEM_WIDTH{1'b0}};
    end 
    else if(rs_buffer_ren_1d) begin
        rs_reorder_data <= rs_buffer_data[`RS_ELEM_WIDTH-1:0];
    end
    else begin
        rs_reorder_data <= {`RS_ELEM_WIDTH{1'b0}};
    end
end

// rs reordered address
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rs_reorder_addr <= {`RS_ADDR_WIDTH{1'b0}};
    end
    else if(rs_reorder_end) begin
        rs_reorder_addr <= {`RS_ADDR_WIDTH{1'b0}};
    end
    else if(rs_reorder_busy) begin
        rs_reorder_addr <= rs_reorder_addr + `RS_ADDR_WIDTH'd1;
    end
    else begin 
        rs_reorder_addr <= rs_reorder_addr;
    end
end

endmodule