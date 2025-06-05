`timescale 1ns/1ps
import pkg_systolic::*;

//------------------------------------------------------------------------------
// pe.sv  –  Processing Element (dataflow: Output-Stationary)
//
//   • Registra A y B un ciclo, los re-envía y los multiplica.
//   • El producto se acumula durante K ciclos; al siguiente ciclo se pasa
//     por ReLU y se emite c_out con c_valid=1.
//   • Un ciclo después el ACC se limpia automáticamente.
//
//   Puertos
//   -------
//     a_in , b_in   : operandos que llegan de la izquierda / arriba
//     valid_in      : pulso de validez asociado a a_in, b_in
//     a_out, b_out  : mismos operandos reenviados (shift) a derecha / abajo
//     valid_out     : validez propagada
//     c_out         : resultado ReLU (32 bit)
//     c_valid       : pulso 1-clk, coincide con ciclo en que c_out es válido
//------------------------------------------------------------------------------
module pe #(
    parameter int K = 4            // profundidad de la multiplicación-suma
)(
    input  logic  clk,
    input  logic  rst,             // activo-alto (igual que accumulator)

    // flujo A/B
    input  s16_t  a_in,
    input  s16_t  b_in,
    input  logic  valid_in,

    output s16_t  a_out,
    output s16_t  b_out,
    output logic  valid_out,

    // resultado
    output s32_t  c_out,
    output logic  c_valid
);

    //--------------------------------------------------------------------------
    // 1. Registradores de paso (shift) para A, B y validez
    //--------------------------------------------------------------------------
    s16_t a_reg, b_reg;
    logic v_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            a_reg <= '0;
            b_reg <= '0;
            v_reg <= 1'b0;
        end
        else begin
            a_reg <= a_in;
            b_reg <= b_in;
            v_reg <= valid_in;
        end
    end

    assign a_out     = a_reg;
    assign b_out     = b_reg;
    assign valid_out = v_reg;

    //--------------------------------------------------------------------------
    // 2. Multiplicador (combinacional, 16×16 → 32)
    //--------------------------------------------------------------------------
    s32_t prod;

    multiplier u_mul (
        .a_in  (a_reg),
        .b_in  (b_reg),
        .p_out (prod)
    );

    //--------------------------------------------------------------------------
    // 3. Acumulador (suma de K productos)
    //--------------------------------------------------------------------------
    s32_t acc_val;
    logic last_prod;

    accumulator #(.K(K)) u_acc (
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
    relu u_relu (
        .x_in  (acc_val),
        .v_in  (last_prod),
        .y_out (c_out),
        .v_out (c_valid)
    );

endmodule
