/*
Test bench for Accumulator module
Date: 31/08/24
NY Approved
*/
import pkg_systolic::*;

module tb_accumulator;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;   // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz

    logic clk;
    logic rst;

    // Interfaz al DUT
    logic valid_in;
    s32_t prod_in;

    s32_t acc_out;
    logic last_prod;

    /* accumulator unit under testing */
    accumulator #(.K(K)) uut (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .prod_in   (prod_in),
        .acc_out   (acc_out),
        .last_prod (last_prod)
    );

    // inner wiring
    localparam int CNT_W = (K <= 1) ? 1 : $clog2(K);
    logic [CNT_W-1:0] k_cnt;        // cuenta productos procesados
    logic             res_ready;

    // Initialize inputs
    initial begin
		$display("accumulator module testbench:\n");

		clk = 1'b0;
        rst = 1'b0;

		valid_in = 1'b0;
		prod_in = 0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        k_cnt = uut.k_cnt;
        res_ready = uut.res_ready;
    end
            
    // Variables de referencia
    s32_t exp_sum;
    int   err_cnt = 0;
    int   seed    = 17;

    // Sembrar el RNG una sola vez
    initial $urandom(seed);

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        // Suma 1/4
		valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 2/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000;
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 3/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 4/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Waiting for op
        valid_in = 0;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum = 0;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 1/4
		valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 2/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000;
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 3/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

        // Suma 4/4
        valid_in = 1;
        prod_in  = $urandom_range(2000) - 1000; 
        exp_sum += prod_in;

        $display("[%0t] k=%0d prod=%0d acc_now=%0d res_ready=%0d",
                 $time, k_cnt, prod_in, acc_out, res_ready); 
	 
        @(posedge clk);

		// Done

    end

    initial
	#2000 $finish;                                 

endmodule
