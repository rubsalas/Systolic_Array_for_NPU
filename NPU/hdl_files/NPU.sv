// ===============================================================
//  NPU.sv     –  Top-level que integra un systolic array
// ===============================================================
`timescale 1ns/1ps
import pkg_systolic::*;

module NPU #(
    parameter int M       = 4,                     // dimensión de la malla
    parameter int K       = 4,                     // profundidad de la MAC
    parameter int DATA_W  = pkg_systolic::DATA_W,  // 16
    parameter int ACC_W   = pkg_systolic::ACC_W    // 32
)(
    input  logic                      clk,
    input  logic                      rst,       // activo-bajo global

    output logic                      z
);

    // Interfaz al UUT
    s16_t   a_mat [K-1:0][K-1:0];   // matriz A
    s16_t   b_mat [K-1:0][K-1:0];   // matriz B
    logic   valid_in;               // habilita stream

    // Bordes para systolic array
    s16_t   a_col0 [K-1:0];         // columna de A
    s16_t   b_row0 [K-1:0];         // fila de B
    logic   data_validity [K-1:0];      // habilita stream

    matrix_feeder #(
        .K(K)
    ) feeder (
        .clk        (clk),
        .rst        (rst),
        .a_mat      (a_mat),
        .b_mat      (b_mat),
        .valid_in   (valid_in),
        .a_col0     (a_col0),
        .b_row0     (b_row0),
        .valid_out  (data_validity)
    );

    // Resultado global
    logic c_valid;     // pulso por banda C
    s32_t c_mat [K-1:0][K-1:0]; // matriz resultante

    //----------------------------------------------------------------------
    // Instancia del systolic array
    //----------------------------------------------------------------------
    

endmodule : NPU
