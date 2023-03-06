//////////////////////////////////////////////////////////////////////////////////
// Company: Qauntuam Computing Lab. at Pukyong National University 
// Engineer: Sanghyeon Lee, Leanghok Hour, Youngsun Han
// 
// Create Date: 2023/01/31 14:14:21
// Design Name: 
// Module Name: Params.vh
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

`ifndef __QPU_PARAMS_VH__
`define __QPU_PARAMS_VH__

// realized state 
`define RS_BUFF_SIZE    32  // rs buffer size
`define RS_ADDR_WIDTH   10  // address bit-width for the rs buffer + 1
`define RS_AMPL_WIDTH   8   // bit-width for the rs amplitude
`define RS_ELEM_WIDTH   16  //`RS_AMPL_WIDTH * 2 (real, imag)
`define RS_INFO_WIDTH   26  //`RS_ADDR_WIDTH + `RS_ELEM_WIDTH

// gate decoder
`define QG_GLUT_SIZE    10  // the number of supported gates
`define QG_OPCD_WIDTH   4   // opcode bit-width
`define QG_AMPL_WIDTH   32  // `RS_AMPL_WIDTH * 4
`define QG_INFO_WIDTH   24  // gate info bit-width: [Gate Opcode:4] [Control Qubit Index] [ Target Qubit Index]

// vmm unit
`define XB_GATE_COUNT   4   // the number of gates to be loaded on the crossbar
`define XB_ELEM_WIDTH   8   // `XB_GATE_COUNT * 2;
`define XB_ADDR_WIDTH   3  // address bit-width for the crossbar

`endif