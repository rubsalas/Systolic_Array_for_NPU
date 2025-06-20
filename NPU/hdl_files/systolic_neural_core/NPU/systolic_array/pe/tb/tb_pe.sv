/*
Test bench for PE module
Date: 05/06/25
Approved
*/
import pkg_systolic::*;

module tb_pe;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int P        = 32;   // cantidad de bits para perf. counters
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    // Interfaz al UUT
    s16_t a_in;
    s16_t b_in;
    logic valid_in;

    s16_t a_out;
    s16_t b_out;
    logic valid_out;

    s32_t c_out;
    logic c_valid;

    logic [P-1:0] perf_mult_count;  // número de multiplicaciones realizadas
    logic [P-1:0] perf_sum_count;   // número de sumas en el acumulador
    logic [P-1:0] perf_accum_count; // número de bloques acumulados (resultados)

    /* pe unit under testing */
    pe #(
        .K(K),
        .P(P)
    ) uut (
        .clk                (clk),
        .rst                (rst),
        .a_in               (a_in),
        .b_in               (b_in),
        .valid_in           (valid_in),

        .a_out              (a_out),
        .b_out              (b_out),
        .valid_out          (valid_out),
        .c_out              (c_out),
        .c_valid            (c_valid),
        .perf_mult_count    (perf_mult_count),
        .perf_sum_count     (perf_sum_count),
        .perf_accum_count   (perf_accum_count)
    );

    // inner wiring
    logic v_reg;
    s32_t prod;
    s32_t acc_val;
    logic last_prod;
    s32_t relu_out;
    logic relu_valid;
    s32_t c_hold;
    logic have_res;
    logic start_next;

    // Initialize inputs
    initial begin
		$display("pe module testbench:\n");

		clk = 1'b0;
        rst = 1'b0;

		valid_in = 1'b0;
		a_in = 0;
		b_in = 0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        v_reg = uut.v_reg;
        prod = uut.prod;
        acc_val = uut.acc_val;
        last_prod = uut.last_prod;
        relu_out = uut.relu_out;
        relu_valid = uut.relu_valid;
        c_hold = uut.c_hold;
        have_res = uut.have_res;
        start_next = uut.start_next;
    end
            
    // Variables de referencia
    // s32_t exp_sum;
    // int   err_cnt = 0;
    // int   seed    = 29;

    // Sembrar el RNG una sola vez
    // initial $urandom(seed);

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        // Suma 1/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 2; 
        b_in = 5; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 2/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = -1; 
        b_in = -4; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 3/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 0; 
        b_in = 8; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 4/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 6; 
        b_in = 1; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        valid_in = 0;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 69; 
        b_in = 69; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        valid_in = 0;

        @(posedge clk);

        valid_in = 0;

        @(posedge clk);

        valid_in = 0;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 42; 
        b_in = 42; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 1/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 2; 
        b_in = 0; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 2/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = -1; 
        b_in = 6;  

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 3/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 0; 
        b_in = -9; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Suma 4/4
		valid_in = 1;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 6;
        b_in = 3; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        valid_in = 0;
        // a_in  = $urandom_range(RANGE * 2) - RANGE; 
        // b_in  = $urandom_range(RANGE * 2) - RANGE;
        a_in = 69; 
        b_in = 69; 

        $display("[%0t] a_in=%0d b_in=%0d valid_in=%0d a_out=%0d b_out=%0d valid_out=%0d c_out=%0d c_valid=%0d",
                 $time, a_in, b_in, valid_in, a_out, b_out, valid_out, c_out, c_valid); 
	 
        @(posedge clk);

        // Done

    end

    initial
	#2000 $finish;                                 

endmodule
