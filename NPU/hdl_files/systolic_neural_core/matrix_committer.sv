//==============================================================================
// matrix_committer.sv
//------------------------------------------------------------------------------
// Módulo: matrix_committer
//   • Escribe la matriz de resultados C (K×K palabras de 32 bits) de vuelta
//     en la MRAM usando el puerto de 32 bits.
//   • Entrada 'data_ready'=1 indica que c_mat ya está válido en el NPU.
//   • Entrada 'commit_start' (pulso 1-ciclo) inicia el commit en MRAM.
//   • Al completar todas las escrituras, emite 'ready_to_ram' (pulso 1-ciclo)
//     y permanece en DONE hasta que 'commit_start' regrese a 0.
//------------------------------------------------------------------------------ 
`timescale 1ns/1ps
import pkg_systolic::*;

module matrix_committer #(
    parameter int K = 4   // dimensión de la matriz C (K×K)
)(
    input  logic        clk,                // reloj síncrono
    input  logic        rst,                // reset síncrono activo-alto

    // Control signals
    input  logic        data_ready,         // 1 = c_mat válido (NPU) y listo para escribir
    input  logic        commit_start,       // pulso 1-ciclo (Contorl Unit) para disparar commit

    // Entradas desde NPU
    input  s32_t        c_mat [0:K-1][0:K-1],

    // Interfaz MRAM 32-bit (solo escritura)
    input  logic        ready32,            // MRAM listo (1 ciclo tras we32)
    input  logic        stall32,            // MRAM ocupado
    
    output logic        we32,               // habilita escritura
    output logic [$clog2(K*K)-1:0] addr32,  // dirección fila-major 0…K*K-1
    output s32_t        din32,              // dato a escribir en MRAM

    // Salida de control
    output logic        ready_to_ram        // pulso 1-ciclo: commit completado
);

    // Número total de palabras y ancho de índice
    localparam int NUM_ELEM = K * K;
    localparam int IDX_W    = (NUM_ELEM <= 1) ? 1 : $clog2(NUM_ELEM);

    // FSM States
    typedef enum logic [1:0] {IDLE, WRITE_C, DONE} st_t;
    st_t state, next_state;

    // Índice lineal 0..NUM_ELEM-1
    logic [IDX_W-1:0] idx;
    // Señal de handshake interna: esperamos ready32 tras we32
    logic request_pending;

    //--------------------------------------------------------------------------
    // 1) Registro de estado (solo aquí se actualiza `state`)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    //--------------------------------------------------------------------------
    // 2) Lógica de transición (combinacional)
    //--------------------------------------------------------------------------
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                // arranca solo si la matriz está lista y hay pulso de commit_start
                if (data_ready && commit_start)
                    next_state = WRITE_C;

            WRITE_C:
                // tras escribir el último elemento
                if (request_pending && ready32 && (idx == NUM_ELEM-1))
                    next_state = DONE;

            DONE:
                // espera a que commit_start regrese a 0 para reiniciar
                if (!commit_start)
                    next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // 3) Datapath: control de we32, addr32, din32, idx, request_pending,
    //    y generación de ready_to_ram
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            idx             <= '0;
            request_pending <= 1'b0;
            we32            <= 1'b0;
            addr32          <= '0;
            din32           <= '0;
            ready_to_ram    <= 1'b0;
        end else begin
            // defaults cada ciclo
            we32         <= 1'b0;
            ready_to_ram <= 1'b0;

            case (state)
                IDLE: begin
                    // limpiar antes de arrancar
                    idx             <= '0;
                    request_pending <= 1'b0;
                end

                WRITE_C: begin
                    // configurar dirección y dato
                    addr32 <= idx;
                    din32  <= c_mat[idx / K][idx % K];
                    // lanzar escritura si MRAM libre
                    if (!request_pending && stall32) begin
                        we32            <= 1'b1;
                        request_pending <= 1'b1;
                    end
                    // cuando MRAM confirma escritura, avanzar índice
                    else if (request_pending && ready32) begin
                        request_pending <= 1'b0;
                        idx <= (idx == NUM_ELEM-1) ? '0 : idx + 1;
                    end
                end

                DONE: begin
                    // commit completo -> pulso de un ciclo
                    ready_to_ram <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
