//------------------------------------------------------------------------------
// systolic_neural_core.sv
//------------------------------------------------------------------------------
// Encapsula matrix_prefetcher, NPU y matrix_committer
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module systolic_neural_core #(
  parameter int M = 4,
  parameter int K = 4
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
	output logic             result_stored     // commit terminado					(from MtxComt [y])
);

    s16_t a_mat [0:K-1][0:K-1]; // matriz A                         // [y] from MtxPref to NPU [y]
    s16_t b_mat [0:K-1][0:K-1]; // matriz B                         // [y] from MtxPref to NPU [y]
    logic npu_start;            // pulso 1-ciclo: matrices cargadas // [y] from MtxPref to NPU [y]

    //----------------------------------------------------------------------
    // Instancia Matrix Prefetcher
    //----------------------------------------------------------------------
    matrix_prefetcher #(
        .K(K)
    ) prefetch (
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
        .M(K),
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
        .c_mat (c_mat)
    );

	assign npu_done = result_done;
    
    //----------------------------------------------------------------------
    // Instancia Matrix Commiter
    //----------------------------------------------------------------------
    matrix_committer #(
        .K(K)
    ) commiter (
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
        .ready_to_ram (result_stored)    // Tiene que ir al modulo que leerá la matriz resultante del MRAM
    );

endmodule
