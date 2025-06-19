/*
Test bench for Systolic Array module
Date: 11/06/25
Approved with 3x3 matrix
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
*/
import pkg_systolic::*;

module tb_systolic_array;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    s16_t   a_mat [0:K-1][0:K-1];   // matriz A
    s16_t   b_mat [0:K-1][0:K-1];   // matriz B
    logic   valid_in;               // habilita stream

    // Bordes para systolic array
    s16_t   a_col0 [0:K-1];         // columna de A
    s16_t   b_row0 [0:K-1];         // fila de B
    logic   data_validity [0:K-1];  // habilita stream

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

    // Resultado global
    logic c_valid;     // pulso por banda C
    s32_t c_mat [0:K-1][0:K-1]; // matriz resultante

    systolic_array #(
        .M (K),
        .K (K)
    ) uut (
        .clk      (clk),
        .rst      (rst),
        .a_col0   (a_col0),
        .b_row0   (b_row0),
        .valid_in (data_validity),
        .c_mat    (c_mat),
        .c_valid  (c_valid)
    );

    // inner wiring feeder
    int unsigned fc; 
    // inner wiring uut
    s16_t a_bus [0:K-1][0:K];
    s16_t b_bus [0:K][0:K-1];
    logic v_bus [0:K-1][0:K];

    // Initialize inputs
    initial begin
		$display("systolic array module testbench:\n");

		clk = 1'b0;
        rst = 1'b0;

        /*
        a_mat = '{
            '{  0,  0,  0  },   // fila 0
            '{  0,  0,  0  },   // fila 1
            '{  0,  0,  0  }    // fila 3
        };
        b_mat = '{
            '{  0,  0,  0  },   // fila 0
            '{  0,  0,  0  },   // fila 1
            '{  0,  0,  0  }    // fila 3
        };
        */

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

        fc = feeder.fc;

        a_bus = uut.a_bus;
        b_bus = uut.b_bus;
        v_bus = uut.v_bus;
    end

    // Variables de referencia
    // s32_t exp_sum;
    // int   err_cnt = 0;
    //int seed = 77;

    // Sembrar el RNG una sola vez
    //initial $urandom(seed);

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        valid_in = 1'b1;

        /*
        a_mat = '{
            '{  1,  3,  -2  },   // fila 0
            '{  2,  0,  4  },    // fila 1
            '{  3,  -1,  1  }    // fila 2
        };
        b_mat = '{
            '{  2,  -1,  3  },   // fila 0
            '{  0,  4,  5  },    // fila 1
            '{  -2,  1,  0  }    // fila 2
        };
        */

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


        // #900 // K=3
        #900 // K=4

        valid_in = 0;

        // #200

        // @(posedge clk);

        // valid_in = 1'b1;

        // a_mat = '{
        //     '{  8,  -3,  5  },   // fila 0
        //     '{  -1,  2,  -6  },    // fila 1
        //     '{  0,  7,  -9  }    // fila 2
        // };
        // b_mat = '{
        //     '{  5,  3,  -3  },   // fila 0
        //     '{  -6,  0,  -5  },    // fila 1
        //     '{  4,  -1,  8  }    // fila 2
        // };

        // #900

        // valid_in = 0;

        #200;

		// Done

    end

    initial
	#3000 $finish;                                 

endmodule
