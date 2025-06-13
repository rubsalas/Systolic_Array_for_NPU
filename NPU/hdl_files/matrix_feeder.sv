//------------------------------------------------------------------------------
// matrix_feeder.sv
//   • Recibirá las matrices del RAM que están por operarse.
//   • Maneja la logica para que el systolic array funcione como deba.
//   • Entradas externas            :  matriz A  (a_mat [K-1...0][K-1...0])
//                                     +  matriz B  (n_mat [K-1...0][K-1...0])
//                                     +  valid_in  (pulso K ciclos)
//
//   • Salida                       :  1  columna de A  (a_col0 [K-1...0])
//                                     +  1  fila de B  (b_row0 [K-1...0])
//                                     +  valid_out  (valid_out [K-1...0] segun ciclo)
//
//   Parametrización
//   --------------
//     K : tamaño de la malla           (PEs = K * K)
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module matrix_feeder #(
    parameter int K = 4
)(
    input   logic   clk,
    input   logic   rst,

    // Matrices de entrada
    input   s16_t   a_mat [0:K-1][0:K-1],   // matriz A
    input   s16_t   b_mat [0:K-1][0:K-1],   // matriz B
    input   logic   valid_in,               // habilita stream

    // Bordes para systolic array
    output  s16_t   a_col0 [0:K-1],         // columna de A
    output  s16_t   b_row0 [0:K-1],         // fila de B
    output  logic   valid_out [0:K-1]       // habilita stream
);

    // ancho mínimo del contador (K-1 cabe); si K=1 forzamos 1 bit
    localparam int CNT_W = (K <= 1) ? 1 : $clog2(K*2);
    logic [CNT_W-1:0]  f_cycle;  // cantidad de ciclos consecutivos del feeder

    // Registro del contador
    always_ff @(posedge clk) begin
        if (rst) begin
            f_cycle <= '0;
        end
        else if (valid_in) begin
            f_cycle <= f_cycle + 1'b1;
        end
        else begin
            f_cycle <= '0;        // reset automático al caer valid_in
        end
    end

    int unsigned fc;          // variable procedural (entero)

    always_comb begin

        fc = int'(f_cycle);   // casteo explícito

        if (0 <= fc && fc < K) begin

            for (int j = 0; j < fc && j < K; j = j + 1) begin : FEED_BELOW
                a_col0[j] = a_mat[fc-j-1][j];
                b_row0[j] = b_mat[j][fc-j-1];
                valid_out[j] = 1'b1;
            end
            for (int k = 0; k < K; k = k + 1) begin : FILL_BELOW
                a_col0[fc+k] = 0;
                b_row0[fc+k] = 0;
                valid_out[fc+k] = 1'b0;
            end

        end
        else if (fc == K) begin

            for (int j = 0; j < fc && j < K; j = j + 1) begin : FEED_SAME
                a_col0[j] = a_mat[fc-j-1][j];
                b_row0[j] = b_mat[j][fc-j-1];
                valid_out[j] = 1'b1;
            end

        end
        else if (fc > K) begin

            for (int j = 0; j <= fc-K-1 && j < K; j = j + 1) begin : FILL_OVER
                a_col0[j] = 0;
                b_row0[j] = 0;
                valid_out[j] = 1'b0;
            end
            for (int k = 0; k < K; k = k + 1) begin : FEED_OVER
                a_col0[fc-K+k] = a_mat[K-1-k][fc-K+k];
                b_row0[fc-K+k] = b_mat[fc-K+k][K-1-k];
                valid_out[fc-K+k] = 1'b1;
            end

        end
        else begin

            for (int j = 0; j < K; j = j + 1) begin : FEED_INVALID
                a_col0[j] = -1;
                b_row0[j] = -1;
                valid_out[j] = 1'b0;
            end

        end

    end

endmodule
