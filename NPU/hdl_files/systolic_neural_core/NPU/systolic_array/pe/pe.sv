//------------------------------------------------------------------------------
// pe.sv  –  Processing Element (dataflow: Output-Stationary) con Performance Counters
//
//   • Registra A y B un ciclo, los re-envía y los multiplica.
//   • El producto se acumula durante K ciclos; al siguiente ciclo se aplica
//     opcionalmente ReLU y se emite c_out con c_valid=1.
//   • Un ciclo después el ACC se limpia automáticamente.
//   • Performance counters:
//       - perf_mult_count  : número de multiplicaciones realizadas.
//       - perf_sum_count   : número de sumas realizadas en el acumulador.
//       - perf_accum_count : número de bloques acumulados (resultados finales).
//
//   Puertos
//   -------
//     a_in            : operando A que llega de la izquierda.
//     b_in            : operando B que llega desde arriba.
//     valid_in        : pulso de validez asociado a a_in, b_in.
//     use_relu        : habilita la aplicación de ReLU (1) o bypass (0).
//     a_out, b_out    : operandos reenviados (shift) a derecha / abajo.
//     valid_out       : validez propagada.
//     c_out           : resultado (ReLU o acumulador) de 32 bits.
//     c_valid         : pulso 1-clk, coincide con ciclo en que c_out es válido.
//     perf_mult_count : contador de multiplicaciones.
//     perf_sum_count  : contador de sumas en el acumulador.
//     perf_accum_count: contador de resultados acumulados.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module pe #(
    parameter int K = 4,            // profundidad de la multiplicación-suma
    parameter int P = 32            // cantidad de bits para perf. counters
)(
    input  logic  clk,
    input  logic  rst,

    // flujo A/B
    input  s16_t  a_in,
    input  s16_t  b_in,
    input  logic  valid_in,

    // ReLU control bit
    input  logic  use_relu,         //  1 = aplicar ReLU, 0 = bypass

    output s16_t  a_out,
    output s16_t  b_out,
    output logic  valid_out,

    // resultado
    output s32_t  c_out,
    output logic  c_valid,

    // Performance counters
    output logic [P-1:0] perf_mult_count,  // número de multiplicaciones realizadas
    output logic [P-1:0] perf_sum_count,   // número de sumas en el acumulador
    output logic [P-1:0] perf_accum_count  // número de bloques acumulados (resultados)
);

    //--------------------------------------------------------------------------
    // 0. Contadores internos
    //--------------------------------------------------------------------------
    logic [P-1:0] mult_count_reg;   // incrementa en cada ciclo donde v_reg=1 (una multiplicación válida).
    logic [P-1:0] sum_count_reg;    // incrementa también con v_reg (una suma al acumulador por entrada válida).
    logic [P-1:0] accum_count_reg;  // incrementa con last_prod (cuando acaba un bloque de K sumas y hay un resultado final).

    //--------------------------------------------------------------------------
    // 1. Registros de paso para A, B y validez
    //--------------------------------------------------------------------------
    s16_t a_reg, b_reg;
    logic v_reg;

    logic last_prod;

    always_ff @(posedge clk) begin
        if (rst) begin
            a_reg <= '0;
            b_reg <= '0;
            v_reg <= 1'b0;
            // reset counters
            mult_count_reg <= 0;
            sum_count_reg  <= 0;
            accum_count_reg<= 0;
        end
        else begin
            a_reg <= a_in;
            b_reg <= b_in;
            v_reg <= valid_in;

            // Increment counters based on events
            if (v_reg) begin
                mult_count_reg <= mult_count_reg + 1;
                sum_count_reg  <= sum_count_reg  + 1;
            end
            if (last_prod) begin
                accum_count_reg <= accum_count_reg + 1;
            end
        end
    end

    assign perf_mult_count  = mult_count_reg;
    assign perf_sum_count   = sum_count_reg;
    assign perf_accum_count = accum_count_reg;

    assign a_out     = a_reg;
    assign b_out     = b_reg;
    assign valid_out = v_reg;

    //--------------------------------------------------------------------------
    // 2. Multiplicador (combinacional, 16×16 → 32)
    //--------------------------------------------------------------------------
    s32_t prod;

    multiplier mul (
        .a_in  (a_reg),
        .b_in  (b_reg),
        .p_out (prod)
    );

    //--------------------------------------------------------------------------
    // 3. Acumulador (suma de K productos)
    //--------------------------------------------------------------------------
    s32_t acc_val;

    accumulator #(.K(K)) acc (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (v_reg),     // ya alineado un ciclo
        .prod_in   (prod),
        .acc_out   (acc_val),
        .last_prod (last_prod)  // pulso un ciclo cuando acc_val es final
    );

    //--------------------------------------------------------------------------
    // 4. ReLU combinacional
    //--------------------------------------------------------------------------
    s32_t relu_out;
    logic relu_valid;

    relu u_relu (
        .x_in  (acc_val),       // dato del acumulador
        .v_in  (last_prod),     // pulso 1-clk → relu_valid
        .y_out (relu_out),
        .v_out (relu_valid)
    );

    //----------------------------------------------------------------------
    // 4.5 Señal unificada de dato y validez resultante
    //----------------------------------------------------------------------
    logic result_valid;
    // Si use_relu=1, esperamos relu_valid; si =0, last_prod
    assign result_valid = use_relu ? relu_valid : last_prod;

    // Cable para el dato multiplexado
    s32_t result_data;

    // Instancia del MUX parametrizable (32 bits)
    mux_2NtoN #(.N(ACC_W)) mux_result (
        .I0   (acc_val),       // bypass: acumulador directo
        .I1   (relu_out),      // ReLU
        .rst  (rst),           // si reset, sale 0
        .S    (use_relu),      // select: 0=bypass, 1=ReLU
        .en   (result_valid),  // habilita sólo cuando hay dato válido
        .O    (result_data)    // salida multiplexada
    );

    // -------------------------------------------------------------------------
    // 5. Registro “hold” – mantiene el resultado final hasta el START siguiente
    // -------------------------------------------------------------------------
    s32_t c_hold;
    logic have_res;

    // Detectar flanco 0→1 de valid_in (primer ciclo del nuevo bloque)
    logic start_next;
    assign start_next = valid_in & ~v_reg;   // v_reg = valid_in retardado 1 ciclo

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_hold   <= '0;
            have_res <= 1'b0;
        end
        else if (result_valid) begin
            // captura el dato multiplexado
            c_hold   <= result_data;
            have_res <= 1'b1;
        end
        else if (start_next) begin
            c_hold   <= '0;
            have_res <= 1'b0;
        end
    end

    // Salidas estables
    assign c_out   = c_hold;      // permanece fijo entre bloques
    assign c_valid = have_res;    // ‘1’ cuando c_out es válido

endmodule
