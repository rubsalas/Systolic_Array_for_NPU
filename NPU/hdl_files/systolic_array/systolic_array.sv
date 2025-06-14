//------------------------------------------------------------------------------
// systolic_array.sv
//   • M × M malla de Processing-Elements (PE) con dataflow “Output-Stationary”.
//   • Cada PE multiplica-acumula K productos de 16-bit firmados
//     (resultado 32-bit) y aplica ReLU.
//   • Entradas externas            :  1  columna de A  (a_col0[0‥M-1])
//                                     +  1  fila    de B  (b_row0[0‥M-1])
//                                     +  valid_in  (pulso K ciclos)
//
//   • Salida                       :  matriz C completa  c_mat[M][M]
//                                     +  c_valid  (pulso 1-clk por banda)
//
//   Parametrización
//   --------------
//     M : tamaño de la malla           (PEs = M * M)
//     K : profundidad de la MAC        (= num de columnas de A = num de filas de B)
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module systolic_array #(
    parameter int M = 4,               // tamaño de la malla
    parameter int K = 4                // productos que acumula cada PE
)(
    input  logic                       clk,
    input  logic                       rst,                  // activo-alto

    // Bordes de entrada (1 palabra por ciclo)
    input  s16_t                       a_col0 [0:M-1],           // columna de A
    input  s16_t                       b_row0 [0:M-1],           // fila de B
    input  logic                       valid_in [0:M-1],         // habilita stream
    /* valid_in se pone a 1 exactamente K ciclos por cada banda vertical se quiera procesar. */

    // Resultados
    output s32_t                       c_mat [0:M-1][0:M-1],         // matriz C
    output logic                       c_valid               // pulso banda
);
    //--------------------------------------------------------------------------
    // 1. Señales internas: buses “shift” para A, B y validez
    //--------------------------------------------------------------------------
    s16_t a_bus [0:M-1][0:M];      // [fila][columna+1]  – extra col. para salida
    s16_t b_bus [0:M][0:M-1];      // [fila+1][columna]  – extra fila para salida
    logic v_bus [0:M-1][0:M];      // validez viaja junto a los datos

    //--------------------------------------------------------------------------
    // 2. Inyección de la primera columna / fila (ciclo 0 … K-1)
    //--------------------------------------------------------------------------
    genvar i, j;

    generate
        // -------- Inyección de la primera columna de A y la validez ----------
        for (i = 0; i < M; i = i + 1) begin : INJ_A
            assign a_bus[i][0] = a_col0[i];              // driver externo
            assign v_bus[i][0] = valid_in[i];               // mismo pulso para la fila
        end

        // -------- Inyección de la primera fila de B --------------------------
        for (j = 0; j < M; j = j + 1) begin : INJ_B     // driver externo
            assign b_bus[0][j] = b_row0[j];
        end
    endgenerate

    //--------------------------------------------------------------------------
    // 3. Matriz de PEs  (parámetro K propagado a cada instancia)
    //    • Cada PE lee a_bus[i][j]  &  b_bus[i][j]
    //    • Escribe a_bus[i][j+1]    &  b_bus[i+1][j]   -> efecto “shift”
    //--------------------------------------------------------------------------
    // 1. Un vector packed de M bits (uno por fila):
    logic [0:M-1] c_valid_band;      // bit i = pulso del PE (i, M-1)

    // 2. Sólo la última columna conecta ese bit; las demás NO lo tocan
    generate
        for (i = 0; i < M; i = i + 1) begin : ROW
            for (j = 0; j < M; j = j + 1) begin : COL
                if (j == M-1) begin : LAST
                    pe #(.K(K)) u_pe (
                        .clk       (clk),
                        .rst       (rst),
                        .a_in      (a_bus[i][j]),
                        .b_in      (b_bus[i][j]),
                        .valid_in  (v_bus[i][j]),
                        .a_out     (a_bus[i][j+1]),
                        .b_out     (b_bus[i+1][j]),
                        .valid_out (v_bus[i][j+1]),
                        .c_out     (c_mat[i][j]),
                        .c_valid   (c_valid_band[i])   // único driver por fila
                    );
                end
                else begin : MID
                    pe #(.K(K)) u_pe (
                        .clk       (clk),
                        .rst       (rst),
                        .a_in      (a_bus[i][j]),
                        .b_in      (b_bus[i][j]),
                        .valid_in  (v_bus[i][j]),
                        .a_out     (a_bus[i][j+1]),
                        .b_out     (b_bus[i+1][j]),
                        .valid_out (v_bus[i][j+1]),
                        .c_out     (c_mat[i][j]),
                        .c_valid   ()                 // sin conexión
                    );
                end
            end
        end
    endgenerate

    // 3. El pulso de banda lista es el AND de esos M bits
    assign c_valid = &c_valid_band;   // reducción AND packed → 1-clk pulse

endmodule
