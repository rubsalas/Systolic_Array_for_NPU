/*
Test bench for System top module
Date: 22/06/25
NY Approved
*/
/*
add wave *
 
add wave -radix signed /tb_system_top_20x20/memA
add wave -radix signed /tb_system_top_20x20/memB
add wave -radix signed /tb_system_top_20x20/a_mat
add wave -radix signed /tb_system_top_20x20/b_mat
add wave -radix signed /tb_system_top_20x20/c_mat
add wave -radix signed /tb_system_top_20x20/memC
add wave -radix signed /tb_system_top_20x20/pe_mult_count
add wave -radix signed /tb_system_top_20x20/pe_sum_count
add wave -radix signed /tb_system_top_20x20/pe_accum_count
*/
import pkg_systolic::*;

module tb_system_top_20x20;

    timeunit 1ps;
    timeprecision 1ps;

    // Parámetros
    localparam int K        = 20;    // productos por celda
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
		$display("\nSystem Top with 8x8 matrices module testbench:\n");

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
            3,    4,   -8,   -1,    7,    6,    3,    0,    6,    2,    9,   -3,    7,   -5,    0,   -5,   -6,   -1,    8,   -5,
            0,   -6,   -7,    1,    6,    8,   -6,    2,    4,    1,   -3,    8,    6,    5,    7,   -1,   -8,    8,   -9,   -7,
            3,   -9,    6,    1,   -2,    1,   -7,   -3,    9,   -2,   -2,   -5,    8,    5,   -7,   -7,    1,    7,    6,   -6,
            0,    8,    0,   -6,    8,    1,    8,   -3,    8,    9,    0,    5,   -7,    3,    1,    9,   -2,    0,   -4,   -3,
           -4,   -8,   -1,    6,   -7,   -7,   -5,   -5,   -8,   -7,    8,    3,    7,   -1,    7,   -2,   -3,    9,    4,    9,
           -1,    5,    6,    2,   -7,    1,   -6,    6,    9,    1,   -3,   -2,   -9,   -1,   -6,   -2,    2,   -4,    1,    4,
           -8,   -6,   -5,   -2,   -8,    9,    8,   -7,   -9,   -6,   -3,    9,   -6,    3,   -7,    2,   -6,   -8,   -9,   -3,
           -4,   -6,    6,   -3,   -8,   -9,    8,    4,   -6,   -1,   -7,   -2,   -7,    0,    2,    4,   -4,   -8,    7,    5,
           -8,   -6,    3,   -3,   -1,    2,    6,    9,   -4,   -3,   -8,   -4,   -4,    1,    7,   -1,   -6,    5,   -4,   -9,
            6,    4,    9,    7,    0,    2,    3,   -1,   -5,    8,   -9,    5,   -7,    1,   -8,    8,   -1,   -5,   -2,    6,
            2,    0,    2,    9,   -5,    0,    3,    4,   -7,   -9,   -3,    1,   -4,   -2,   -2,    5,    3,    9,    4,   -8,
            3,    9,    4,   -8,   -4,    5,   -7,   -1,   -4,    5,    7,    6,    8,   -9,   -8,    6,    1,    0,    5,   -8,
            4,   -3,    8,   -7,   -5,   -9,    3,    4,    1,   -9,   -3,   -9,   -9,    7,   -6,   -3,   -6,   -3,    0,   -1,
           -4,   -6,    6,    3,   -7,   -9,   -1,    5,   -6,   -1,   -5,    7,    2,   -6,   -5,   -1,   -9,   -8,   -8,   -3,
           -1,    8,    1,    2,    9,   -8,    6,    5,    4,    2,    8,   -4,   -3,    3,    9,    0,   -9,   -5,   -5,   -1,
            1,    1,    2,   -7,    1,   -8,   -8,   -1,   -4,   -5,    9,    0,    2,    3,    8,   -5,    0,   -6,    6,   -2,
           -8,    0,   -4,    7,   -7,    0,    3,    1,    0,    4,   -6,   -6,    8,    6,    6,    1,    1,   -6,    6,   -6,
            6,    4,   -8,    0,    1,   -5,   -4,    9,    3,   -7,   -7,   -7,   -3,   -2,   -8,    3,   -9,   -6,    3,    8,
            7,    0,    5,    6,    9,   -3,    4,   -7,    2,   -2,   -1,    9,   -4,    4,   -3,    2,   -6,   -7,   -9,    7,
            5,   -3,   -6,    6,    3,   -1,   -3,   -8,   -3,   -5,   -6,   -3,    5,    3,    2,    8,   -5,   -6,    6,   -5
        };

        uut.mram.memB = '{
            -5,    9,   -7,   -1,   -6,    6,    5,    6,    3,   -3,   -6,    6,   -9,    3,    4,   -9,    5,   -1,   -2,    9,
            -6,    1,   -9,   -9,   -9,    8,   -9,    3,   -3,    4,   -9,    7,   -2,    5,    6,    8,   -2,    2,   -2,   -2,
             5,    0,   -9,    4,    8,   -6,   -4,    0,   -6,    1,    7,    4,    7,   -3,    0,    0,    9,    6,    7,    3,
             9,   -8,    6,   -2,    3,    4,   -4,    2,    8,    2,   -7,    5,    7,   -6,   -4,    7,    3,    2,    6,   -9,
             6,   -8,    0,    9,    9,    3,   -4,   -4,    7,   -2,   -9,   -3,    8,    8,   -2,    3,    7,    2,    9,    2,
             5,   -1,    8,   -9,    3,    7,   -5,    7,    8,   -3,    4,   -8,    6,    2,    9,    8,   -3,    7,    4,    6,
             2,    4,    2,   -9,    8,    8,    1,    5,   -9,   -2,   -4,    8,    9,   -4,   -7,    8,   -1,   -8,   -7,   -7,
            -9,    5,   -9,   -1,   -2,   -1,   -6,   -4,    2,    0,   -7,   -4,   -4,   -1,    7,   -4,   -1,    0,    5,    1,
             6,    6,   -6,   -9,    0,    3,    1,    4,   -3,   -1,   -6,   -1,    7,   -3,    4,   -9,   -2,   -9,    3,   -5,
            -8,   -4,    5,    7,    4,    8,   -2,    7,    5,   -2,    7,   -9,    3,    9,    1,    4,   -8,    0,   -5,   -3,
            -8,    0,   -7,   -7,    0,    0,   -4,    4,    9,   -1,   -5,   -9,    8,   -8,    9,   -3,    9,    5,   -4,    7,
            -8,    3,   -3,    2,   -6,   -3,    9,    4,    9,   -3,    6,   -6,    3,    0,    7,    6,   -9,    1,    3,    0,
            -9,   -4,   -3,    1,    9,   -5,    1,    4,   -3,   -1,   -6,    3,    8,    2,    8,    6,    8,   -2,   -7,   -8,
            -7,   -5,   -4,   -4,    8,   -3,   -1,    1,    7,   -1,    2,    1,    1,   -6,    0,   -2,    6,   -5,    9,    8,
            -6,    1,   -8,    4,   -7,    3,   -5,   -5,    1,   -6,    9,    3,   -7,    9,    8,   -2,    9,   -7,   -1,    2,
             0,    9,    8,   -6,    5,   -1,   -6,   -8,    0,   -9,   -9,   -7,    4,   -6,   -8,   -3,   -2,    9,    4,   -4,
            -6,    5,   -4,   -2,   -4,   -6,    4,    3,    8,    0,    8,   -1,    6,    1,   -6,   -3,    1,   -8,   -9,   -9,
             0,    1,    5,    3,    1,    3,   -7,   -7,    1,    5,   -6,   -1,   -3,    8,    6,    2,   -1,   -4,    8,   -3,
             0,   -3,   -2,    2,   -7,   -1,   -7,    5,   -7,    9,    1,   -2,    3,    0,   -8,    1,   -4,    1,    9,    0,
            -2,    1,   -6,    8,    9,   -7,   -2,   -2,   -9,   -2,    3,   -7,   -1,    8,   -7,   -7,   -9,   -9,    0,    2
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

        /*
        // RESPUESTA DE AxB=C
        uut.mram.memC = '{
            -20, -100,  -25, -154,  -70,  269, -122,  221,   37,   69, -295,  -46,  159,   63,  242,  126,   84,   46,  -43,   31,
            -37, -103,  165,   52,   63,  125,   43,  -88,  364, -151,  -64, -119,  -57,  143,  451,  105,   85,   12,  197,   86,
            151, -110,    9,   33,  104, -130,   63,  103,  -10,  183,   -3,   74,  104,  -98,   70, -115,  177,  -51,  179,   -3,
            -16,  129,   32, -162,   69,  276,  -67,   32,   62, -169, -117,  -96,  149,   67,    9,   70, -125,    8,   40,   -8,
           -103, -128,  -22,  247,   16, -283,  -15, -161,  -61,   74,  104,  -38,  -84,    3,   22,  -41,  112,  -79,   22,  -10,
            110,  109, -151, -104, -129,  -42,  -45,   57,  -97,   99,   63,  -35,  -53,  -90,  -55, -177, -204,    6,   98,   14,
            172,   -7,  410, -206,   92,  -26,  290,   36,   55, -127,  230,  -37,   23, -300, -113,  250, -237,  182, -111,   82,
             55,   91,  -27,  128,   29, -172,   29, -123, -425,    8,  231,   97, -138, -143, -422, -112, -144,  -42,    7,   -3,
            136,  -16,  144,   26,   50,   57,  -89, -242,  -94,  -12,   82,  122, -145,  -16,   59,  102,   83,   14,  140,    5,
            115,   49,  124,   50,  163,   66,    6,   74,  -19,  -81,   44,   -1,   55,  -12, -282,  102, -244,  174,  112,  -10,
            127,   88,  156, -134, -156,   21,  -88, -116,   43,  113, -149,  178,  -56, -179,  -96,  118,   41,  136,  170, -121,
           -244,  109,  -11, -115, -207,   14,  -42,  179,   71,   47,  -67, -169,   91,   -3,  249,  158,  -70,  391, -132,   16,
            150,  119, -182,  -43,   22, -133,   68, -120, -337,  100,  -23,  255, -238, -253, -204, -306,  114,  -39,  113,  238,
             49,  -15,   52,  160,   38, -187,  240,  -89, -127,  -28,   90,  102, -102, -200,  -35,   56,  -64,  176,  -81,  -62,
            -55,  -58, -265,  -57,   66,  198, -192,  -83,  -22,  -92, -264,  111,   21,   -9,  120,  -21,  254,  -35,   30,   83,
           -244,  -61, -363,  134, -222, -194,   13,  -29,    6,   52,  137,   31, -144,  -12,  123, -169,  285,   18,  -36,  241,
            -42, -161,  113, -109,   25,   27,  -83,   72,  -68,   35,   78,  142,   86, -106,  -96,  172,   49,  -79,  -70, -246,
            111,   98,  -61,   -9,  -69,  -12,  -39, -124, -279,   57, -372,   63, -282,  -26, -189, -248, -184,   10,  120,   83,
            166,  -18,  -52,   58,  242,   16,  176,   30,   66, -175,  -83,   71,  111,  -66, -113,  -13,   30,   17,  102,  117,
            152, -103,  213,    2,    3,   17,   28,  -36,    0,  -48, -146,  144,  -37,  -95, -191,   29,  131,  130,   98,  -11
        };
        */

    end
	 
	initial
	#375000 $finish;    

endmodule