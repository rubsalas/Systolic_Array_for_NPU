/*
Test bench for Matrix Commiter module
Date: 18/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_matrix_committer/memC
add wave -radix signed /tb_matrix_committer/c_mat
*/
import pkg_systolic::*;

module tb_matrix_committer;

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
    // logic re16;
    // logic mat_sel;
    // logic [$clog2(K*K)-1:0] addr16;
    // s16_t din16;
    // s16_t dout16; 
    // logic ready16;
    // logic stall16;

    logic we32;
    // logic re32;
    logic [$clog2(K*K)-1:0] addr32;
    s32_t din32;

    // s32_t dout32;
    logic ready32;
    logic stall32;

    //--------------------------------------------------------------------------
    // Instancia de la MRAM: almacena C (32 bits)
    //--------------------------------------------------------------------------
    MRAM #(
        .K (K)
    ) mram (
        .clk     (clk),
        .rst     (rst),
        // Puerto A/B de 16 bits
        // .we16    (we16),  // 1→din16→mem[mat_sel?B:A][addr16]
        // .re16    (re16),  // 1→mem[mat_sel?B:A][addr16]→dout16
        // .mat_sel (mat_sel),  // 0=A, 1=B
        // .addr16  (addr16),   // índice fila-major 0…K*K–1
        // .din16   (din16),  // dato de entrada
        // .dout16  (dout16),  // dato de salida
        // .ready16 (ready16),  // 1-clk cuando la operación acaba
        // .stall16 (stall16)  // 1 mientras la memoria no esté lista
        // Puerto C de 32 bits
        .we32    (we32),  // 1→din32→memC[addr32]
        // .re32    (re32),  // 1→memC[addr32]→dout32
        .addr32  (addr32),   // índice fila-major 0…K*K–1
        .din32   (din32),  // dato de entrada

        // .dout32  (dout32),  // dato de salida
        .ready32 (ready32),  // 1-clk cuando la operación acaba
        .stall32 (stall32)   // 1 mientras la memoria no esté lista
    );

    // matrix commiter wires 
    logic data_ready;  // npu_done from NPU
    logic commit_start;         // indica que inicie el commit
    s32_t c_mat [0:K-1][0:K-1]; // matriz C resultante
    logic ready_to_ram;         // señal que indica que se ha escrito en MRAM

    matrix_committer #(
        .K(K)
    ) uut (
        .clk          (clk),
        .rst          (rst),
        // Control signals
        .data_ready   (data_ready),     // from NPU
        .commit_start (commit_start),   // Vendrá de un control unit
        // Entradas desde NPU
        .c_mat        (c_mat),          // from NPU
        // Conexión MRAM 32-bit
        .ready32      (ready32),        //ok
        .stall32      (stall32),        //ok

        .we32         (we32),           //ok
        .addr32       (addr32),         //ok
        .din32        (din32),          //ok
        // Salida de control
        .ready_to_ram (ready_to_ram)    // Tiene que ir al modulo que leerá la matriz resultante del MRAM
    );

    // inner wiring MRAM
    s32_t memC [0:K*K-1];
    // inner wiring uut
    logic [1:0] state;
    localparam int NUM_ELEM = K * K;
    localparam int IDX_W = (NUM_ELEM <= 1) ? 1 : $clog2(NUM_ELEM + 1);
    logic [IDX_W-1:0] idx;
    logic request_pending;

    // Initialize inputs
    initial begin
		$display("\nMatrix Commiter module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        data_ready = 1'b0;
        commit_start = 1'b0;

        c_mat = '{
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  }
        };
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        memC = mram.memC;

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

        c_mat = '{
            '{  2,  -1,  0,  6  },
            '{  -7,  5,  6,  -4  },
            '{  8,  1,  -2,  3  },
            '{  0,  7,  -9,  1  }
        };

        @(posedge clk);

        data_ready = 1'b1;

        @(posedge clk);

        commit_start = 1'b1;

        @(posedge clk);

        commit_start = 1'b0;


        // --- espera a que se termine de escribir en MRAM ---
        wait(ready_to_ram);


        @(posedge clk);

        data_ready = 1'b0;

        @(posedge clk);

        c_mat = '{
            '{  5,  0,  2,  -3  },
            '{  -4,  6,  7,  1  },
            '{  8,  -9,  0,  9  },
            '{  1,  3,  -5,  2  }
        };

        @(posedge clk);

        data_ready = 1'b1;

        @(posedge clk);

        commit_start = 1'b1;

        @(posedge clk);

        commit_start = 1'b0;

		// Done

    end

    initial
	#12000 $finish;    

endmodule
