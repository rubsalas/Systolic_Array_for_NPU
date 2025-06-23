//------------------------------------------------------------------------------
// system_top.sv  –  Top-level integration of MRAM, Systolic Neural Core and Perf Monitor
//
//   • Integra los siguientes bloques:
//       1. MRAM                  – Memoria dual-port para A/B (16-bit) y C (32-bit).
//       2. systolic_neural_core  – Prefetch → NPU → Commit con performance counters.
//       3. perf_monitor          – Congela y expone los contadores tras commit.
//       4. JTAG Interface        – Interfaz externa para acceder a registros.
//
//   • Flujo de control externamente gobernado por:
//       – matrices_loaded : flag que indica A/B cargadas en MRAM.
//       – prefetch_start  : pulso 1-clk para iniciar lectura de A/B.
//       – commit_start    : pulso 1-clk para iniciar escritura de C.
//       – use_relu        : flag para habilitar el uso del ReLU.
//
//   • Handshake MRAM:
//       – 16-bit port: re16, mat_sel, addr16 → solicitud; ready16, stall16 → respuesta.
//       – 32-bit port: we32, addr32, din32 → solicitud; ready32, stall32 → respuesta.
//
//   • Estado y señales clave:
//       – busy            : ‘1’ mientras el NPU está computando.
//       – done            : pulso 1-clk al completar matriz C.
//       – result_stored   : pulso 1-clk tras escritura de C en MRAM.
//       – perf_ready      : pulso 1-clk al completar el snapshot de contadores.
//
//   • Parámetros:
//       – K : dimensión de las matrices (K×K) y profundidad de MAC.
//       – P : ancho en bits de los contadores de performance.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module system_top #(
    parameter int K = 4,            // dimensión de matriz (K×K)
    parameter int P = 32            // cantidad de bits para perf. counters
)(
    input  logic clk,
    input  logic rst,

    input  logic [3:0] cmd_in,
    input  logic       use_relu_in,
    input  logic       use_stepping_in,
    input  logic       mat_sel_in,
    input  logic       address_in,
    input  s16_t       din16_in,
    input  logic       perf_sel_in,
    // Command strobe
    input  logic       confirm_uji,

    output logic [6:0] sseg_hex1,
	output logic [6:0] sseg_hex0,
    output logic rst_led
);

    //––– Señales de control de flujo –––
    /* Vendria de un User JTAG Interface */
    logic use_relu_fw;      // habilita el uso del relu                 // [y] from CU to SNC (MtxPref) [y]

    //––– Señales de control externas (lectura) –––
    /* Esta vendrá del UJI luego de revisar que se han cargado las matrices */
	/* Esta podria dejar de ser 1 cuando se ingresa una nueva matriz C :todo*/
    logic matrices_loaded_fw;  // MRAM ya cargó matrices A/B		    // [y] from CU to SNC (MtxPref) [y]
	/* Este vendrá de un control unit luego de revisar que la memoria pueda ser leida */
	logic prefetch_start;   // pulso para arrancar el prefetch	        // [y] from CU to SNC (MtxPref) [y]
    /* Este vendrá de un control unit luego de revisar que la memoria pueda ser escrita */
	logic commit_start;     // pulso para arrancar el commit	        // [y] from CU to SNC (MtxComt) [y]
    /* */
    logic npu_busy;         // NPU esta en media ejecucion			    // [y] from SNC (NPU) to CU [y]
	/* */
    logic npu_done;         // NPU calculo matriz resultante 			// [y] from SNC (NPU) to CU [y]
	/* Esta irá al matrix_store_unit para avisar que se ha escrito en MRAM y es posible leer la matriz */
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
    logic start_exec;           // Start command from host          // [y] from UJI to CU [y]
    logic stop_exec;            // Clear done & go to IDLE          // [y] from UJI to CU [y]
    logic use_relu;             // habilita el uso del relu         // [y] from UJI to CU [y]
    logic matrices_loaded;      // MRAM ya cargó matrices A/B	    // [y] from UJI to CU [y]
    logic use_stepping;         // habilita el uso de stepping      // [y] from UJI to CU [n]

    logic exec_active;          // High during execution            // [y] from CU to UJI [n]
    logic exec_done;            // High when cycle completes        // [y] from CU to UJI [n]
    
    //--------------------------------------------------------------------------
    // Instancia de control_unit
    //--------------------------------------------------------------------------
    control_unit #(
        .P(P)
    ) cu_inst (
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

    //--------------------------------------------------------------------------
    // Instancia de User JTAG Interface
    //--------------------------------------------------------------------------
    user_jtag_interface #(
        .K(K)
    ) UJI (
        .clk               (clk),
        .rst               (rst),

        .cmd_in            (cmd_in),
        .use_relu_in       (use_relu_in),
        .use_stepping_in   (use_stepping_in),
        .mat_sel           (mat_sel_in),
        .address           (address_in),
        .din16             (din16_in),
        .perf_sel          (perf_sel_in),

        .confirm           (confirm_uji),

        .use_relu_out      (use_relu),
        .use_stepping_out  (use_stepping),
        .start_exec        (start_exec),
        .matrices_loaded   (matrices_loaded),
        .stop_exec         (stop_exec)
    );


    //----------------------------------------------------------------------
    // JTAG lol
    //----------------------------------------------------------------------

    //--- Señales internas para el JTAG ---
    logic tck;
    // logic tdi;
    logic [7:0] ir_in, ir_out;
    //logic tdo;
	//assign rst = ~key0;         // Reset activo en alto

    logic virtual_state_cdr;
    logic virtual_state_sdr;
    logic virtual_state_e1dr;
    logic virtual_state_pdr;
    logic virtual_state_e2dr;
    logic virtual_state_udr;
    logic virtual_state_cir;
    logic virtual_state_uir;

    // Instancia del módulo sld_virtual_jtag
    vjtag
        // .sld_auto_instance_index("YES"),
        // .sld_instance_index(0),
        // .sld_ir_width(8),
        // .sld_sim_action(""),
        // .sld_sim_n_scan(""),
        // .sld_sim_total_length(0)
     jtag_inst (
        .tck(altera_reserved_tck),
        .tdi(altera_reserved_tdi),
        .tdo(altera_reserved_tdo),
        .ir_in(ir_in),
        .ir_out(ir_out),
        .virtual_state_cdr(virtual_state_cdr),
        .virtual_state_sdr(virtual_state_sdr),
        .virtual_state_e1dr(virtual_state_e1dr),
        .virtual_state_pdr(virtual_state_pdr),
        .virtual_state_e2dr(virtual_state_e2dr),
        .virtual_state_udr(virtual_state_udr),
        .virtual_state_cir(virtual_state_cir),
        .virtual_state_uir(virtual_state_uir)
    );


    //----------------------------------------------------------------------
    // FPGA Display
    //----------------------------------------------------------------------

    // Instancia del módulo que muestra el valor de TDI en HEX0 y HEX1
    sseg_display tdi_disp_inst (
        .tdi(tdi),
        .HEX0(sseg_hex1),
        .HEX1(sseg_hex0)
    );

    // Led para verificar el reset
    assign rst_led = ~rst;

endmodule
