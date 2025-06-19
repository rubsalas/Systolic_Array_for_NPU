//==============================================================================
// control_unit.sv   (versión “1-pulso final”)
// -----------------------------------------------------------------------------
// • start (pulso)  → STREAM:      valid_out = 1   DURANTE  K ciclos
// • Fin STREAM                   → DRAIN:        valid_out = 0
// • Pulso único matrix_done en DRAIN → done = 1    UN ciclo
//                                     → regreso a IDLE
//
// Parámetro : K (dimensión matriz = profundidad MAC)
//==============================================================================
`timescale 1ns/1ps

module neural_control_unit #(
    parameter int K = 4
)(
    input  logic clk,
    input  logic rst,          // activo-alto síncrono

    input  logic start,        // pulso: arrancar bloque
    input  logic matrix_done,  // pulso ÚNICO al terminar matriz C

    output logic valid_out,    // -> matrix_feeder.valid_in
    output logic done,         // pulso 1-clk  «C lista para escribir»
    output logic busy          // 1 desde start hasta done
);
    //--------------------------------------------------------------------------
    // 1. Estados y contador STREAM
    //--------------------------------------------------------------------------
    typedef enum logic [1:0] {IDLE, STREAM, DRAIN} st_t;
    st_t st, nxt;

    localparam int CW = (K <= 1) ? 1 : $clog2(K*2);
    logic [CW-1:0] k_cnt;      // cuenta 0 … K-1

    //--------------------------------------------------------------------------
    // 2. Registro de estado
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            st <= IDLE;
        else
            st <= nxt;
    end

    //--------------------------------------------------------------------------
    // 3. Lógica de transición
    //--------------------------------------------------------------------------
    always_comb begin
        nxt = st;
        unique case (st)
            IDLE   : if (start)              nxt = STREAM;
            STREAM : if (k_cnt == (K*2)-1)   nxt = DRAIN;
            DRAIN  : if (matrix_done)        nxt = IDLE;   // pulso final
        endcase
    end

    //--------------------------------------------------------------------------
    // 4. Contador de ciclos STREAM
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            k_cnt <= '0;
        else begin
            if (st == STREAM)
                k_cnt <= k_cnt + 1'b1;
            else
                k_cnt <= '0;
        end
    end

    //--------------------------------------------------------------------------
    // 5. Salidas
    //--------------------------------------------------------------------------
    assign valid_out = (st == STREAM);          // 1 durante K ciclos
    assign done      = (st == DRAIN) && matrix_done; // se reenvía tal cual
    assign busy      = (st != IDLE);            // array ocupado

endmodule
