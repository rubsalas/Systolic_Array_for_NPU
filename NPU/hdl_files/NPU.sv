// ============================================================================
//  NPU.sv     –  Top-level que integra un systolic array
// ============================================================================
//  Flujo paso a paso
//    1) El software escribe A y B y lanza `start`.
//    2) `control_unit` genera `valid_out = 1` K ciclos -> el `feeder` envía
//       la columna-k y fila-k de A/B al systolic_array (STREAM).
//    3) Al terminar STREAM, `control_unit` baja `valid_out`; el array drena
//       K-1 ciclos hasta que la matriz C emerge completa y produce un único
//       pulso `c_valid` (reenviado como `done`).
//    4) `done = 1` un ciclo -> matriz C estable en `c_mat`; el sistema puede
//       leerla o lanzar otro `start`.
// ============================================================================

`timescale 1ns/1ps
import pkg_systolic::*;

module NPU #(
    parameter int M = 4,   // tamaño de la malla  (PEs = M×M)
    parameter int K = 4    // profundidad MAC = columnas de A = filas de B
)(
    input  logic clk,
    input  logic rst,

    input  logic  start,                           // inicia el bloque
    input  s16_t  a_mat [0:K-1][0:K-1],            // matrices de entrada
    input  s16_t  b_mat [0:K-1][0:K-1],

    output logic  busy,                            // 1 → NPU ocupado
    output logic  done,                            // pulso 1-clk C lista
    output s32_t  c_mat [0:K-1][0:K-1]             // resultado
);
    
    // Control Unit wires
    logic result_done;
    logic valid_stream;

    /*------------ Control Unit ----------------*/
    control_unit #(
        .K(K)
    ) controller (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .matrix_done    (result_done),      // pulso unico del systolic_array
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
