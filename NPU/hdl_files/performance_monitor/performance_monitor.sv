//------------------------------------------------------------------------------
// perf_monitor.sv  –  Congela y expone performance counters tras cada iteración
//
//   • Escucha la señal commit_done (pulso 1-clk al finalizar la escritura C).
//   • Congela (“snapshot”) contadores de:
//       – MRAM: lecturas/escrituras 16/32 bit y bits transferidos.
//       – NPU totales: total_mult_count, total_sum_count, total_accum_count.
//       – PEs individuales: pe_mult_count[i][j], pe_sum_count[i][j], pe_accum_count[i][j].
//   • Genera counters_ready (pulso 1-clk) indicando que el snapshot es válido.
//
//   Parámetros:
//     K : tamaño de la malla (número de PEs por fila/columna).
//     P : ancho en bits de los performance counters.
//
//   Puertos:
//     clk, rst         : reloj y reset síncrono.
//     commit_done      : pulso al completar la escritura de C en MRAM.
//     // Contadores de MRAM
//       read16_count, write16_count, read32_count, write32_count,
//       bits_read_16_count, bits_written_16_count,
//       bits_read_32_count, bits_written_32_count
//     // Contadores agregados del NPU
//       total_mult_count, total_sum_count, total_accum_count
//     // Contadores individuales de cada PE
//       pe_mult_count  [0:K-1][0:K-1],
//       pe_sum_count   [0:K-1][0:K-1],
//       pe_accum_count [0:K-1][0:K-1]
//     // Salidas “snapshot”
//       snap_...        : mismo ancho y tamaño que las señales de entrada.
//     counters_ready       : pulso 1-clk tras capturar snapshot.
//------------------------------------------------------------------------------
`timescale 1ns/1ps

module performance_monitor #(
    parameter int K = 4,
    parameter int P = 32
)(
    input  logic               clk,
    input  logic               rst,
    input  logic               commit_done,

    // Memory Access Performance counters
    input  logic [P-1:0]       read16_count,
    input  logic [P-1:0]       write16_count,
    input  logic [P-1:0]       read32_count,
    input  logic [P-1:0]       write32_count,
    input  logic [P-1:0]       bits_read_16_count,
    input  logic [P-1:0]       bits_written_16_count,
    input  logic [P-1:0]       bits_read_32_count,
    input  logic [P-1:0]       bits_written_32_count,

    // Arithmetic Op. Performance counters
    input  logic [P-1:0]       pe_mult_count  [0:K-1][0:K-1],
    input  logic [P-1:0]       pe_sum_count   [0:K-1][0:K-1],
    input  logic [P-1:0]       pe_accum_count [0:K-1][0:K-1],
    input  logic [P-1:0]       total_mult_count,
    input  logic [P-1:0]       total_sum_count,
    input  logic [P-1:0]       total_accum_count,

    // Snapshots de salida
    output logic [P-1:0]       snap_read16_count,
    output logic [P-1:0]       snap_write16_count,
    output logic [P-1:0]       snap_read32_count,
    output logic [P-1:0]       snap_write32_count,
    output logic [P-1:0]       snap_bits_read_16_count,
    output logic [P-1:0]       snap_bits_written_16_count,
    output logic [P-1:0]       snap_bits_read_32_count,
    output logic [P-1:0]       snap_bits_written_32_count,

    output logic [P-1:0]       snap_pe_mult_count  [0:K-1][0:K-1],
    output logic [P-1:0]       snap_pe_sum_count   [0:K-1][0:K-1],
    output logic [P-1:0]       snap_pe_accum_count [0:K-1][0:K-1],
    output logic [P-1:0]       snap_total_mult_count,
    output logic [P-1:0]       snap_total_sum_count,
    output logic [P-1:0]       snap_total_accum_count,

    output logic               counters_ready
);

    integer i, j;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counters_ready <= 1'b0;
            snap_read16_count           <= '0;
            snap_write16_count          <= '0;
            snap_read32_count           <= '0;
            snap_write32_count          <= '0;
            snap_bits_read_16_count     <= '0;
            snap_bits_written_16_count  <= '0;
            snap_bits_read_32_count     <= '0;
            snap_bits_written_32_count  <= '0;
            snap_total_mult_count       <= '0;
            snap_total_sum_count        <= '0;
            snap_total_accum_count      <= '0;
            for (i = 0; i < K; i++) begin
                for (j = 0; j < K; j++) begin
                    snap_pe_mult_count[i][j]  <= '0;
                    snap_pe_sum_count[i][j]   <= '0;
                    snap_pe_accum_count[i][j] <= '0;
                end
            end
        end
        else if (commit_done) begin
            // Congela counters de MRAM
            snap_read16_count          <= read16_count;
            snap_write16_count         <= write16_count;
            snap_read32_count          <= read32_count;
            snap_write32_count         <= write32_count;
            snap_bits_read_16_count    <= bits_read_16_count;
            snap_bits_written_16_count <= bits_written_16_count;
            snap_bits_read_32_count    <= bits_read_32_count;
            snap_bits_written_32_count <= bits_written_32_count;

            // Congela counters agregados NPU
            snap_total_mult_count      <= total_mult_count;
            snap_total_sum_count       <= total_sum_count;
            snap_total_accum_count     <= total_accum_count;

            // Congela counters individuales de PEs
            for (i = 0; i < K; i++) begin
                for (j = 0; j < K; j++) begin
                    snap_pe_mult_count[i][j]  <= pe_mult_count[i][j];
                    snap_pe_sum_count[i][j]   <= pe_sum_count[i][j];
                    snap_pe_accum_count[i][j] <= pe_accum_count[i][j];
                end
            end

            counters_ready <= 1'b1;
        end
        else begin
            counters_ready <= 1'b0;
        end
    end

endmodule
