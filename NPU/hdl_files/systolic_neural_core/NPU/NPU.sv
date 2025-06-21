//------------------------------------------------------------------------------
// NPU.sv  –  Neural Processing Unit (NPU) top-level
//
//   • Orquesta el flujo completo: Control Unit → Matrix Feeder → Systolic Array.
//   • Recibe matrices A y B (K×K), genera streams de datos y arranca la malla.
//   • Permite bypass o aplicación de ReLU en cada PE controlado por use_relu.
//   • Expone performance counters por PE y totales agregados.
//
//   Parametrización
//   --------------
//     K       : dimensión de la malla (PEs = K×K) y profundidad de la MAC.
//     P       : anchura en bits de los performance counters.
//
//   Puertos
//   -------
//     clk                   : reloj de sistema.
//     rst                   : reset síncrono.
//     a_mat[0‥K-1][0‥K-1]   : matriz A de entrada (s16_t).
//     b_mat[0‥K-1][0‥K-1]   : matriz B de entrada (s16_t).
//     start                 : pulso 1-clk para iniciar el bloque.
//     use_relu              : habilita aplicación de ReLU (1) o bypass (0) en los PEs.
//     busy                  : indicador de que el NPU está ocupado.
//     done                  : pulso 1-clk al completar C.
//     c_mat[0‥K-1][0‥K-1]   : matriz de resultados (s32_t).
//     pe_mult_count[...]    : contador de multiplicaciones por PE.
//     pe_sum_count[...]     : contador de sumas por PE.
//     pe_accum_count[...]   : contador de bloques resultantes por PE.
//     total_mult_count      : suma de todas las multiplicaciones de PEs.
//     total_sum_count       : suma de todas las sumas de PEs.
//     total_accum_count     : suma total de los resultados de PEs.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
import pkg_systolic::*;

module NPU #(
    parameter int K = 4,            // tamaño de la malla (PEs = M×M)
    parameter int P = 32            // cantidad de bits para perf. counters
)(
    input  logic clk,
    input  logic rst,

    input  s16_t a_mat [0:K-1][0:K-1],                  // matrices de entrada
    input  s16_t b_mat [0:K-1][0:K-1],
    input  logic use_relu,                              // habilita el uso del relu
    input  logic start,                                 // inicia el bloque

    output logic busy,                                  // 1 → NPU ocupado
    output logic done,                                  // pulso 1-clk C lista
    output s32_t c_mat [0:K-1][0:K-1],                  // resultado
    
    // Performance counters desde el Systolic Array
    output logic [P-1:0] pe_mult_count  [0:K-1][0:K-1],
    output logic [P-1:0] pe_sum_count   [0:K-1][0:K-1],
    output logic [P-1:0] pe_accum_count [0:K-1][0:K-1],

    // Totales agregados
    output logic [P-1:0] total_mult_count,
    output logic [P-1:0] total_sum_count,
    output logic [P-1:0] total_accum_count
);

    // Control Unit wires
    logic result_done;
    logic valid_stream;

    /*------------ Control Unit ----------------*/
    neural_control_unit #(
        .K(K)
    ) neural_controller (
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
        .K(K),
        .P(P)
    ) s_array (
        .clk                (clk),
        .rst                (rst),
        .a_col0             (a_col0),
        .b_row0             (b_row0),
        .valid_in           (data_validity),
        .use_relu           (use_relu),
        
        // matrices de salida
        .c_mat              (c_mat),
        .c_valid            (result_done),

        // performance counters
        .pe_mult_count      (pe_mult_count),
        .pe_sum_count       (pe_sum_count),
        .pe_accum_count     (pe_accum_count),
        .total_mult_count   (total_mult_count),
        .total_sum_count    (total_sum_count),
        .total_accum_count  (total_accum_count)
    );

endmodule
