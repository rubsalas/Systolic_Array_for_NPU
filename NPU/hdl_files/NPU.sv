// ===============================================================
//  NPU.sv     –  Top-level que integra un systolic array
// ===============================================================

`timescale 1ns/1ps
import pkg_systolic::*;

module NPU #(
    parameter int M = 4,
    parameter int K = 4         // profundidad de la MAC
)(
    input  logic clk,
    input  logic rst,

    input  logic start,

    output logic busy,
    output logic done
);
    // Tienen que ser inputs
    s16_t a_mat [0:K-1][0:K-1];     // matriz A
    s16_t b_mat [0:K-1][0:K-1];     // matriz B

    // Tiene que ser output
    s32_t c_mat [0:K-1][0:K-1];     // matriz resultante

    // Control Unit wires
    logic result_done;     // pulso por banda C
    logic valid_stream;

    /*------------ Control Unit ----------------*/
    control_unit #(
        .K(K)
    ) CU (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .matrix_done    (result_done),      // pulso único del systolic_array
        .valid_out      (valid_stream),     // feeder
        .busy           (busy),
        .done           (done)
    );

    // Matrix Feeder wires
    s16_t a_col0 [0:K-1];           // columna de A
    s16_t b_row0 [0:K-1];           // fila de B
    logic data_validity [0:K-1];    // habilita stream

    /*------------ Matrix Feeder ---------------*/
    matrix_feeder #(
        .K(K)
    ) feeder (
        .clk        (clk),
        .rst        (rst),
        .a_mat      (a_mat),
        .b_mat      (b_mat),
        .valid_in   (valid_stream),
        .a_col0     (a_col0),
        .b_row0     (b_row0),
        .valid_out  (data_validity)
    );

    /*------------ Systolic Array --------------*/
    systolic_array #(
        .M (M),
        .K (K)
    ) u_array (
        .clk      (clk),
        .rst      (rst),
        .a_col0   (a_col0),
        .b_row0   (b_row0),
        .valid_in (data_validity),
        .c_mat    (c_mat),
        .c_valid  (result_done)
    );

endmodule
