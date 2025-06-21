//------------------------------------------------------------------------------
// systolic_array.sv
//   • K × K malla de Processing-Elements (PE) con dataflow “Output-Stationary”.
//   • Cada PE multiplica K valores de 16-bits (+1 ciclo de registro) y 
//     acumula los productos (profundidad K), aplicando ReLU al final.
//   • Performance counters:
//       – pe_mult_count [P-bits]   : número de multiplicaciones por PE.
//       – pe_sum_count  [P-bits]   : número de sumas en cada acumulador.
//       – pe_accum_count[P-bits]   : número de bloques resultantes emitidos.
//       – total_*                  : agregados de todos los PEs.
//   • Entradas externas:
//       – clk, rst               : reloj y reset global.
//       – a_col0[0‥K-1]          : palabra de 16 bits que inicia cada columna de A.
//       – b_row0[0‥K-1]          : palabra de 16 bits que inicia cada fila de B.
//       – valid_in[0‥K-1]        : pulso de validez que se mantiene K ciclos para 
//                                 arrancar cada banda vertical.
//       – use_relu               : habilita aplicación de ReLU (1) o bypass (0).
//   • Salidas:
//       – c_mat[0‥K-1][0‥K-1]    : matriz de resultados 32 bits.
//       – c_valid                : pulso por banda indicando que c_mat es válido.
//       – pe_*_count             : contadores individuales por PE.
//       – total_*_count          : contadores agregados.
//   Parametrización:
//       parameter K : dimensión de la malla (PEs = K×K) y profundidad de MAC.
//       parameter P : anchura en bits de los performance counters.
//------------------------------------------------------------------------------


`timescale 1ns/1ps
import pkg_systolic::*;

module systolic_array #(
    parameter int K = 4,            // tamaño de la malla (PEs = M×M)
    parameter int P = 32            // cantidad de bits para perf. counters
)(
    input  logic         clk,
    input  logic         rst,

    // Bordes de entrada (1 palabra por ciclo)
    input  s16_t         a_col0 [0:K-1],                // columna de A
    input  s16_t         b_row0 [0:K-1],                // fila de B
    /* valid_in se pone a 1 exactamente K ciclos por cada banda vertical se quiera procesar. */
    input  logic         valid_in [0:K-1],              // habilita stream
    input  logic         use_relu,                      // habilita el uso del relu

    // Resultados
    output s32_t         c_mat [0:K-1][0:K-1],          // matriz C
    output logic         c_valid,                       // pulso banda

    // Performance counters por PE
    output logic [P-1:0] pe_mult_count [0:K-1][0:K-1],
    output logic [P-1:0] pe_sum_count  [0:K-1][0:K-1],
    output logic [P-1:0] pe_accum_count[0:K-1][0:K-1],

    // Performance counters totales agregados
    output logic [P-1:0] total_mult_count,
    output logic [P-1:0] total_sum_count,
    output logic [P-1:0] total_accum_count
);

    // Wires temporales para capturar counters de cada PE
    logic [31:0] mult_w [0:K-1][0:K-1];
    logic [31:0] sum_w  [0:K-1][0:K-1];
    logic [31:0] acc_w  [0:K-1][0:K-1];

    //--------------------------------------------------------------------------
    // 1. Señales internas: buses “shift” para A, B y validez
    //--------------------------------------------------------------------------
    s16_t a_bus [0:K-1][0:K];      // [fila][columna+1]  – extra col. para salida
    s16_t b_bus [0:K][0:K-1];      // [fila+1][columna]  – extra fila para salida
    logic v_bus [0:K-1][0:K];      // validez viaja junto a los datos

    //--------------------------------------------------------------------------
    // 2. Inyección de la primera columna / fila (ciclo 0 … K-1)
    //--------------------------------------------------------------------------
    genvar i, j;

    generate
        // -------- Inyección de la primera columna de A y la validez ----------
        for (i = 0; i < K; i = i + 1) begin : INJ_A
            assign a_bus[i][0] = a_col0[i];             // driver externo
            assign v_bus[i][0] = valid_in[i];           // mismo pulso para la fila
        end

        // -------- Inyección de la primera fila de B --------------------------
        for (j = 0; j < K; j = j + 1) begin : INJ_B     // driver externo
            assign b_bus[0][j] = b_row0[j];
        end
    endgenerate

    //--------------------------------------------------------------------------
    // 3. Matriz de PEs  (parámetro K propagado a cada instancia)
    //    • Cada PE lee a_bus[i][j]  &  b_bus[i][j]
    //    • Escribe a_bus[i][j+1]    &  b_bus[i+1][j]   -> efecto “shift”
    //--------------------------------------------------------------------------
    // 1. Un vector packed de K bits (uno por fila):
    logic [0:K-1] c_valid_band;      // bit i = pulso del PE (i, K-1)

    // 2. Sólo la última columna conecta ese bit; las demás NO lo tocan
    generate
        for (i = 0; i < K; i = i + 1) begin : ROW
            for (j = 0; j < K; j = j + 1) begin : COL
                if (j == K-1) begin : LAST
                    pe #(.K(K)) u_pe (
                        .clk       (clk),
                        .rst       (rst),
                        .a_in      (a_bus[i][j]),
                        .b_in      (b_bus[i][j]),
                        .valid_in  (v_bus[i][j]),
                        .use_relu  (use_relu),
                        .a_out     (a_bus[i][j+1]),
                        .b_out     (b_bus[i+1][j]),
                        .valid_out (v_bus[i][j+1]),
                        .c_out     (c_mat[i][j]),
                        .c_valid   (c_valid_band[i]),   // único driver por fila
                        // Performance counters
                        .perf_mult_count (mult_w[i][j]),
                        .perf_sum_count  (sum_w[i][j]),
                        .perf_accum_count(acc_w[i][j])
                    );
                end
                else begin : MID
                    pe #(.K(K)) u_pe (
                        .clk       (clk),
                        .rst       (rst),
                        .a_in      (a_bus[i][j]),
                        .b_in      (b_bus[i][j]),
                        .valid_in  (v_bus[i][j]),
                        .use_relu  (use_relu),
                        .a_out     (a_bus[i][j+1]),
                        .b_out     (b_bus[i+1][j]),
                        .valid_out (v_bus[i][j+1]),
                        .c_out     (c_mat[i][j]),
                        .c_valid   (),                 // sin conexión
                        // Performance counters
                        .perf_mult_count (mult_w[i][j]),
                        .perf_sum_count  (sum_w[i][j]),
                        .perf_accum_count(acc_w[i][j])
                    );
                end

                // Exponer en la interfaz
                assign pe_mult_count[i][j]   = mult_w[i][j];
                assign pe_sum_count[i][j]    = sum_w[i][j];
                assign pe_accum_count[i][j]  = acc_w[i][j];
            end
        end
    endgenerate


    logic [0:K-1] valid_vec;

    always_comb begin
        for (int i = 0; i < K; i++) begin
            valid_vec[i] = valid_in[i];
        end
    end

    // 3. El pulso de banda lista es el AND de esos K bits
    assign c_valid = &c_valid_band & ~|valid_vec;   // reducción AND packed → 1-clk pulse


    // Agregarización de counters de todos los PEs
    integer ii, jj;
    always_comb begin
        total_mult_count  = 0;
        total_sum_count   = 0;
        total_accum_count = 0;
        for (ii = 0; ii < K; ii++) begin
            for (jj = 0; jj < K; jj++) begin
                total_mult_count  += mult_w[ii][jj];
                total_sum_count   += sum_w[ii][jj];
                total_accum_count += acc_w[ii][jj];
            end
        end
    end

endmodule
