`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 15:21:41
// Design Name: 
// Module Name: QPU
// Project Name: 
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

module QPU(
    // for qpu output
    output  reg [`RS_INFO_WIDTH-1:0] rs_qpuout_data,
    output  reg rs_qpuout_en,  
    // for the gate decoder
    input  wire [`QG_INFO_WIDTH-1:0] qg_info_data,
    // for the rs buffer
    input  wire [`RS_INFO_WIDTH-1:0] rs_qpuin_data,
    input  wire [`RS_ADDR_WIDTH-1:0] rs_qpuin_addr,
    input  wire rs_qpuin_clr,      
    input  wire rs_qpuin_en,      

    input  wire qg_enable,  // to load the gate info on the xbar
    input  wire rs_enable,  // to load the rs vector on the xbar

    input  wire clock,
    input  wire nreset);

//////////////////////////////////////////////////////////////////////////////////
// internal wires 
//////////////////////////////////////////////////////////////////////////////////

// for qpuout
reg rs_qpuout_done;

// for gate decoder
wire [`RS_ADDR_WIDTH-1:0] qb_ctrl_addr;
wire [`RS_ADDR_WIDTH-1:0] qb_targ_addr;
wire [`QG_AMPL_WIDTH-1:0] qg_real_data;
wire [`QG_AMPL_WIDTH-1:0] qg_imag_data;
wire b_single_gate;

// for reorder unit
wire [`RS_INFO_WIDTH-1:0] rs_reorder_data_0;
wire [`RS_INFO_WIDTH-1:0] rs_reorder_data_1;
wire rs_reorder_hold;
wire rs_reorder_busy;
wire rs_reorder_flag;
wire rs_reorder_end;

wire [`RS_ADDR_WIDTH-1:0] rs_buffer_size;
wire [`RS_INFO_WIDTH-1:0] rs_buffer_data;
wire [`RS_ADDR_WIDTH-1:0] rs_buffer_addr;
wire rs_buffer_ren;
wire rs_buffer_cam;

// for vmm unit
wire [`RS_INFO_WIDTH-1:0] xbar_out_data;
wire xbar_out_done;
wire xbar_out_en;

reg  [`XB_ADDR_WIDTH-1:0] xbar_row_addr;
reg  xbar_row_wen;

//////////////////////////////////////////////////////////////////////////////////
// QPU Controller - gate information loading
//////////////////////////////////////////////////////////////////////////////////

parameter STATE_GAT_IDLE = 1'd0;                    // qpu idle
parameter STATE_GAT_LOAD = STATE_GAT_IDLE + 1'd1;   // gate load

// gate idle/load
reg gat_ctrl_state;     

// check whether loading rsv is completed.
wire b_gat_loaded = (xbar_row_addr == `XB_ELEM_WIDTH-1); 

// state machine for gate loading
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        gat_ctrl_state <= STATE_GAT_IDLE;
    end
    else begin
        case(gat_ctrl_state)
            STATE_GAT_IDLE: begin
                if(qg_enable)      gat_ctrl_state <= STATE_GAT_LOAD;
                else               gat_ctrl_state <= gat_ctrl_state; 
            end 
            STATE_GAT_LOAD: begin
                if(b_gat_loaded)   gat_ctrl_state <= STATE_GAT_IDLE;
                else               gat_ctrl_state <= gat_ctrl_state;
            end
            default:               gat_ctrl_state <= gat_ctrl_state;
        endcase
    end
end

// to increase the row address of the xbar on loading the gate info.
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_row_addr <= `XB_ADDR_WIDTH'd0;
    end
    else if(gat_ctrl_state == STATE_GAT_LOAD) begin
        if(b_gat_loaded)    xbar_row_addr <= `XB_ADDR_WIDTH'd0;
        else                xbar_row_addr <= xbar_row_addr + `XB_ADDR_WIDTH'd1;
    end
    else begin
        xbar_row_addr <= `XB_ADDR_WIDTH'd0;
    end
end

// to enable loading the gate info. to the xbar row buffer
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_row_wen <= 1'b0;
    end
    else if(qg_enable) begin
        xbar_row_wen <= 1'b1;
    end
    else if(b_gat_loaded) begin
        xbar_row_wen <= 1'b0;
    end
    else begin
        xbar_row_wen <= xbar_row_wen;
    end
end

//////////////////////////////////////////////////////////////////////////////////
// QPU Controller - rsv load and multiplication 
//////////////////////////////////////////////////////////////////////////////////

parameter STATE_RSV_IDLE = 2'd0;
parameter STATE_RSV_LOAD = STATE_RSV_IDLE + 2'd1;   // rsv load
parameter STATE_RSV_MULT = STATE_RSV_LOAD + 2'd1;   // rsv multiply
parameter STATE_RSV_OUTP = STATE_RSV_MULT + 2'd1;   // rsv output

// for xbar rsv buffer 
reg [`XB_ADDR_WIDTH-1:0] xbar_rsv_addr;
reg xbar_vmm_en;

// rsv idle/load/mult
reg [1:0] rsv_ctrl_state;     

// reorder end with 1 cycle delay
reg rs_reorder_end_1d;

always @(posedge clock) begin
    rs_reorder_end_1d <= rs_reorder_end;
end

// state machine for rsv loading and vmm
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        rsv_ctrl_state <= STATE_RSV_IDLE;
    end
    else begin
        case(rsv_ctrl_state)
            STATE_RSV_IDLE: begin
                if(rs_buffer_ren)           rsv_ctrl_state <= STATE_RSV_LOAD;
                else                        rsv_ctrl_state <= rsv_ctrl_state; 
            end 
            STATE_RSV_LOAD: begin
                if(rs_reorder_end | rs_reorder_hold) begin
                    rsv_ctrl_state <= STATE_RSV_MULT;
                end
                else begin
                    rsv_ctrl_state <= rsv_ctrl_state;
                end
            end
            STATE_RSV_MULT: begin
                if(rs_reorder_end_1d)       rsv_ctrl_state <= STATE_RSV_IDLE;
                else                        rsv_ctrl_state <= STATE_RSV_OUTP;
            end
            STATE_RSV_OUTP: begin
                if(rs_reorder_end_1d)       rsv_ctrl_state <= STATE_RSV_IDLE;
                else if(xbar_out_done)      rsv_ctrl_state <= STATE_RSV_LOAD;
                else                        rsv_ctrl_state <= rsv_ctrl_state;
            end
        endcase
    end
end

// to increase the rsv index of the crossbar on the rsv loading
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        xbar_rsv_addr <= `XB_ADDR_WIDTH'd0;
    end
    else if(rs_reorder_busy & rs_reorder_flag) begin
        xbar_rsv_addr <= xbar_rsv_addr + `XB_ADDR_WIDTH'd2;
    end
    else begin
        xbar_rsv_addr <= `XB_ADDR_WIDTH'd0;
    end
end

// to enable the vector-matrix multiplication using the crossbar
reg xbar_vmm_en_p1;

always @(*) begin
    xbar_vmm_en_p1 <= (rsv_ctrl_state == STATE_RSV_MULT);
end

always @(posedge clock) begin
    xbar_vmm_en <= xbar_vmm_en_p1;
end

//////////////////////////////////////////////////////////////////////////////////
// QPU Controller - qpu simulation output 
//////////////////////////////////////////////////////////////////////////////////

parameter STATE_OUT_IDLE = 1'd0;
parameter STATE_OUT_VMMR = STATE_OUT_IDLE + 1'd1;   // output 

// output idle/concat
reg out_ctrl_state;     

// state machine for qpu output
always @(posedge clock or negedge nreset) begin
    if(!nreset) begin
        out_ctrl_state <= STATE_OUT_IDLE;
    end
    else begin
        case(out_ctrl_state)
            STATE_OUT_IDLE: begin
                if(xbar_vmm_en)      out_ctrl_state <= STATE_OUT_VMMR;
                else                 out_ctrl_state <= out_ctrl_state; 
            end 
            STATE_OUT_VMMR: begin
                if(rs_qpuout_done)   out_ctrl_state <= STATE_OUT_IDLE;
                else                 out_ctrl_state <= out_ctrl_state;
            end
        endcase
    end
end

// qpu output eanble
always @(*) begin
    if(rs_reorder_busy & ~rs_reorder_flag) begin
        // non-reordered output
        rs_qpuout_en <= 1'b1;
    end
    else if(out_ctrl_state == STATE_OUT_VMMR) begin
        // reordered & vmm output
        rs_qpuout_en <= xbar_out_en;
    end
    else begin
        rs_qpuout_en <= 1'b0;
    end
end

always @(*) begin
    if(rs_reorder_busy & ~rs_reorder_flag) begin
        // non-reordered output
        rs_qpuout_data <= rs_reorder_data_0;
    end
    else if(xbar_out_en) begin
        // reordered & vmm output
        rs_qpuout_data <= xbar_out_data;
    end
    else begin
        rs_qpuout_data <= {`RS_INFO_WIDTH{1'b0}};
    end
end

//////////////////////////////////////////////////////////////////////////////////
// internal modules 
//////////////////////////////////////////////////////////////////////////////////

// rsv buffer
RSVBuffer rsv_buffer(
    // for the reorder buffer 
    .rs_buffer_size(rs_buffer_size),
    .rs_output_data(rs_buffer_data),
    .rs_output_addr(rs_buffer_addr),  
    .rs_output_cam(rs_buffer_cam),  
    .rs_output_ren(rs_buffer_ren),  
    .rs_buffer_clr(rs_qpuin_clr), 
    // qpu input 
    .rs_input_data(rs_qpuin_data),
    .rs_input_addr(rs_qpuin_addr),
    .rs_input_wen(rs_qpuin_en), 

    .clock(clock),
    .nreset(nreset));    

// gate decoder
GateDecoder gate_decoder(
    // qpu input
    .qg_info_data(qg_info_data), 
    // for the reorder unit
    .qb_ctrl_addr(qb_ctrl_addr),   
    .qb_targ_addr(qb_targ_addr),
    .b_single_gate(b_single_gate),
    // for the vmm unit
    .qg_real_data(qg_real_data),  
    .qg_imag_data(qg_imag_data),  

    .nreset(nreset),
    .clock(clock));    

// reorder unit
ReorderUnit reorder_unit(
    // for the vmm unit and output buffer
    .rs_reorder_data_0(rs_reorder_data_0),
    .rs_reorder_data_1(rs_reorder_data_1),
    .rs_reorder_hold(rs_reorder_hold),
    .rs_reorder_busy(rs_reorder_busy),
    .rs_reorder_flag(rs_reorder_flag),
    .rs_reorder_end(rs_reorder_end),
    .rs_reorder_resume(xbar_out_done),
    // for the rs buffer
    .rs_buffer_size(rs_buffer_size),
    .rs_buffer_data(rs_buffer_data),
    .rs_buffer_addr(rs_buffer_addr),
    .rs_buffer_ren(rs_buffer_ren),
    .rs_buffer_cam(rs_buffer_cam),
    // for the gate decoder
    .qb_ctrl_addr(qb_ctrl_addr),   
    .qb_targ_addr(qb_targ_addr),   
    .b_single_gate(b_single_gate),

    .enable(rs_enable), 
    .clock(clock),
    .nreset(nreset));

// vmm unit
VMMUnit vmm_unit(
    // vmm output
    .xbar_out_data(xbar_out_data), 
    .xbar_out_done(xbar_out_done),
    .xbar_out_en(xbar_out_en),
    // gate decoder input
    .qg_real_data(qg_real_data),   
    .qg_imag_data(qg_imag_data),   
    // qpu control
    .xbar_row_addr(xbar_row_addr),
    .xbar_rsv_addr(xbar_rsv_addr),
    .xbar_row_wen(xbar_row_wen),
    .xbar_rsv_wen(rs_reorder_busy & rs_reorder_flag),
    .xbar_vmm_en(xbar_vmm_en),
    // reordered rs input
    .rs_data_info_0(rs_reorder_data_0),   
    .rs_data_info_1(rs_reorder_data_1),   
    
    .clock(clock),
    .nreset(nreset));

endmodule
