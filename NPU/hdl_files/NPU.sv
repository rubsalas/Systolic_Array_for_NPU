// ===============================================================
//  NPU.sv
// ===============================================================
`timescale 1ns/1ps
import pkg_systolic::*;

module NPU #(
    parameter int K      = 3,

    parameter int DATA_W = pkg_systolic::DATA_W,
    parameter int ACC_W  = pkg_systolic::ACC_W
)(
    input  logic clk,
    input  logic rst_n,

    input  s16_t a_in,
    input  s16_t b_in,
    input  logic valid_in,

    output s32_t c_out,
    output logic c_valid
);

    // Dummy wires para las salidas no utilizadas del PE
    s16_t a_unused, b_unused;

	/*
    pe_mac_relu #(.K(K)) u_pe (
        .clk      (clk),
        .rst_n    (rst_n),
        .a_in     (a_in),
        .b_in     (b_in),
        .valid_in (valid_in),
        .a_out    (a_unused),
        .b_out    (b_unused),
        .c_out    (c_out),
        .c_valid  (c_valid)
    );
	 */

endmodule : NPU
