/*
Test bench for System top module
Date: 22/06/25
Approved
*/
/*
add wave *

add wave -radix signed /tb_system_top/memA
add wave -radix signed /tb_system_top/memB
add wave -radix signed /tb_system_top/a_mat
add wave -radix signed /tb_system_top/b_mat
add wave -radix signed /tb_system_top/c_mat
add wave -radix signed /tb_system_top/memC
add wave -radix signed /tb_system_top/pe_mult_count
add wave -radix signed /tb_system_top/pe_sum_count
add wave -radix signed /tb_system_top/pe_accum_count
*/
import pkg_systolic::*;

module tb_system_top;

    timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 4;    // productos por celda
    localparam int P        = 32;   // cantidad de bits para perf. counters
    localparam int CLK_PER  = 100;  // ns -> 100 MHz
    // localparam int RANGE    = 10;   // rango de valores por usar

    logic clk;
    logic rst;

    logic  [3:0]  cmd_in;
    logic         use_relu_in;
    logic         use_stepping_in;
    // logic         mat_sel_in;
    // logic         address_in;
    // s16_t         din16_in;
    // logic         perf_sel_in;
    logic         confirm_uji;

    //---------------------------------------------------------------------------
    // Instantiate system_top
    //---------------------------------------------------------------------------
    system_top #(
        .K(K),
        .P(P)
    ) uut (
        .clk               (clk),
        .rst               (rst),

        .cmd_in            (cmd_in),
        .use_relu_in       (use_relu_in),
        .use_stepping_in   (use_stepping_in),
        // .mat_sel_in        (mat_sel_in),
        // .address_in        (address_in),
        // .din16_in          (din16_in),
        // .perf_sel_in       (perf_sel_in),
        .confirm_uji       (confirm_uji)
    );

    // Inner wiring
    logic use_relu_fw;      // habilita el uso del relu                 // [y] from CU to SNC (MtxPref) [y]
    logic matrices_loaded_fw;  // MRAM ya cargó matrices A/B		    // [y] from CU to SNC (MtxPref) [y]
	logic prefetch_start;   // pulso para arrancar el prefetch	        // [y] from CU to SNC (MtxPref) [y]

    // inner wiring MRAM165
    s16_t memA [0:K*K-1];
    s16_t memB [0:K*K-1];
    
    // Puertos de 16 bits
    logic re16;             // habilita lectura de A o B                // [y] from SNC (MtxPref) to MRAM [y]
    logic mat_sel;          // 0→A, 1→B                                 // [y] from SNC (MtxPref) to MRAM [y]
    logic [$clog2(K*K)-1:0] addr16; //  dirección 0…K*K–1 para A/B      // [y] from SNC (MtxPref) to MRAM [y]
    s16_t dout16;           // dato leído de A/B                        // [y] from MRAM to SNC (MtxPref) [y]
    logic ready16;          // pulso 1-clk cuando termina we16 o re16   // [y] from MRAM to SNC (MtxPref) [y]
    logic stall16;          // 1 mientras ready16=0 (back-pressure)     // [y] from MRAM to SNC (MtxPref) [y]
    
    logic start_exec;           // Start command from host          // [y] from UJI to CU [y]

    // SNC matrices
    s16_t a_mat [0:K-1][0:K-1]; // matriz A
    s16_t b_mat [0:K-1][0:K-1]; // matriz B
	
    logic npu_busy;         // NPU esta en media ejecucion			    // [y] from SNC (NPU) to CU [y]
    logic exec_active;          // High during execution            // [y] from CU to UJI [n]
    logic npu_done;         // NPU calculo matriz resultante 			// [y] from SNC (NPU) to CU [y]
    logic exec_done;            // High when cycle completes        // [y] from CU to UJI [n]

    // SNC matrix C
    s32_t c_mat [0:K-1][0:K-1]; // matriz C resultante
    
    logic commit_start;     // pulso para arrancar el commit	        // [y] from CU to SNC (MtxComt) [y]

    // inner wiring MRAM32
    s32_t memC [0:K*K-1];

    // Puertos de 32 bits
    logic we32;             // habilita escritura de C                  // [y] from SNC (MtxComt) to MRAM [y]
    logic [$clog2(K*K)-1:0] addr32; // dirección 0…K*K–1 para C         // [y] from SNC (MtxComt) to MRAM [y]
    s32_t din32;            // dato de 32 bits a escribir en C          // [y] from SNC (MtxComt) to MRAM [y]
    logic ready32;          // pulso 1-clk cuando termina we32 o re32   // [y] from MRAM to SNC (MtxComt) [y]
    logic stall32;          // 1 mientras ready32=0                     // [y] from MRAM to SNC (MtxComt) [y]

	logic result_stored;    // commit terminado					        // [y] from SNC (MtxComt) to CU [y]

    // Memory Access Performance counters
    logic [P-1:0] read16_count;           // lecturas 16-bit completadas        // [y] from MRAM to PM [y]
    logic [P-1:0] write16_count;          // escrituras 16-bit completadas      // [y] from MRAM to PM [y]
    logic [P-1:0] read32_count;           // lecturas 32-bit completadas        // [y] from MRAM to PM [y]
    logic [P-1:0] write32_count;          // escrituras 32-bit completadas      // [y] from MRAM to PM [y]
    logic [P-1:0] bits_read_16_count;     // bits leídos (16 por lectura)       // [y] from MRAM to PM [y]
    logic [P-1:0] bits_written_16_count;  // bits escritos (16 por escritura)   // [y] from MRAM to PM [y]
    logic [P-1:0] bits_read_32_count;     // bits leídos (32 por lectura)       // [y] from MRAM to PM [y]
    logic [P-1:0] bits_written_32_count;  // bits escritos (32 por escritura)   // [y] from MRAM to PM [y]

    //––– Arithmetic Op. Performance Counters (via NPU) –––
    // Performance counters por PE
    logic [P-1:0] pe_mult_count [0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    logic [P-1:0] pe_sum_count  [0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    logic [P-1:0] pe_accum_count[0:K-1][0:K-1];                         // [y] from SNC to PM [y]
    // Performance counters totales agregados
    logic [P-1:0] total_mult_count;                                     // [y] from SNC to PM [y]
    logic [P-1:0] total_sum_count;                                      // [y] from SNC to PM [y]
    logic [P-1:0] total_accum_count;                                    // [y] from SNC to PM [y]

    // Initialize inputs
    initial begin
		$display("\nSystem Top module testbench:\n");

		clk = 1'b1;
        rst = 1'b0;

        cmd_in = 1'b0;
        use_relu_in = 1'b0;
        use_stepping_in = 1'b0;
        // mat_sel_in = 1'b0;
        // address_in = 1'b0;
        // din16_in = 1'b0;
        // perf_sel_in = 1'b0;
        confirm_uji = 1'b0;
    end


    // Clock
    always #(CLK_PER/2) begin
        clk = ~clk;

        use_relu_fw = uut.use_relu_fw;
        matrices_loaded_fw = uut.matrices_loaded_fw;
        prefetch_start = uut.prefetch_start;

        memA = uut.mram.memA;
        memB = uut.mram.memB;
        
        re16 = uut.re16;
        mat_sel = uut.mat_sel;
        addr16 = uut.addr16;
        dout16 = uut.dout16;
        ready16 = uut.ready16;
        stall16 = uut.stall16;

        start_exec = uut.start_exec;

        a_mat = uut.SNC.a_mat;
        b_mat = uut.SNC.b_mat;

        npu_busy = uut.npu_busy;
        exec_active = uut.exec_active;
        npu_done = uut.npu_done;
        exec_done = uut.exec_done;

        c_mat = uut.SNC.c_mat;
        
        commit_start = uut.commit_start;

        memC = uut.mram.memC;

        we32 = uut.we32;
        addr32 = uut.addr32;
        din32 = uut.din32;
        ready32 = uut.ready32;
        stall32 = uut.stall32;

        result_stored = uut.result_stored;

        pe_mult_count = uut.pe_mult_count;
        pe_sum_count = uut.pe_sum_count;
        pe_accum_count = uut.pe_accum_count;
        total_mult_count = uut.total_mult_count;
        total_sum_count = uut.total_sum_count;
        total_accum_count = uut.total_accum_count;

        read16_count = uut.read16_count;
        write16_count = uut.write16_count;
        read32_count = uut.read32_count;
        write32_count = uut.write32_count;
        bits_read_16_count = uut.bits_read_16_count;
        bits_written_16_count = uut.bits_written_16_count;
        bits_read_32_count = uut.bits_read_32_count;
        bits_written_32_count = uut.bits_written_32_count;
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

        confirm_uji = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b0;

        @(posedge clk);
        @(posedge clk);

        use_relu_in = 1'b0;

        /* Stepping */
        @(posedge clk);

        cmd_in = 4'd2;
        use_stepping_in = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b0;

        @(posedge clk);
        @(posedge clk);

        use_stepping_in = 1'b0;

        /* Adding matrices for operation */

        uut.mram.memA = '{
            2,  -1,  0,  6,
            -7,  5,  6,  -4,
            8,  1,  -2,  3,
            0,  7,  -9,  1
        };
        uut.mram.memB = '{
            5,  0,  2,  -3,
            -4,  6,  7,  1,
            8,  -9,  0,  9,
            1,  3,  -5,  2
        };

        /* Write */
        @(posedge clk);

        cmd_in = 4'd3;

        @(posedge clk);

        confirm_uji = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b0;

        @(posedge clk);
        @(posedge clk);

        /* Start */
        @(posedge clk);

        cmd_in = 4'd4;

        @(posedge clk);

        confirm_uji = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b0;

        @(posedge clk);
        @(posedge clk);


        // --- espera a que se haya escrito el resultado en MRAM ---
        wait(result_stored);

        /* Done */
        @(posedge clk);

        cmd_in = 4'd9;

        @(posedge clk);

        confirm_uji = 1'b1;

        @(posedge clk);

        confirm_uji = 1'b0;

        @(posedge clk);
        @(posedge clk);
        
	 
        // Done

    end

    initial
	#20000 $finish;    

endmodule
