/*
Test bench for Matrix Prefetcher module
Date: 17/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_matrix_prefetcher/memA
add wave -radix signed /tb_matrix_prefetcher/memB
add wave -radix signed /tb_matrix_prefetcher/a_mat
add wave -radix signed /tb_matrix_prefetcher/b_mat
*/
import pkg_systolic::*;

module tb_matrix_prefetcher;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;
	
    // Interfaz al UUT
	// logic we16;
    logic re16;
    logic mat_sel;
    logic [$clog2(K*K)-1:0] addr16;
    // s16_t din16;

    s16_t dout16; 
    logic ready16;
    logic stall16;

    // logic we32;
    // logic re32;
    // logic [$clog2(K*K)-1:0] addr32;
    // s32_t din32;
    // s32_t dout32;
    // logic ready32;
    // logic stall32;

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena A, B (16 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K (K)
    ) mram (
        .clk     (clk),
        .rst     (rst),
        // Puerto A/B de 16 bits
        // .we16    (we16),  // 1→din16→mem[mat_sel?B:A][addr16]
        .re16    (re16),  // 1→mem[mat_sel?B:A][addr16]→dout16
        .mat_sel (mat_sel),  // 0=A, 1=B
        .addr16  (addr16),   // índice fila-major 0…K*K–1
        // .din16   (din16),  // dato de entrada

        .dout16  (dout16),  // dato de salida
        .ready16 (ready16),  // 1-clk cuando la operación acaba
        .stall16 (stall16)  // 1 mientras la memoria no esté lista
        // Puerto C de 32 bits
        // .we32    (we32),  // 1→din32→memC[addr32]
        // .re32    (re32),  // 1→memC[addr32]→dout32
        // .addr32  (addr32),   // índice fila-major 0…K*K–1
        // .din32   (din32),  // dato de entrada
        // .dout32  (dout32),  // dato de salida
        // .ready32 (ready32),  // 1-clk cuando la operación acaba
        // .stall32 (stall32)   // 1 mientras la memoria no esté lista
    );

    // matrix prefetcher wires 
    logic matrices_ready;       // señal que indica a MRAM llenada
    logic prefetch_start;        
    s16_t a_mat [0:K-1][0:K-1]; // matriz A
    s16_t b_mat [0:K-1][0:K-1]; // matriz B
    logic ready_to_npu;         // pulso 1-ciclo: matrices cargadas

    matrix_prefetcher #(
        .K(K)
    ) uut (
        .clk              (clk),
        .rst              (rst),
        // Control signals
        .matrices_ready   (matrices_ready), // Tiene que venir del modulo que carga las matrices a MRAM
        .prefetch_start   (prefetch_start), // Vendrá de un control unit
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
        // Salida de control
        .ready_to_npu     (ready_to_npu)
    );

    // inner wiring MRAM
    s16_t memA [0:K*K-1];
    s16_t memB [0:K*K-1];
    // inner wiring uut
    logic [1:0] state;
    localparam int NUM_ELEM = K * K;
    localparam int IDX_W = (NUM_ELEM <= 1) ? 1 : $clog2(NUM_ELEM + 1);
    logic [IDX_W-1:0] idx;
    logic request_pending;

    // Initialize inputs
    initial begin
		$display("\nMatrix Prefetcher module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        matrices_ready = 1'b0;
        prefetch_start = 1'b0;

		re16 = 1'b0;
		mat_sel = 1'b0;
		addr16 = 0;

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

        state = uut.state;
        idx = uut.idx;
        request_pending = uut.request_pending;
    end

    // Variables de referencia

    initial	begin

        repeat (1) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        matrices_ready = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b0;

        
        // --- espera a que el NPU active el done ---
        wait(ready_to_npu);


        @(posedge clk);

        matrices_ready = 1'b0;

        @(posedge clk);

        mram.memA = '{
            6,  3,  -1,  0,
            7,  -5,  2,  4,
            -3,  -6,  2,  9,
            5,  4,  0,  -9
        };
        mram.memB = '{
            9,  -1,  0,  -5,
            4,  2,  -7,  0,
            -6,  1,  3,  9,
            0,  -3,  5,  8
        };

        @(posedge clk);

        matrices_ready = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b1;

        @(posedge clk);

        prefetch_start = 1'b0;

		// Done

    end

    initial
	#21000 $finish;    

endmodule
