/*
Test bench for Matrix Feeder module
Date: 12/06/25
NY Approved
*/
/*
add wave *

add wave -radix signed /tb_matrix_feeder/a_mat
add wave -radix signed /tb_matrix_feeder/b_mat
add wave -radix signed /tb_matrix_feeder/a_col0
add wave -radix signed /tb_matrix_feeder/b_row0
add wave -radix binary /tb_matrix_feeder/valid_out
*/
import pkg_systolic::*;

module tb_matrix_feeder;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    // Interfaz al UUT
    s16_t   a_mat [0:K-1][0:K-1];   // matriz A
    s16_t   b_mat [0:K-1][0:K-1];   // matriz B
    logic   valid_in;               // habilita stream

    // Bordes para systolic array
    s16_t   a_col0 [0:K-1];         // columna de A
    s16_t   b_row0 [0:K-1];         // fila de B
    logic   valid_out [0:K-1];      // habilita stream

    /* systolic array unit under testing */
    matrix_feeder #(.K(K)) uut (
        .clk        (clk),
        .rst        (rst),
        .a_mat      (a_mat),
        .b_mat      (b_mat),
        .valid_in   (valid_in),
        .a_col0     (a_col0),
        .b_row0     (b_row0),
        .valid_out  (valid_out)
    );

    // inner wiring
    localparam int CNT_W = (K <= 1) ? 1 : $clog2(K*2);
    logic [CNT_W-1:0]  f_cycle;  // cantidad de ciclos consecutivos del feeder
    int unsigned fc; 

    // Initialize inputs
    initial begin
		$display("matrix feeder module testbench:\n");

		clk = 1'b0;
        rst = 1'b0;

        a_mat = '{
            '{  0,  0,  0,  0  },   // fila 0
            '{  0,  0,  0,  0  },   // fila 1
            '{  0,  0,  0,  0  },   // fila 2
            '{  0,  0,  0,  0  }    // fila 3
        };
        b_mat = '{
            '{  0,  0,  0,  0  },   // fila 0
            '{  0,  0,  0,  0  },   // fila 1
            '{  0,  0,  0,  0  },   // fila 2
            '{  0,  0,  0,  0  }    // fila 3
        };

		valid_in = 1'b0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        f_cycle = uut.f_cycle;
        fc = uut.fc;
    end

    // Variables de referencia
    // s32_t exp_sum;
    // int   err_cnt = 0;
    // int seed = 77;

    // Sembrar el RNG una sola vez
    // initial $urandom(seed);

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        valid_in = 1'b1;

        a_mat = '{
            '{  100,  101,  102,  103  },   // fila 0
            '{  104,  105,  106,  107  },   // fila 1
            '{  108,  109,  110,  111  },   // fila 2
            '{  112,  113,  114,  115  }    // fila 3
        };
        b_mat = '{
            '{  200,  201,  202,  203  },   // fila 0
            '{  204,  205,  206,  207  },   // fila 1
            '{  208,  209,  210,  211  },   // fila 2
            '{  212,  213,  214,  215  }    // fila 3
        };

        @(posedge clk);

		// Done

    end

    initial
	#1500 $finish;                                 

endmodule
