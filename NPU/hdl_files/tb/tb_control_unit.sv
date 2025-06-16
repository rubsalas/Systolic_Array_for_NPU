/*
Test bench for Control Unit module
Date: 14/06/25
Approved
*/
import pkg_systolic::*;

module tb_control_unit;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;
	 
	logic start;
    logic matrix_done;

    logic valid_out;
    logic busy;
    logic done;

	control_unit #(
        .K(K)
    ) uut (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .matrix_done (matrix_done),
        .valid_out   (valid_out),
        .busy        (busy),
        .done        (done)
    );

    // inner wiring
    localparam int CW_K = (K <= 1) ? 1 : $clog2(K);  // ancho para 0 … K-1

    logic [1:0] st, nxt;
    logic [CW_K-1:0] k_cnt;       // cuenta STREAM

    // Initialize inputs
    initial begin
		$display("control unit module testbench:\n");

		clk = 1'b0;
        rst = 1'b0;

		start = 1'b0;
		matrix_done = 1'b0;
    end

    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        st = uut.st;
        nxt = uut.nxt;
        k_cnt = uut.k_cnt;
    end

    // Variables de referencia

    initial	begin

        repeat (2) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        @(posedge clk);

        start = 1'b1;

        @(posedge clk);

        start = 1'b0;


        #800;


        @(posedge clk);

        matrix_done = 1'b1;

        @(posedge clk);

        matrix_done = 1'b0;

        @(posedge clk);

        start = 1'b1;

        @(posedge clk);

        start = 1'b0;


		// Done

    end

    initial
	#2000 $finish;    

endmodule
