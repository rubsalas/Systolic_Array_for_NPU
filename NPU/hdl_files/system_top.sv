//=============================================================================
// npu_system_top
//   • Instancia la NPU (systolic array + feeder + CU)
//   • Instancia una MRAM sencilla que actúa como memoria global
//   • Posible conexion JTAG
//=============================================================================
`timescale 1ns/1ps
import pkg_systolic::*;

module system_top #(
    parameter int M = 4,
    parameter int K = 4     // dimensión de matriz
)(
    input  logic clk,
    input  logic rst,

    input  logic tdo,

    output logic tdi,

    output logic [6:0] sseg_hex1,
	output logic [6:0] sseg_hex0,
    output logic rst_led
);


    //--------------------------------------------------------------------------
    // Señales internas para la MRAM (puerto A/B de 16 bits y C de 32 bits)
    //--------------------------------------------------------------------------
    // Puertos de 16 bits
    logic we16;             // habilita escritura de A o B              // [y] from MRAM to [n]
    logic re16;             // habilita lectura de A o B                // [y] from MRAM to MtxPref [y]
    logic mat_sel;          // 0→A, 1→B                                 // [y] from MRAM to MtxPref [y]
    logic [$clog2(K*K)-1:0] addr16; //  dirección 0…K*K–1 para A/B      // [y] from MRAM to MtxPref [y]
    s16_t din16;            // dato de 16 bits a escribir en A/B        // [y] from MRAM to [n]
    s16_t dout16;           // dato leído de A/B                        // [y] from MRAM to MtxPref [y]
    logic ready16;          // pulso 1-clk cuando termina we16 o re16   // [y] from MRAM to MtxPref [y]
    logic stall16;          // 1 mientras ready16=0 (back-pressure)     // [y] from MRAM to MtxPref [y]
    // Puertos de 32 bits
    logic we32;             // habilita escritura de C                  // [y] from MRAM to [n]
    logic re32;             // habilita lectura de C                    // [y] from MRAM to [n]
    logic [$clog2(K*K)-1:0] addr32; // dirección 0…K*K–1 para C         // [y] from MRAM to [n]
    s32_t din32;            // dato de 32 bits a escribir en C          // [y] from MRAM to [n]
    s32_t dout32;           // dato leído de C                          // [y] from MRAM to [n]
    logic ready32;          // pulso 1-clk cuando termina we32 o re32   // [y] from MRAM to [n]
    logic stall32;          // 1 mientras ready32=0                     // [y] from MRAM to [n]

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena A, B (16 bits) y C (32 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K (K)
    ) u_mram (
        .clk     (clk),
        .rst     (rst),
        // Puerto A/B de 16 bits
        .we16    (we16),        // 1→din16→mem[mat_sel?B:A][addr16]
        .re16    (re16),        // 1→mem[mat_sel?B:A][addr16]→dout16
        .mat_sel (mat_sel),     // 0=A, 1=B
        .addr16  (addr16),      // índice fila-major 0…K*K–1
        .din16   (din16),       // dato de entrada

        .dout16  (dout16),      // dato de salida
        .ready16 (ready16),     // 1-clk cuando la operación acaba
        .stall16 (stall16),     // 1 mientras la memoria no esté lista
        // Puerto C de 32 bits
        .we32    (we32),        // 1→din32→memC[addr32]
        .re32    (re32),        // 1→memC[addr32]→dout32
        .addr32  (addr32),      // índice fila-major 0…K*K–1
        .din32   (din32),       // dato de entrada

        .dout32  (dout32),      // dato de salida
        .ready32 (ready32),     // 1-clk cuando la operación acaba
        .stall32 (stall32)      // 1 mientras la memoria no esté lista
    );

    
    // matrix prefetcher wires 
    logic matrices_loaded;      // señal que indica a MRAM llenada  // [y] from MtxPref to [n]
    logic prefetch_start;       // indica que inicie el prefetch    // [y] from MtxPref to [n]
    s16_t a_mat [0:K-1][0:K-1]; // matriz A                         // [y] from MtxPref to NPU [y]
    s16_t b_mat [0:K-1][0:K-1]; // matriz B                         // [y] from MtxPref to NPU [y]
    logic npu_start;            // pulso 1-ciclo: matrices cargadas // [y] from MtxPref to NPU [y]

    matrix_prefetcher #(
        .K(K)
    ) prefetch (
        .clk              (clk),
        .rst              (rst),
        .matrices_ready   (matrices_loaded), // Tiene que venir del modulo que carga las matrices a MRAM
        .prefetch_start   (prefetch_start),
        // Conexión MRAM 16-bit
        .dout16           (dout16),     //ok
        .ready16          (ready16),    //ok
        .stall16          (stall16),    //ok

        .re16             (re16),       //ok
        .mat_sel          (mat_sel),    //ok
        .addr16           (addr16),     //ok
        // Salida a NPU
        .a_mat            (a_mat),
        .b_mat            (b_mat),
        .ready_to_npu     (npu_start)
    );


    // NPU wires
    logic npu_busy;  // [y] from NPU to [n]
    logic npu_done;  // [y] from NPU to [n]
    s32_t c_mat [0:K-1][0:K-1]; // matriz resultante // [y] from NPU to [n]

    //----------------------------------------------------------------------
    // Instancia NPU
    //----------------------------------------------------------------------
    NPU #(
        .M(K),
        .K(K)
    ) u_npu (
        .clk   (clk),
        .rst   (rst),
        .a_mat (a_mat),
        .b_mat (b_mat),
        .start (npu_start),
        .busy  (npu_busy),
        .done  (npu_done),
        .c_mat (c_mat)
    );


    //----------------------------------------------------------------------
    // JTAG lol
    //----------------------------------------------------------------------

    // Señales internas para el JTAG
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

    // Instancia del módulo que muestra el valor de TDI en HEX0 y HEX1
    sseg_display tdi_disp_inst (
        .tdi(tdi),
        .HEX0(sseg_hex1),
        .HEX1(sseg_hex0)
    );

    // Led para verificar el reset
    assign rst_led = ~rst;

endmodule
