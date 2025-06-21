/*
Test bench for Systolic Array module
Date: 11/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_systolic_array/a_mat
add wave -radix signed /tb_systolic_array/b_mat
add wave -radix signed /tb_systolic_array/a_col0
add wave -radix signed /tb_systolic_array/b_row0
add wave -radix binary /tb_systolic_array/data_validity
add wave -radix signed /tb_systolic_array/a_bus
add wave -radix signed /tb_systolic_array/b_bus
add wave -radix binary /tb_systolic_array/v_bus
add wave -radix signed /tb_systolic_array/c_mat
add wave -radix signed /tb_systolic_array/pe_mult_count
add wave -radix signed /tb_systolic_array/pe_sum_count
add wave -radix signed /tb_systolic_array/pe_accum_count
*/
import pkg_systolic::*;

module tb_systolic_array;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int P        = 32;   // cantidad de bits para perf. counters
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    s16_t a_mat [0:K-1][0:K-1];     // matriz A
    s16_t b_mat [0:K-1][0:K-1];     // matriz B
    logic valid_in;                 // habilita stream

    // Bordes para systolic array
    s16_t a_col0 [0:K-1];           // columna de A
    s16_t b_row0 [0:K-1];           // fila de B
    logic data_validity [0:K-1];    // habilita stream

    matrix_feeder #(
        .K(K)
    ) feeder (
        .clk        (clk),
        .rst        (rst),
        .a_mat      (a_mat),
        .b_mat      (b_mat),
        .valid_in   (valid_in),
        .a_col0     (a_col0),
        .b_row0     (b_row0),
        .valid_out  (data_validity)
    );

    logic use_relu;                 // habilita el uso del relu
    // Resultado global
    logic c_valid;                  // pulso por banda C
    s32_t c_mat [0:K-1][0:K-1];     // matriz resultante
    // Performance counters por PE
    logic [P-1:0] pe_mult_count [0:K-1][0:K-1];
    logic [P-1:0] pe_sum_count  [0:K-1][0:K-1];
    logic [P-1:0] pe_accum_count[0:K-1][0:K-1];
    // Performance counters totales agregados
    logic [P-1:0] total_mult_count;
    logic [P-1:0] total_sum_count;
    logic [P-1:0] total_accum_count;

    systolic_array #(
        .K(K),
        .P(P)
    ) uut (
        .clk                (clk),
        .rst                (rst),
        .a_col0             (a_col0),
        .b_row0             (b_row0),
        .valid_in           (data_validity),
        .use_relu           (use_relu),
        .c_mat              (c_mat),
        .c_valid            (c_valid),
        .pe_mult_count      (pe_mult_count),
        .pe_sum_count       (pe_sum_count),
        .pe_accum_count     (pe_accum_count),
        .total_mult_count   (total_mult_count),
        .total_sum_count    (total_sum_count),
        .total_accum_count  (total_accum_count)
    );

    // inner wiring feeder
    int unsigned fc; 
    // inner wiring uut
    s16_t a_bus [0:K-1][0:K];
    s16_t b_bus [0:K][0:K-1];
    logic v_bus [0:K-1][0:K];

    // Initialize inputs
    initial begin
		$display("Systolic array module testbench:\n");

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
		use_relu = 1'b0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        fc = feeder.fc;

        a_bus = uut.a_bus;
        b_bus = uut.b_bus;
        v_bus = uut.v_bus;
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
        use_relu = 1'b1;

        a_mat = '{
            '{  2,  -1,  0,  6  },   // fila 0
            '{  -7,  5,  6,  -4  },  // fila 1
            '{  8,  1,  -2,  3  },   // fila 2
            '{  0,  7,  -9,  1  }    // fila 3
        };
        b_mat = '{
            '{  5,  0,  2,  -3  },   // fila 0
            '{  -4,  6,  7,  1  },   // fila 1
            '{  8,  -9,  0,  9  },   // fila 2
            '{  1,  3,  -5,  2  }    // fila 3
        }; 

        #800

        valid_in = 0;

        
        // --- espera a que el systolic array active c_valid ---
        wait(c_valid);


        @(posedge clk);

        /* NO RELU */
        valid_in = 1'b1;
        use_relu = 1'b0;

        a_mat = '{
            '{  6,  3,  -1,  0  },
            '{  7,  -5,  2,  4  },
            '{  -3,  -6,  2,  9  },
            '{  5,  4,  0,  -9  }
        };
        b_mat = '{
            '{  9,  -1,  0,  -5  },
            '{  4,  2,  -7,  0  },
            '{  -6,  1,  3,  9  },
            '{  0,  -3,  5,  8  }
        };

        #800

        valid_in = 0;


        // --- espera a que el systolic array active c_valid ---
        wait(c_valid);


        @(posedge clk);

        rst = 1;

        @(posedge clk);

        rst = 0;


		// Done

    end

    initial
	#4000 $finish;                                 

endmodule
