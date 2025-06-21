/*
Test bench for Systolic Neural Core module
Date: 18/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_systolic_neural_core/memA
add wave -radix signed /tb_systolic_neural_core/memB
add wave -radix signed /tb_systolic_neural_core/memC
add wave -radix signed /tb_systolic_neural_core/a_mat
add wave -radix signed /tb_systolic_neural_core/b_mat
add wave -radix signed /tb_systolic_neural_core/c_mat
add wave -radix signed /tb_systolic_neural_core/pe_mult_count
add wave -radix signed /tb_systolic_neural_core/pe_sum_count
add wave -radix signed /tb_systolic_neural_core/pe_accum_count
*/
import pkg_systolic::*;

module tb_systolic_neural_core;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int P        = 32;   // cantidad de bits para perf. counters
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;
	
    //––– Señales de control externas (lectura) –––
    /* Esta vendrá del matrix_load_unit luego de revisar que se han cargado las matrices */
	logic matrices_loaded;  // MRAM ya cargó matrices A/B		        // [n] from CU(?) to SNC (MtxPref) [y]
	/* Este vendrá de un control unit luego de revisar que la memoria pueda ser leida */
	logic prefetch_start;   // pulso para arrancar el prefetch	        // [n] from CU(?) to SNC (MtxPref) [y]
    /* Este vendrá de un control unit luego de revisar que la memoria pueda ser escrita */
	logic commit_start;     // pulso para arrancar el commit	        // [n] from CU(?) to SNC (MtxComt) [y]
    /* */
    logic npu_busy;         // NPU esta en media ejecucion			    // [y] from SNC (NPU) to CU(?) [n]
	/* */
    logic npu_done;         // NPU calculo matriz resultante 			// [y] from SNC (NPU) to CU(?) [n]
	/* Esta irá al matrix_store_unit para avisar que se ha escrito en MRAM y es posible leer la matriz */
	logic result_stored;    // commit terminado					        // [y] from SNC (MtxComt) to CU(?) [n]

    //––– Performance Counters (via NPU) –––
    // Performance counters por PE
    logic [P-1:0] pe_mult_count [0:K-1][0:K-1];
    logic [P-1:0] pe_sum_count  [0:K-1][0:K-1];
    logic [P-1:0] pe_accum_count[0:K-1][0:K-1];
    // Performance counters totales agregados
    logic [P-1:0] total_mult_count;
    logic [P-1:0] total_sum_count;
    logic [P-1:0] total_accum_count;

    //--------------------------------------------------------------------------
    // Señales internas para la MRAM (puerto A/B de 16 bits y C de 32 bits)
    //--------------------------------------------------------------------------
    // Puertos de 16 bits
    // logic we16;             // habilita escritura de A o B              // [n] from (?) to MRAM [y] /*!*/
    logic re16;             // habilita lectura de A o B                // [y] from SNC (MtxPref) to MRAM [y]
    logic mat_sel;          // 0→A, 1→B                                 // [y] from SNC (MtxPref) to MRAM [y]
    logic [$clog2(K*K)-1:0] addr16; //  dirección 0…K*K–1 para A/B      // [y] from SNC (MtxPref) to MRAM [y]
    // s16_t din16;            // dato de 16 bits a escribir en A/B        // [n] from (?) to MRAM [y] /*!*/
    s16_t dout16;           // dato leído de A/B                        // [y] from MRAM to SNC (MtxPref) [y]
    logic ready16;          // pulso 1-clk cuando termina we16 o re16   // [y] from MRAM to SNC (MtxPref) [y]
    logic stall16;          // 1 mientras ready16=0 (back-pressure)     // [y] from MRAM to SNC (MtxPref) [y]
    // Puertos de 32 bits
    logic we32;             // habilita escritura de C                  // [y] from SNC (MtxComt) to MRAM [y]
    // logic re32;             // habilita lectura de C                    // [n] from (?) to MRAM [y] /*!*/
    logic [$clog2(K*K)-1:0] addr32; // dirección 0…K*K–1 para C         // [y] from SNC (MtxComt) to MRAM [y]
    s32_t din32;            // dato de 32 bits a escribir en C          // [y] from SNC (MtxComt) to MRAM [y]
    // s32_t dout32;           // dato leído de C                          // [y] from MRAM to (?) [n] /*!*/
    logic ready32;          // pulso 1-clk cuando termina we32 o re32   // [y] from MRAM to SNC (MtxComt) [y]
    logic stall32;          // 1 mientras ready32=0                     // [y] from MRAM to SNC (MtxComt) [y]

    //------------------------------------------------------------------------------
    // Instancia del Systolic Neural Core
    //------------------------------------------------------------------------------
    systolic_neural_core #(
        .K(K),
        .P(P)
    ) uut (
        .clk                (clk),
        .rst                (rst),

        // Control externo (lectura)
        .matrices_loaded    (matrices_loaded),
        .prefetch_start     (prefetch_start),

        // MRAM 16-bit interface
        .dout16             (dout16),
        .ready16            (ready16),
        .stall16            (stall16),

        .re16               (re16),
        .mat_sel            (mat_sel),
        .addr16             (addr16),

        // Control externo (escritura)
        .commit_start       (commit_start),

        // MRAM 32-bit interface
        .ready32            (ready32),
        .stall32            (stall32),

        .we32               (we32),
        .addr32             (addr32),
        .din32              (din32),

        // Status
        .npu_busy           (npu_busy),
        .npu_done           (npu_done),
        .result_stored      (result_stored),

        // Performance counters
        .pe_mult_count      (pe_mult_count),
        .pe_sum_count       (pe_sum_count),
        .pe_accum_count     (pe_accum_count),
        .total_mult_count   (total_mult_count),
        .total_sum_count    (total_sum_count),
        .total_accum_count  (total_accum_count)
    );

    // Performance counters
    logic [P-1:0] read16_count;           // lecturas 16-bit completadas
    logic [P-1:0] write16_count;          // escrituras 16-bit completadas
    logic [P-1:0] read32_count;           // lecturas 32-bit completadas
    logic [P-1:0] write32_count;          // escrituras 32-bit completadas
    logic [P-1:0] bits_read_16_count;     // bits leídos (16 por lectura)
    logic [P-1:0] bits_written_16_count;  // bits escritos (16 por escritura)
    logic [P-1:0] bits_read_32_count;     // bits leídos (32 por lectura)
    logic [P-1:0] bits_written_32_count;  // bits escritos (32 por escritura)

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena A, B (16 bits) y C (32 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K(K),
        .P(P)
    ) mram (
        .clk     (clk),
        .rst     (rst),
        // Puerto A/B de 16 bits
        // .we16    (we16),        // 1→din16→mem[mat_sel?B:A][addr16]
        .re16    (re16),        // 1→mem[mat_sel?B:A][addr16]→dout16
        .mat_sel (mat_sel),     // 0=A, 1=B
        .addr16  (addr16),      // índice fila-major 0…K*K–1
        // .din16   (din16),       // dato de entrada

        .dout16  (dout16),      // dato de salida
        .ready16 (ready16),     // 1-clk cuando la operación acaba
        .stall16 (stall16),     // 1 mientras la memoria no esté lista
        // Puerto C de 32 bits
        .we32    (we32),        // 1→din32→memC[addr32]
        // .re32    (re32),        // 1→memC[addr32]→dout32
        .addr32  (addr32),      // índice fila-major 0…K*K–1
        .din32   (din32),       // dato de entrada

        // .dout32  (dout32),      // dato de salida
        .ready32 (ready32),     // 1-clk cuando la operación acaba
        .stall32 (stall32),      // 1 mientras la memoria no esté lista
        // Performance Counters
        .read16_count           (read16_count),
        .write16_count          (write16_count),
        .read32_count           (read32_count),
        .write32_count          (write32_count),
        .bits_read_16_count     (bits_read_16_count),
        .bits_written_16_count  (bits_written_16_count),
        .bits_read_32_count     (bits_read_32_count),
        .bits_written_32_count  (bits_written_32_count)
    );

    // inner wiring MRAM
    s16_t memA [0:K*K-1];
    s16_t memB [0:K*K-1];
    s32_t memC [0:K*K-1];
    // inner wiring uut
    logic [1:0] prefetch_state;
    s16_t a_mat [0:K-1][0:K-1]; // matriz A
    s16_t b_mat [0:K-1][0:K-1]; // matriz B
    logic [1:0] commit_state;
    s32_t c_mat [0:K-1][0:K-1]; // matriz C resultante

    // Initialize inputs
    initial begin
		$display("\Systolic Neural Core module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        matrices_loaded = 1'b0;
        prefetch_start = 1'b0;
        commit_start = 1'b0;

        mram.memA = '{
            2,  -1,  0,  6,
            -7,  5,  6,  -4,
            8,  1,  -2,  3,
            0,  7,  -9,  1
        };
        mram.memB = '{
            5,  0,  2,  -3,
            -4,  6,  7,  1,
            8,  -9,  0,  9,
            1,  3,  -5,  2
        };
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        memA = mram.memA;
        memB = mram.memB;
        memC = mram.memC;

        prefetch_state = uut.prefetcher.state;
        commit_state = uut.committer.state;

        a_mat = uut.a_mat;
        b_mat = uut.b_mat;
        c_mat = uut.c_mat;
    end

    // Variables de referencia

    initial	begin

        repeat (1) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        matrices_loaded = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b0;


        // --- espera a que el NPU active el busy ---
        wait(npu_busy);

        $display("[%0t] a_mat = %0p \nb_mat = %0p",
                 $time, a_mat, b_mat); 
	 
        // $display("[%0t] a_mat=%0d b_mat=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
        //          $time, a_mat, b_mat, valid_in, a_out, b_out, valid_out, c_out, c_valid); 

        // --- espera a que el NPU active el ready ---
        wait(npu_done);

        $display("[%0t] c_mat = %0p",
                 $time, c_mat); 


        @(posedge clk);

        commit_start = 1'b1;

        @(posedge clk);

        commit_start = 1'b0;


        // --- espera a que se termine de escribir en MRAM ---
        wait(result_stored);

        $display("[%0t] memC = %0p",
                 $time, memC); 
        

		// Done

    end

    initial
	#17000 $finish;    

endmodule
