//------------------------------------------------------------------------------
// MRAM.sv  –  Memoria MRAM dual-port para matrices A/B (16 bit) y C (32 bit)
//
//   • Bancos internos:
//       – memA, memB: K×K palabras de 16 bit para matrices A y B.
//       – memC       : K×K palabras de 32 bit para matriz C.
//
//   • Puertos de acceso (handshake “ready/stall”):
//       – Puerto A/B (16 bit):
//           • we16     : habilita escritura de din16 en memA/B[addr16].
//           • re16     : habilita lectura de memA/B[addr16] → dout16.
//           • ready16  : pulso 1 clk cuando termina we16 o re16.
//           • stall16  : 1 mientras ready16=0.
//       – Puerto C (32 bit):
//           • we32     : habilita escritura de din32 en memC[addr32].
//           • re32     : habilita lectura de memC[addr32] → dout32.
//           • ready32  : pulso 1 clk cuando termina we32 o re32.
//           • stall32  : 1 mientras ready32=0.
//
//   • Performance counters (anchura P bits):
//       – read16_count          : número de lecturas 16 bit completadas.
//       – write16_count         : número de escrituras 16 bit completadas.
//       – read32_count          : número de lecturas 32 bit completadas.
//       – write32_count         : número de escrituras 32 bit completadas.
//       – bits_read_16_count    : total de bits leídos (+=16 por lectura 16 bit).
//       – bits_written_16_count : total de bits escritos (+=16 por escritura 16 bit).
//       – bits_read_32_count    : total de bits leídos (+=32 por lectura 32 bit).
//       – bits_written_32_count : total de bits escritos (+=32 por escritura 32 bit).
//
//   Parámetros:
//     K : dimensión de las matrices (K×K).
//     P : ancho en bits de los contadores de performance.
//
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module MRAM #(
    parameter int K = 4,            // dimensión de matriz (K×K)
    parameter int P = 32            // cantidad de bits para perf. counters
)(
    input  logic        clk,
    input  logic        rst,

    //--------------------------------------------------------------------------
    // Puerto A/B (16 bits): carga y lectura de matrices A y B
    //--------------------------------------------------------------------------
    input  logic        we16,       // write enable: 1 = escribir din16 en la dirección addr16
    input  logic        re16,       // read  enable: 1 = leer de la dirección addr16
    input  logic        mat_sel,    // 0 = banco A, 1 = banco B
    input  logic [$clog2(K*K)-1:0] addr16, // dirección fila-major 0…K*K-1
    input  s16_t        din16,      // datos de entrada para escritura
    output s16_t        dout16,     // datos de salida de lectura
    output logic        ready16,    // 1-clk cuando la operación (we16/re16) finaliza
    output logic        stall16,    // 1 mientras no esté listo (ready16=0)

    //--------------------------------------------------------------------------
    // Puerto C (32 bits): escritura y lectura de la matriz de resultados
    //--------------------------------------------------------------------------
    input  logic        we32,       // write enable para memC
    input  logic        re32,       // read  enable para memC
    input  logic [$clog2(K*K)-1:0] addr32, // dirección 0…K*K-1 para C
    input  s32_t        din32,      // datos a escribir en memC
    output s32_t        dout32,     // datos leídos de memC
    output logic        ready32,    // 1-clk cuando finaliza we32 o re32
    output logic        stall32,    // 1 mientras no esté listo (ready32=0)

    // Performance counters
    output logic [P-1:0]            read16_count,           // lecturas 16-bit completadas
    output logic [P-1:0]            write16_count,          // escrituras 16-bit completadas
    output logic [P-1:0]            read32_count,           // lecturas 32-bit completadas
    output logic [P-1:0]            write32_count,          // escrituras 32-bit completadas
    output logic [P-1:0]            bits_read_16_count,     // bits leídos (16 por lectura)
    output logic [P-1:0]            bits_written_16_count,  // bits escritos (16 por escritura)
    output logic [P-1:0]            bits_read_32_count,     // bits leídos (32 por lectura)
    output logic [P-1:0]            bits_written_32_count   // bits escritos (32 por escritura)
);

    //--------------------------------------------------------------------------
    // Bancos de memoria interna
    //--------------------------------------------------------------------------
    s16_t memA [0:K*K-1];  // Banco A: K*K elementos de 16 bits
    s16_t memB [0:K*K-1];  // Banco B: K*K elementos de 16 bits
    s32_t memC [0:K*K-1];  // Banco C: K*K elementos de 32 bits

    // Registros internos para retener el dato leído (salidas síncronas)
    s16_t dout16_reg;
    s32_t dout32_reg;

    //--------------------------------------------------------------------------
    // Lógica síncrona de lectura/escritura
    // Se ejecuta en el flanco positivo de `clk`.
    // - Cuando rst=1 reinicia flags y datos leídos.
    // - Si we16=1: escribe en memA o memB según mat_sel, y marca ready16.
    // - Si re16=1: lee de memA o memB, guarda en dout16_reg, marca ready16.
    // - Si we32=1: escribe en memC y marca ready32.
    // - Si re32=1: lee de memC, guarda en dout32_reg, marca ready32.
    // - En ausencia de enables, ambas ready16 y ready32 se ponen a 0.
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset: limpia los flags y datos de salida
            ready16    <= 1'b0;
            ready32    <= 1'b0;
            dout16_reg <= '0;
            dout32_reg <= '0;
        end
        else begin
            // ----- Operaciones para el puerto A/B (16 bits) -----
            if (we16) begin
                // Escritura en memA o memB
                if (mat_sel == 1'b0)
                    memA[addr16] <= din16;
                else
                    memB[addr16] <= din16;
                ready16 <= 1'b1;    // operación completada este ciclo
            end
            else if (re16) begin
                // Lectura de memA o memB
                if (mat_sel == 1'b0)
                    dout16_reg <= memA[addr16];
                else
                    dout16_reg <= memB[addr16];
                ready16 <= 1'b1;    // dato listo para salir
            end
            else begin
                ready16 <= 1'b0;    // inactivo cuando no hay operación
            end

            // ----- Operaciones para el puerto C (32 bits) -----
            if (we32) begin
                // Escritura en memC
                memC[addr32] <= din32;
                ready32 <= 1'b1;    // completada
            end
            else if (re32) begin
                // Lectura de memC
                dout32_reg <= memC[addr32];
                ready32 <= 1'b1;    // lectura lista
            end
            else begin
                ready32 <= 1'b0;    // inactivo
            end
        end
    end

    //--------------------------------------------------------------------------
    // Salidas combinacionales finales
    // - `doutX` refleja el dato registrado en el último ciclo de lectura
    // - `stallX` es simplemente el inverso de `readyX`
    //--------------------------------------------------------------------------
    assign dout16  = dout16_reg;    // dato leído de 16 bits
    assign dout32  = dout32_reg;    // dato leído de 32 bits
    assign stall16 = ~ready16;      // 1 mientras no esté listo
    assign stall32 = ~ready32;      // 1 mientras no esté listo


    //-------------- Performance counters ------------
    logic read16_pend, write16_pend;
    logic read32_pend, write32_pend;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Flags de pending
            read16_pend   <= 1'b0;
            write16_pend  <= 1'b0;
            read32_pend   <= 1'b0;
            write32_pend  <= 1'b0;
            // Contadores
            read16_count          <= '0;
            write16_count         <= '0;
            read32_count          <= '0;
            write32_count         <= '0;
            bits_read_16_count    <= '0;
            bits_written_16_count <= '0;
            bits_read_32_count    <= '0;
            bits_written_32_count <= '0;
        end else begin
            // Captura la solicitud cuando re16/we16 se activa
            if (re16)
                read16_pend  <= 1'b1;
            if (we16)
                write16_pend <= 1'b1;

            // Cuando ready16 llega y había una request pendiente, contamos
            if (ready16 && read16_pend) begin
                read16_count          <= read16_count + 1;
                bits_read_16_count    <= bits_read_16_count + 16;
                read16_pend           <= 1'b0;
            end
            if (ready16 && write16_pend) begin
                write16_count         <= write16_count + 1;
                bits_written_16_count <= bits_written_16_count + 16;
                write16_pend          <= 1'b0;
            end

            // Análogamente para 32 bits
            if (re32)
                read32_pend  <= 1'b1;
            if (we32)
                write32_pend <= 1'b1;

            if (ready32 && read32_pend) begin
                read32_count          <= read32_count + 1;
                bits_read_32_count    <= bits_read_32_count + 32;
                read32_pend           <= 1'b0;
            end
            if (ready32 && write32_pend) begin
                write32_count         <= write32_count + 1;
                bits_written_32_count <= bits_written_32_count + 32;
                write32_pend          <= 1'b0;
            end
        end
    end

endmodule
