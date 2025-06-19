//==============================================================================
// matrix_prefetcher.sv
//------------------------------------------------------------------------------
// Módulo: matrix_prefetcher
//   • Prefetch de matrices A y B desde la MRAM (K×K palabras de 16 bits).
//   • Usa el puerto de 16 bits de la MRAM (re16, mat_sel, addr16).
//   • Almacena los datos en arrays a_mat[][] y b_mat[][].
//   • Entrada 'matrices_ready'=1 indica que A y B ya están escritas en MRAM.
//   • Entrada 'prefetch_start' (pulso 1-ciclo) dispara la lectura de A y B.
//   • Una vez leídas ambas matrices, emite 'ready_to_npu' (pulso 1-ciclo)
//     y permanece en DONE hasta que 'prefetch_start' vuelva a 0.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module matrix_prefetcher #(
    parameter int K = 4   // dimensión de las matrices (K×K)
)(
    input  logic        clk,                // reloj síncrono
    input  logic        rst,                // reset síncrono activo-alto

    // Control signals
    input  logic        matrices_ready,     // 1 = A y B presentes en MRAM (Matrix Load)
    input  logic        prefetch_start,     // pulso 1-ciclo (Control Unit) para lanzar prefetch

    // Interfaz MRAM 16-bit (solo lectura)
    input  s16_t        dout16,             // dato leído de MRAM
    input  logic        ready16,            // MRAM listo (1 ciclo)
    input  logic        stall16,            // MRAM ocupado

    output logic        re16,               // habilita lectura unitaria
    output logic        mat_sel,            // 0→leer A, 1→leer B
    output logic [$clog2(K*K)-1:0] addr16,  // dirección fila-major 0…K*K-1

    // Salidas al NPU
    output s16_t        a_mat [0:K-1][0:K-1],
    output s16_t        b_mat [0:K-1][0:K-1],

    // Salida de control
    output logic        ready_to_npu        // pulso 1-ciclo: datos listos
);

    // cálculo de constantes
    localparam int NUM_ELEM = K * K;
    localparam int IDX_W    = (NUM_ELEM <= 1) ? 1 : $clog2(NUM_ELEM);

    // FSM states
    typedef enum logic [1:0] {IDLE, READ_A, READ_B, DONE} st_t;
    st_t state, next_state;

    // índice lineal, 0..NUM_ELEM-1
    logic [IDX_W-1:0] idx;
    // petición pendiente de MRAM
    logic request_pending;

    //----------------------------------------------------------------------
    // 1) Registro de estado
    //----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    //----------------------------------------------------------------------
    // 2) Lógica de transición
    //----------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                // arranca solo con matrices_ready y prefetch_start=1
                if (matrices_ready && prefetch_start)
                    next_state = READ_A;
            end

            READ_A: begin
                // tras leer último elemento de A
                if (request_pending && ready16 && (idx == NUM_ELEM-1))
                    next_state = READ_B;
            end

            READ_B: begin
                if (request_pending && ready16 && (idx == NUM_ELEM-1))
                    next_state = DONE;
            end

            DONE: begin
                // espera a que 'prefetch_start' regrese a 0 para reiniciar
                if (!prefetch_start)
                    next_state = IDLE;
            end
        endcase
    end

    //----------------------------------------------------------------------
    // 3) Datapath: control de MRAM y almacenamiento
    //----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            idx              <= '0;
            request_pending  <= 1'b0;
            re16             <= 1'b0;
            mat_sel          <= 1'b0;
            addr16           <= '0;
            ready_to_npu     <= 1'b0;
        end else begin
            // defaults cada ciclo
            re16         <= 1'b0;
            ready_to_npu <= 1'b0;

            case (state)
                IDLE: begin
                    // limpiar antes de arranque
                    idx             <= '0;
                    request_pending <= 1'b0;
                end

                READ_A: begin
                    mat_sel <= 1'b0;
                    addr16  <= idx;
                    if (!request_pending && stall16) begin
                        re16             <= 1'b1;
                        request_pending  <= 1'b1;
                    end else if (request_pending && ready16) begin
                        // almacenar A
                        a_mat[idx / K][idx % K] <= dout16;
                        request_pending          <= 1'b0;
                        // avanzar o resetear índice
                        idx <= (idx == NUM_ELEM-1) ? '0 : idx + 1;
                    end
                end

                READ_B: begin
                    mat_sel <= 1'b1;
                    addr16  <= idx;
                    if (!request_pending && stall16) begin
                        re16             <= 1'b1;
                        request_pending  <= 1'b1;
                    end else if (request_pending && ready16) begin
                        // almacenar B
                        b_mat[idx / K][idx % K] <= dout16;
                        request_pending          <= 1'b0;
                        idx <= (idx == NUM_ELEM-1) ? '0 : idx + 1;
                    end
                end

                DONE: begin
                    // un pulso para avisar que ambos prefetch completos
                    ready_to_npu <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
