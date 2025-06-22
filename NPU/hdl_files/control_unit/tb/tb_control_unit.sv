/*
Test bench for Control Unit module
Date: 21/06/25
NY Approved
*/
/*
add wave *

add wave -radix signed /tb_control_unit/memA
add wave -radix signed /tb_control_unit/memB
add wave -radix signed /tb_control_unit/memC
add wave -radix signed /tb_control_unit/a_mat
add wave -radix signed /tb_control_unit/b_mat
add wave -radix signed /tb_control_unit/c_mat
add wave -radix signed /tb_control_unit/pe_mult_count
add wave -radix signed /tb_control_unit/pe_sum_count
add wave -radix signed /tb_control_unit/pe_accum_count
*/
import pkg_systolic::*;

module tb_control_unit;

    timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int P        = 32;   // cantidad de bits para perf. counters
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    //––– Señales de control de flujo –––
    logic use_relu_fw;      // habilita el uso del relu                 // [y] from CU to SNC (MtxPref) [y]

    //––– Señales de control externas (lectura) –––
    logic matrices_loaded_fw;  // MRAM ya cargó matrices A/B		    // [y] from CU to SNC (MtxPref) [y]
	logic prefetch_start;   // pulso para arrancar el prefetch	        // [y] from CU to SNC (MtxPref) [y]
	logic commit_start;     // pulso para arrancar el commit	        // [y] from CU to SNC (MtxComt) [y]
    logic npu_busy;         // NPU esta en media ejecucion			    // [y] from SNC (NPU) to CU [y]
    logic npu_done;         // NPU calculo matriz resultante 			// [y] from SNC (NPU) to CU [y]
	logic result_stored;    // commit terminado					        // [y] from SNC (MtxComt) to CU [y]

    //––– Arithmetic Op. Performance Counters (via NPU) –––
    // Performance counters por PE
    logic [P-1:0] pe_mult_count [0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    logic [P-1:0] pe_sum_count  [0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    logic [P-1:0] pe_accum_count[0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    // Performance counters totales agregados
    logic [P-1:0] total_mult_count;                                     // [y] from SNC to PM [y]
    logic [P-1:0] total_sum_count;                                      // [y] from SNC to PM [y]
    logic [P-1:0] total_accum_count;                                    // [y] from SNC to PM [y]

    //--- Señales internas para la MRAM (puerto A/B de 16 bits y C de 32 bits) ---
    // Puertos de 16 bits
    logic we16;             // habilita escritura de A o B              // [n] from UJI to MRAM [y] /*!*/
    logic re16;             // habilita lectura de A o B                // [y] from SNC (MtxPref) to MRAM [y]
    logic mat_sel;          // 0→A, 1→B                                 // [y] from SNC (MtxPref) to MRAM [y]
    logic [$clog2(K*K)-1:0] addr16; //  dirección 0…K*K–1 para A/B      // [y] from SNC (MtxPref) to MRAM [y]
    s16_t din16;            // dato de 16 bits a escribir en A/B        // [n] from UJI to MRAM [y] /*!*/
    s16_t dout16;           // dato leído de A/B                        // [y] from MRAM to SNC (MtxPref) [y]
    logic ready16;          // pulso 1-clk cuando termina we16 o re16   // [y] from MRAM to SNC (MtxPref) [y]
    logic stall16;          // 1 mientras ready16=0 (back-pressure)     // [y] from MRAM to SNC (MtxPref) [y]
    // Puertos de 32 bits
    logic we32;             // habilita escritura de C                  // [y] from SNC (MtxComt) to MRAM [y]
    logic re32;             // habilita lectura de C                    // [n] from UJI to MRAM [y] /*!*/
    logic [$clog2(K*K)-1:0] addr32; // dirección 0…K*K–1 para C         // [y] from SNC (MtxComt) to MRAM [y]
    s32_t din32;            // dato de 32 bits a escribir en C          // [y] from SNC (MtxComt) to MRAM [y]
    s32_t dout32;           // dato leído de C                          // [y] from MRAM to UJI [n] /*!*/
    logic ready32;          // pulso 1-clk cuando termina we32 o re32   // [y] from MRAM to SNC (MtxComt) [y]
    logic stall32;          // 1 mientras ready32=0                     // [y] from MRAM to SNC (MtxComt) [y]

    //------------------------------------------------------------------------------
    // Instancia del Systolic Neural Core
    //------------------------------------------------------------------------------
    systolic_neural_core #(
        .K(K),
        .P(P)
    ) SNC (
        .clk                (clk),
        .rst                (rst),

        // Control de flujo
        .use_relu           (use_relu_fw),

        // Control externo (lectura)
        .matrices_loaded    (matrices_loaded_fw),
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

        // Arithmetic Op. Performance counters
        .pe_mult_count      (pe_mult_count),
        .pe_sum_count       (pe_sum_count),
        .pe_accum_count     (pe_accum_count),
        .total_mult_count   (total_mult_count),
        .total_sum_count    (total_sum_count),
        .total_accum_count  (total_accum_count)
    );

    // Memory Access Performance counters
    logic [P-1:0] read16_count;           // lecturas 16-bit completadas        // [y] from MRAM to PM [y]
    logic [P-1:0] write16_count;          // escrituras 16-bit completadas      // [y] from MRAM to PM [y]
    logic [P-1:0] read32_count;           // lecturas 32-bit completadas        // [y] from MRAM to PM [y]
    logic [P-1:0] write32_count;          // escrituras 32-bit completadas      // [y] from MRAM to PM [y]
    logic [P-1:0] bits_read_16_count;     // bits leídos (16 por lectura)       // [y] from MRAM to PM [y]
    logic [P-1:0] bits_written_16_count;  // bits escritos (16 por escritura)   // [y] from MRAM to PM [y]
    logic [P-1:0] bits_read_32_count;     // bits leídos (32 por lectura)       // [y] from MRAM to PM [y]
    logic [P-1:0] bits_written_32_count;  // bits escritos (32 por escritura)   // [y] from MRAM to PM [y]

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena A, B (16 bits) y C (32 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K(K),
        .P(P)
    ) mram (
        .clk                    (clk),
        .rst                    (rst),
        // Puerto A/B de 16 bits
        .we16                   (we16),        // 1→din16→mem[mat_sel?B:A][addr16]
        .re16                   (re16),        // 1→mem[mat_sel?B:A][addr16]→dout16
        .mat_sel                (mat_sel),     // 0=A, 1=B
        .addr16                 (addr16),      // índice fila-major 0…K*K–1
        .din16                  (din16),       // dato de entrada

        .dout16                 (dout16),      // dato de salida
        .ready16                (ready16),     // 1-clk cuando la operación acaba
        .stall16                (stall16),     // 1 mientras la memoria no esté lista
        // Puerto C de 32 bits
        .we32                   (we32),        // 1→din32→memC[addr32]
        .re32                   (re32),        // 1→memC[addr32]→dout32
        .addr32                 (addr32),      // índice fila-major 0…K*K–1
        .din32                  (din32),       // dato de entrada

        .dout32                 (dout32),      // dato de salida
        .ready32                (ready32),     // 1-clk cuando la operación acaba
        .stall32                (stall32),     // 1 mientras la memoria no esté lista
        // Memory Access Performance counters
        .read16_count           (read16_count),
        .write16_count          (write16_count),
        .read32_count           (read32_count),
        .write32_count          (write32_count),
        .bits_read_16_count     (bits_read_16_count),
        .bits_written_16_count  (bits_written_16_count),
        .bits_read_32_count     (bits_read_32_count),
        .bits_written_32_count  (bits_written_32_count)
    );

    // Performance counter snapshots
    logic [P-1:0] snap_read16_count;
    logic [P-1:0] snap_write16_count;
    logic [P-1:0] snap_read32_count;
    logic [P-1:0] snap_write32_count;
    logic [P-1:0] snap_bits_read_16_count;
    logic [P-1:0] snap_bits_written_16_count;
    logic [P-1:0] snap_bits_read_32_count;
    logic [P-1:0] snap_bits_written_32_count;

    logic [P-1:0] snap_pe_mult_count  [0:K-1][0:K-1];
    logic [P-1:0] snap_pe_sum_count   [0:K-1][0:K-1];
    logic [P-1:0] snap_pe_accum_count [0:K-1][0:K-1];
    logic [P-1:0] snap_total_mult_count;
    logic [P-1:0] snap_total_sum_count;
    logic [P-1:0] snap_total_accum_count;

    logic         result_stored_fw;         // Commit done                      // [y] from CU to PM [y]
    logic         counters_ready;           // Perf counters are ready          // [y] from PM to CU [y]

    //--------------------------------------------------------------------------
    // Instancia de perf_monitor: congela y expone los counters
    //--------------------------------------------------------------------------
    performance_monitor #(
        .K(K),
        .P(P)
    ) perf_monitor (
        .clk                        (clk),
        .rst                        (rst),
        .commit_done                (result_stored_fw),

        // Contadores MRAM
        .read16_count               (read16_count),
        .write16_count              (write16_count),
        .read32_count               (read32_count),
        .write32_count              (write32_count),
        .bits_read_16_count         (bits_read_16_count),
        .bits_written_16_count      (bits_written_16_count),
        .bits_read_32_count         (bits_read_32_count),
        .bits_written_32_count      (bits_written_32_count),

        // Contadores NPU agregados
        .total_mult_count           (total_mult_count),
        .total_sum_count            (total_sum_count),
        .total_accum_count          (total_accum_count),

        // Contadores individuales de PEs
        .pe_mult_count              (pe_mult_count),
        .pe_sum_count               (pe_sum_count),
        .pe_accum_count             (pe_accum_count),

        // Salidas snapshot
        .snap_read16_count          (snap_read16_count),
        .snap_write16_count         (snap_write16_count),
        .snap_read32_count          (snap_read32_count),
        .snap_write32_count         (snap_write32_count),
        .snap_bits_read_16_count    (snap_bits_read_16_count),
        .snap_bits_written_16_count (snap_bits_written_16_count),
        .snap_bits_read_32_count    (snap_bits_read_32_count),
        .snap_bits_written_32_count (snap_bits_written_32_count),

        .snap_total_mult_count      (snap_total_mult_count),
        .snap_total_sum_count       (snap_total_sum_count),
        .snap_total_accum_count     (snap_total_accum_count),
        .snap_pe_mult_count         (snap_pe_mult_count),
        .snap_pe_sum_count          (snap_pe_sum_count),
        .snap_pe_accum_count        (snap_pe_accum_count),

        .counters_ready             (counters_ready)
    );

    // Control Unit signals
    logic start_exec;           // Start command from host          // [n] from UJI to CU [y]
    logic stop_exec;            // Clear done & go to IDLE          // [n] from UJI to CU [y]
    logic use_relu;             // habilita el uso del relu         // [n] from UJI to CU [y]
    logic matrices_loaded;      // MRAM ya cargó matrices A/B	    // [n] from UJI to CU [y]
    logic exec_active;          // High during execution            // [y] from CU to UJI [n]
    logic exec_done;            // High when cycle completes        // [y] from CU to UJI [n]
    
    //--------------------------------------------------------------------------
    // Instancia de control_unit
    //--------------------------------------------------------------------------
    control_unit #(
        .P(P)
    ) uut (
        .clk                  (clk),
        .rst                  (rst),
        // External interface
        .start_exec           (start_exec),
        .stop_exec            (stop_exec),
        // Data readiness
        .matrices_loaded      (matrices_loaded),
        // Compute stage
        .npu_busy             (npu_busy),
        .npu_done             (npu_done),
        // Commit stage
        .result_stored        (result_stored),
        // Performance monitor
        .counters_ready       (counters_ready),
        // Flow control/config
        .use_relu             (use_relu),

        // Forwarding Data readiness
        .matrices_loaded_fw   (matrices_loaded_fw),
        // Prefetch stage output
        .prefetch_start       (prefetch_start),
        // Compute stage Status for user
        .exec_active          (exec_active),
        .exec_done            (exec_done),
        // Commit stage output
        .commit_start         (commit_start),
        // Forwarding Commit stage
        .result_stored_fw     (result_stored_fw),
        // Forwarding Flow Control
        .use_relu_fw          (use_relu_fw)
    );

    // inner wiring MRAM
    s16_t memA [0:K*K-1];
    s16_t memB [0:K*K-1];
    s32_t memC [0:K*K-1];
    // inner wiring SNC
    logic [1:0] prefetch_state;
    s16_t a_mat [0:K-1][0:K-1]; // matriz A
    s16_t b_mat [0:K-1][0:K-1]; // matriz B
    logic [1:0] commit_state;
    s32_t c_mat [0:K-1][0:K-1]; // matriz C resultante
    // inner wiring CU
    logic [2:0] state;
    logic [2:0] next_state;

    // Initialize inputs
    initial begin
		$display("\nControl Unit module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        start_exec = 1'b0;
        stop_exec = 1'b0;
        use_relu = 1'b0;
        matrices_loaded = 1'b0;

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

        prefetch_state = SNC.prefetcher.state;
        commit_state = SNC.committer.state;

        a_mat = SNC.a_mat;
        b_mat = SNC.b_mat;
        c_mat = SNC.c_mat;

        state = uut.state;
        next_state = uut.next_state;
    end

    // Variables de referencia

    initial	begin

        repeat (1) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        use_relu = 1'b0;

        @(posedge clk);

        start_exec = 1'b1;

        @(posedge clk);

        matrices_loaded = 1'b1;
        start_exec = 1'b0;

        @(posedge clk);


        // --- espera a que el NPU active el busy ---
        wait(npu_busy);

        $display("[%0t] a_mat = %0p \nb_mat = %0p",
                 $time, a_mat, b_mat);

        matrices_loaded = 1'b0;
	

        // --- espera a que el NPU active el ready ---
        wait(npu_done);

        $display("[%0t] c_mat = %0p",
                 $time, c_mat); 


        // --- espera a que se termine de escribir en MRAM ---
        wait(exec_done);

        $display("[%0t] memC = %0p",
                 $time, memC); 
        

        @(posedge clk);

        stop_exec = 1'b1;

		// Done

    end

    initial
	#18000 $finish;    

endmodule
