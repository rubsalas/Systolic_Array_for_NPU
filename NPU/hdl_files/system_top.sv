`timescale 1ns/1ps
import pkg_systolic::*;

//=============================================================================
// npu_system_top
//   • Instancia la NPU (systolic array + feeder + CU)
//   • Instancia una RAM sencillo que actúa como memoria global
//   • Conexiones mínimas: clk, rst, interfaces de carga/lectura SW
//=============================================================================
module system_top #(
    parameter int M = 4,
    parameter int K = 4     // dimensión de matriz
)(
    input  logic clk,       // reloj principal
    input  logic rst,       // reset global activo-bajo

    output logic out        // pulso: resultado escrito
);

    s16_t a_mat [0:K-1][0:K-1];     // matriz A
    s16_t b_mat [0:K-1][0:K-1];     // matriz B
    s32_t c_mat [0:K-1][0:K-1];     // matriz resultante

    logic npu_start;
    logic npu_busy;
    logic npu_done;

    //----------------------------------------------------------------------
    // Instancia NPU
    //----------------------------------------------------------------------
    NPU #(
        .M(K),
        .K(K)
    ) u_npu (
        .clk   (clk),
        .rst   (rst),
        .start (npu_start),
        .a_mat (a_mat),
        .b_mat (b_mat),
        .busy  (npu_busy),
        .done  (npu_done),
        .c_mat (c_mat)
    );

    //----------------------------------------------------------------------
    // Instancia RAM
    //----------------------------------------------------------------------



endmodule
