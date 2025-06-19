/*
Test bench for NPU module
Date: 15/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_npu/a_mat
add wave -radix signed /tb_npu/b_mat
add wave -radix signed /tb_npu/a_col0
add wave -radix signed /tb_npu/b_row0
add wave -radix binary /tb_npu/data_validity
add wave -radix binary /tb_npu/c_valid_band
add wave -radix signed /tb_npu/c_mat
*/
import pkg_systolic::*;

module tb_npu;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;
	
    // Interfaz al UUT
    s16_t a_mat [0:K-1][0:K-1];   // matriz A
    s16_t b_mat [0:K-1][0:K-1];   // matriz B
	logic start;

    logic busy;
    logic done;
    s32_t c_mat [0:K-1][0:K-1];   // matriz C

	NPU #(
        .M(K),
        .K(K)
    ) uut (
        .clk   (clk),
        .rst   (rst),
        .a_mat (a_mat),
        .b_mat (b_mat),
        .start (start),
        .busy  (busy),
        .done  (done),
        .c_mat (c_mat)
    );

    // inner wiring
    // Control Unit wires
    logic result_done;
    logic valid_stream;
    logic [1:0] st;
    localparam int CW_K = (K <= 1) ? 1 : $clog2(K*2);
    logic [CW_K-1:0] k_cnt;         // cuenta STREAM
    // Matrix Feeder wires
    s16_t a_col0 [0:K-1];           // columna de A
    s16_t b_row0 [0:K-1];           // fila de B
    logic data_validity [0:K-1];
    int unsigned fc;
    // Systolic Array wires
    logic [0:K-1] c_valid_band;

    // Initialize inputs
    initial begin
		$display("\nNPU module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

		start = 1'b0;
        a_mat = '{
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  }
        };
        b_mat = '{
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  },
            '{  0,  0,  0,  0  } 
        };
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        result_done = uut.result_done;
        valid_stream = uut.valid_stream;
        st = uut.controller.st;
        k_cnt = uut.controller.k_cnt;
        a_col0 = uut.a_col0;
        b_row0 = uut.b_row0;
        data_validity = uut.data_validity;
        fc = uut.feeder.fc;
        c_valid_band = uut.u_array.c_valid_band;
    end

    // Variables de referencia

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        start = 1'b1;

        a_mat = '{
            '{  2,  -1,  0,  6  },
            '{  -7,  5,  6,  -4  },
            '{  8,  1,  -2,  3  },
            '{  0,  7,  -9,  1  }
        };
        b_mat = '{
            '{  5,  0,  2,  -3  },
            '{  -4,  6,  7,  1  },
            '{  8,  -9,  0,  9  },
            '{  1,  3,  -5,  2  }
        };

        @(posedge clk);

        start = 1'b0;

        // --- espera a que el NPU active el done ---
        wait(done);

        @(posedge clk);

        start = 1'b1;

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

        @(posedge clk);

        start = 1'b0;

		// Done

    end

    initial
	#4000 $finish;    

endmodule
