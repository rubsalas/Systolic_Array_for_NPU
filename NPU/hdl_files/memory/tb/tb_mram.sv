/*
Test bench for MRAM module
Date: 16/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_mram/memA
add wave -radix signed /tb_mram/memB
add wave -radix signed /tb_mram/memC
*/
import pkg_systolic::*;

module tb_mram;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;
	
    // Interfaz al UUT
	logic we16;
    logic re16;
    logic mat_sel;
    logic [$clog2(K*K)-1:0] addr16;
    s16_t din16;
    s16_t dout16; 
    logic ready16;
    logic stall16;

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
    ) uut (
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

    // inner wiring
    s16_t memA [0:K*K-1];  // Banco A: K*K elementos de 16 bits
    s16_t memB [0:K*K-1];  // Banco B: K*K elementos de 16 bits
    s32_t memC [0:K*K-1];  // Banco C: K*K elementos de 32 bits

    // Initialize inputs
    initial begin
		$display("\nMRAM module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

		we16 = 1'b0;
		re16 = 1'b0;
		mat_sel = 1'b0;
		addr16 = 0;
		din16 = 0;

		we32 = 1'b0;
		re32 = 1'b0;
		addr32 = 0;
		din32 = 0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        memA = uut.memA;
        memB = uut.memB;
        memC = uut.memC;
    end

    // Variables de referencia

    initial	begin

        repeat (1) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);
        /* Escritura inicial de matriz A */
        we16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 0;
		din16 = 2;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 1;
		din16 = -1;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 2;
		din16 = 0;

        @(posedge clk);
        // Prueba de we16 = 0
        we16 = 1'b0;
        mat_sel = 1'b0;
        addr16 = 3;
		din16 = 6;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 3;
		din16 = 6;

        @(posedge clk);
        // Prueba de we16 = 0
        // Cambio de mat_sel
        we16 = 1'b0;
        mat_sel = 1'b1;
        addr16 = 0;
		din16 = -1;

        @(posedge clk);
        /* Escritura inicial de matriz B */
        we16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 0;
		din16 = 5;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 1;
		din16 = 0;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 2;
		din16 = 2;

        @(posedge clk);

        we16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 3;
		din16 = -3;

        @(posedge clk);
        // Prueba de we16 = 0
        // Cambio de mat_sel
        we16 = 1'b0;
        mat_sel = 1'b0;
        addr16 = 0;
		din16 = -1;

        @(posedge clk);
        /* Escritura inicial de matriz C */
        we32 = 1'b1;
        addr32 = 0;
		din32 = 20;

        @(posedge clk);

        we32 = 1'b1;
        addr32 = 1;
		din32 = 12;

        @(posedge clk);
        // Prueba de we32 = 0
        we32 = 1'b0;
        addr32 = 2;
		din32 = -33;

        @(posedge clk);
        
        we32 = 1'b1;
        addr32 = 2;
		din32 = 0;

        @(posedge clk);
        
        we32 = 1'b1;
        addr32 = 3;
		din32 = 5;

        @(posedge clk);
        // Prueba de we32 = 0
        we32 = 1'b0;
        addr32 = 0;
		din32 = -1;

        @(posedge clk);
        /* Lectura de matriz A */
        re16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 0;

        @(posedge clk);

        re16 = 1'b1;
        mat_sel = 1'b0;
        addr16 = 1;

        @(posedge clk);
        // Prueba de re16=0
        re16 = 1'b0;
        mat_sel = 1'b0;
        addr16 = 2;

        @(posedge clk);
        /* Lectura de matriz B */
        re16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 2;

        @(posedge clk);
        
        re16 = 1'b1;
        mat_sel = 1'b1;
        addr16 = 3;

        @(posedge clk);
        // Prueba de re16=0
        re16 = 1'b0;
        mat_sel = 1'b0;
        addr16 = 0;

        @(posedge clk);
        /* Lectura de matriz C */
        re32 = 1'b1;
        addr32 = 0;

        @(posedge clk);
        
        re32 = 1'b1;
        addr32 = 1;

        @(posedge clk);
        // Prueba de re32=0
        re32 = 1'b0;
        addr32 = 4;

        @(posedge clk);
        
        re32 = 1'b1;
        addr32 = 2;

        @(posedge clk);
        
        re32 = 1'b1;
        addr32 = 3;

        @(posedge clk);
        // Prueba de re32=0
        re32 = 1'b0;
        addr32 = 0;

		// Done

    end

    initial
	#3500 $finish;    

endmodule
