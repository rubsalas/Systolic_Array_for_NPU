//==============================================================================
// matrix_memory.sv
//------------------------------------------------------------------------------
// Módulo de memoria sencillo de doble puerto (abstrae BRAMs/XRAMs en FPGA).
// - Almacena dos matrices de entrada (A y B) de K×K palabras de 16 bits.
// - Almacena una matriz de salida (C) de K×K palabras de 32 bits.
// - Puerto A/B (16 bits): permite escribir o leer A o B según `mat_sel`.
// - Puerto C   (32 bits): permite escribir o leer la matriz C de resultados.
// - Señales `readyX` indican cuándo finaliza la operación;
//   `stallX` es el complementario para back-pressure.
//==============================================================================
`timescale 1ns/1ps
import pkg_systolic::*;

module MRAM #(
    parameter int K = 4             // Dimensión de cada matriz (K×K)
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
    output logic        stall32     // 1 mientras no esté listo (ready32=0)
);

    //--------------------------------------------------------------------------
    // Bancos de memoria interna (synthé en BRAMs o LUT-RAMs)
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

endmodule
