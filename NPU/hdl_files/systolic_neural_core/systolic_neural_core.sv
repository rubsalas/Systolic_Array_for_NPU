//------------------------------------------------------------------------------
// systolic_neural_core.sv  –  Wrapper para flujo completo de cómputo
//
//   • Integra tres bloques:
//       1. matrix_prefetcher   → lectura de matrices A/B desde MRAM (16-bit).
//       2. NPU                 → malla sistólica de PEs con performance counters.
//       3. matrix_committer    → escritura de matriz C en MRAM (32-bit).
//   • Orquesta handshakes con la MRAM (re16/ready16/stall16, we32/ready32/stall32).
//   • Señales de control externas:
//       - matrices_loaded : indica que A y B están en MRAM.
//       - prefetch_start  : pulso 1-clk para arrancar la lectura de A/B.
//       - commit_start    : pulso 1-clk para arrancar la escritura de C.
//   • Exposición de estado interno:
//       - npu_busy        : ‘1’ mientras el NPU está computando.
//       - npu_done        : pulso 1-clk al finalizar la computación.
//       - result_stored   : pulso 1-clk al completar la escritura de C.
//   • Performance counters desde la NPU (malla sistólica):
//       - pe_mult_count  [0:K-1][0:K-1] : multiplicaciones por PE.
//       - pe_sum_count   [0:K-1][0:K-1] : sumas por PE.
//       - pe_accum_count [0:K-1][0:K-1] : resultados finales por PE.
//       - total_mult_count, total_sum_count, total_accum_count : agregados.
//   • Parámetros:
//       - K : tamaño de la malla (PEs = K×K) y profundidad de la MAC.
//       - P : ancho en bits de los performance counters.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module systolic_neural_core #(
    parameter int K = 4,            // tamaño de la malla (PEs = M×M)
    parameter int P = 32            // cantidad de bits para perf. counters
)(
	input  logic             clk,
	input  logic             rst,

	//––– Señales de control externas (lectura) –––
	/* Esta vendrá del matrix_load_unit luego de revisar que se han cargado las matrices */
	input  logic             matrices_loaded,  // MRAM ya cargó matrices A/B		(to MtxPref [y])
	/* Este vendrá de un control unit luego de revisar que la memoria pueda ser leida */
	input  logic             prefetch_start,   // pulso para arrancar el prefetch	(to MtxPref [y])

	//––– Puerto MRAM de 16 bits (lectura) –––
	input  s16_t             dout16,           // dato leído de MRAM				(to MtxPref [y])
	input  logic             ready16,          // MRAM dice “dato listo”			(to MtxPref [y])
	input  logic             stall16,          // back-pressure						(to MtxPref [y])

	output logic             re16,             // solicita lectura					(from MtxPref [y])
	output logic             mat_sel,          // 0=A, 1=B							(from MtxPref [y])
	output logic [$clog2(K*K)-1:0] addr16,     // dirección fila-major				(from MtxPref [y])

	//––– Señales de control externas (escritura) –––
	/* Este vendrá de un control unit luego de revisar que la memoria pueda ser escrita */
	input  logic             commit_start,     // pulso para arrancar el commit		(to MtxComt [y])

	//––– Puerto MRAM de 32 bits (escritura) –––
	input  logic             ready32,          // MRAM listo para recibir			(to MtxComt [y])
	input  logic             stall32,          // back-pressure						(to MtxComt [y])

	output logic             we32,             // escribe C en MRAM					(from MtxComt [y])
	output logic [$clog2(K*K)-1:0] addr32,     // dirección fila-major				(from MtxComt [y])
	output s32_t             din32,            // dato a escribir					(from MtxComt [y])

	//––– Salidas de estatus –––
	output logic             npu_busy,         // busy desde NPU					(from NPU [y])
	output logic             npu_done,         // done desde NPU					(from NPU [y])
	/* Esta irá al matrix_store_unit para avisar que se ha escrito en MRAM y es posible leer la matriz */
	output logic             result_stored,    // commit terminado					(from MtxComt [y])

    //––– Performance counters del Systolic Array (vía NPU) –––
    output logic [P-1:0]     pe_mult_count  [0:K-1][0:K-1],
    output logic [P-1:0]     pe_sum_count   [0:K-1][0:K-1],
    output logic [P-1:0]     pe_accum_count [0:K-1][0:K-1],
    output logic [P-1:0]     total_mult_count,
    output logic [P-1:0]     total_sum_count,
    output logic [P-1:0]     total_accum_count
);

    s16_t a_mat [0:K-1][0:K-1]; // matriz A                         // [y] from MtxPref to NPU [y]
    s16_t b_mat [0:K-1][0:K-1]; // matriz B                         // [y] from MtxPref to NPU [y]
    logic npu_start;            // pulso 1-ciclo: matrices cargadas // [y] from MtxPref to NPU [y]

    //----------------------------------------------------------------------
    // Instancia Matrix Prefetcher
    //----------------------------------------------------------------------
    matrix_prefetcher #(
        .K(K)
	) prefetcher (
        .clk            (clk),
        .rst            (rst),
        // Control signals
        .matrices_ready (matrices_loaded),
        .prefetch_start (prefetch_start),
        // Conexión MRAM 16-bit
        .dout16         (dout16),
        .ready16        (ready16),
        .stall16        (stall16),

        .re16           (re16),
        .mat_sel        (mat_sel),
        .addr16         (addr16),
        // Salida a NPU
        .a_mat          (a_mat),
        .b_mat          (b_mat),
        .ready_to_npu   (npu_start)
    );

    s32_t c_mat [0:K-1][0:K-1]; // matriz C resultante // [y] from NPU to MtxComt [y]
	logic result_done;			// NPU ha terminado de calcular la matriz resultante // [y] from NPU to MtxComt [y]

    //----------------------------------------------------------------------
    // Instancia NPU
    //----------------------------------------------------------------------
    NPU #(
        .K(K)
    ) u_npu (
        .clk   (clk),
        .rst   (rst),
        // Prefetcher
        .a_mat (a_mat),
        .b_mat (b_mat),
        .start (npu_start),

        .busy  (npu_busy),
        .done  (result_done),
        .c_mat (c_mat),

        // Forwarding de performance counters
        .pe_mult_count     (pe_mult_count),
        .pe_sum_count      (pe_sum_count),
        .pe_accum_count    (pe_accum_count),
        .total_mult_count  (total_mult_count),
        .total_sum_count   (total_sum_count),
        .total_accum_count (total_accum_count)
    );

	assign npu_done = result_done;
    
    //----------------------------------------------------------------------
    // Instancia Matrix Commiter
    //----------------------------------------------------------------------
    matrix_committer #(
        .K(K)
	) committer (
        .clk          (clk),
        .rst          (rst),
        // Control signals
        .commit_start (commit_start),
        // Entradas desde NPU
        .data_ready   (result_done),
        .c_mat        (c_mat),
        // Conexión MRAM 32-bit
        .ready32      (ready32),
        .stall32      (stall32),

        .we32         (we32),
        .addr32       (addr32),
        .din32        (din32),
        // Salida de control
        .ready_to_ram (result_stored)   // Tiene que ir al modulo que leerá la matriz resultante del MRAM
    );

endmodule
