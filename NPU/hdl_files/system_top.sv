`timescale 1ns/1ps
import pkg_systolic::*;

//=============================================================================
// npu_system_top
//   • Instancia la NPU (systolic array + feeder + CU)
//   • Instancia una MRAM sencilla que actúa como memoria global
//   • Conexiones mínimas: clk, rst, interfaces de carga/lectura SW
//=============================================================================
module system_top #(
    parameter int M = 4,
    parameter int K = 4     // dimensión de matriz
)(
    input  logic clk,
    input  logic rst,

    output logic out
);

    //--------------------------------------------------------------------------
    // Señales internas para la MRAM (puerto A/B de 16 bits y C de 32 bits)
    //--------------------------------------------------------------------------
    //  – we16/re16: habilitan escritura/lectura de A o B
    //  – mat_sel  : 0→A, 1→B
    //  – addr16   : dirección 0…K*K–1 (fila‐major) para A/B
    //  – din16    : dato de 16 bits a escribir en A/B
    //  – dout16   : dato leído de A/B
    //  – ready16  : pulso 1-clk cuando termina we16 o re16
    //  – stall16  : 1 mientras ready16=0 (back-pressure)
    logic we16;
    logic re16;
    logic mat_sel;
    logic [$clog2(K*K)-1:0] addr16;
    s16_t din16;
    s16_t dout16; 
    logic ready16;
    logic stall16;

    //  – we32/re32: habilitan escritura/lectura de C
    //  – addr32   : dirección 0…K*K–1 para C
    //  – din32    : dato de 32 bits a escribir en C
    //  – dout32   : dato leído de C
    //  – ready32  : pulso 1-clk cuando termina we32 o re32
    //  – stall32  : 1 mientras ready32=0
    logic we32;
    logic re32;
    logic [$clog2(K*K)-1:0] addr32;
    s32_t din32;
    s32_t dout32;
    logic ready32;
    logic stall32;

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena A, B (16 bits) y C (32 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K (K)
    ) u_mram (
        .clk     (clk),
        .rst     (rst),

        // Puerto A/B de 16 bits
        .we16    (we16),  // 1→din16→mem[mat_sel?B:A][addr16]
        .re16    (re16),  // 1→mem[mat_sel?B:A][addr16]→dout16
        .mat_sel (mat_sel),  // 0=A, 1=B
        .addr16  (addr16),   // índice fila-major 0…K*K–1
        .din16   (din16),  // dato de entrada
        .dout16  (dout16),  // dato de salida
        .ready16 (ready16),  // 1-clk cuando la operación acaba
        .stall16 (stall16),  // 1 mientras la memoria no esté lista

        // Puerto C de 32 bits
        .we32    (we32),  // 1→din32→memC[addr32]
        .re32    (re32),  // 1→memC[addr32]→dout32
        .addr32  (addr32),   // índice fila-major 0…K*K–1
        .din32   (din32),  // dato de entrada
        .dout32  (dout32),  // dato de salida
        .ready32 (ready32),  // 1-clk cuando la operación acaba
        .stall32 (stall32)   // 1 mientras la memoria no esté lista
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

endmodule
