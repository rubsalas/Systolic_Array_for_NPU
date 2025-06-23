/*
Test bench for User JTAG Interface module
Date: 22/06/24
NY Approved
*/
import pkg_systolic::*;

module tb_user_jtag_interface;

	timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int CLK_PER  = 100;  // ns -> 100 MHz

    logic clk;
    logic rst;

    // Interfaz al UUT
	logic [3:0] cmd_in;
    logic       use_relu_in;
    logic       use_stepping_in;
    logic       mat_sel;
    logic       address;
    s16_t       din16;
    logic       perf_sel;

    // Command strobe
    logic       confirm;

    // Outputs to Control Unit
    logic       use_relu_out;
    logic       use_stepping_out;
    logic       start_exec;
    logic       matrices_loaded;
    logic       stop_exec;


    user_jtag_interface #(
        .K(K)
    ) uut (
        .clk               (clk),
        .rst               (rst),

        .cmd_in            (cmd_in),
        .use_relu_in       (use_relu_in),
        .use_stepping_in   (use_stepping_in),
        .mat_sel           (mat_sel),
        .address           (address),
        .din16             (din16),
        .perf_sel          (perf_sel),

        .confirm           (confirm),

        .use_relu_out      (use_relu_out),
        .use_stepping_out  (use_stepping_out),
        .start_exec        (start_exec),
        .matrices_loaded   (matrices_loaded),
        .stop_exec         (stop_exec)
    );

    // Inner wiring
    logic cmd_reg;
    logic confirm_d;
    logic confirm_fall;
    logic [3:0] state;
    logic [3:0] next_state;

    logic use_relu_reg;
    logic start_exec_reg;
    logic matrices_loaded_reg;
    logic stop_exec_reg;
    logic use_stepping_reg;


    // Initialize inputs
    initial begin
		$display("\nUser JTAG Interface module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        cmd_in = 4'd0;
        use_relu_in = 1'b0;
        use_stepping_in = 1'b0;
        mat_sel = 1'b0;
        address = 0;
        din16 = 0;
        perf_sel = 1'b0;
        confirm = 1'b0;
    end


    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        cmd_reg = uut.cmd_reg;
        confirm_d = uut.confirm_d;
        confirm_fall = uut.confirm_fall;
        state = uut.state;
        next_state = uut.next_state;
        use_relu_reg = uut.use_relu_reg;
        start_exec_reg = uut.start_exec_reg;
        matrices_loaded_reg = uut.matrices_loaded_reg;
        stop_exec_reg = uut.stop_exec_reg;
        use_stepping_reg = uut.use_stepping_reg;
    end


        // Variables de referencia

    initial	begin

        repeat (1) @(posedge clk);
        
        rst = 1;

        @(posedge clk);

        rst = 0;

        /* ReLU */
        @(posedge clk);

        cmd_in = 4'd1;
        use_relu_in = 1'b1;

        @(posedge clk);

        confirm = 1'b1;

        @(posedge clk);

        confirm = 1'b0;

        @(posedge clk);
        @(posedge clk);

        use_relu_in = 1'b0;

        /* Stepping */
        @(posedge clk);

        cmd_in = 4'd2;
        use_stepping_in = 1'b1;

        @(posedge clk);

        confirm = 1'b1;

        @(posedge clk);

        confirm = 1'b0;

        @(posedge clk);
        @(posedge clk);

        use_stepping_in = 1'b0;

        /* wRITE */
        @(posedge clk);

        cmd_in = 4'd3;

        @(posedge clk);

        confirm = 1'b1;

        @(posedge clk);

        confirm = 1'b0;

        @(posedge clk);
        @(posedge clk);

        /* Start */
        @(posedge clk);

        cmd_in = 4'd4;

        @(posedge clk);

        confirm = 1'b1;

        @(posedge clk);

        confirm = 1'b0;

        @(posedge clk);
        @(posedge clk);

    // Done

    end

    initial
	#2500 $finish;  

endmodule
	 