//==============================================================================
// hex_to_sseg.sv
//------------------------------------------------------------------------------
// Convierte un valor binario de 4 bits en la codificación de segmentos para
// un display de 7 segmentos.
// 
// • bin [3:0] : entrada binaria 0–15.
// • seg [6:0] : salida de segmentos, mapea cada bit a un segmento del display:
//      seg[6] = segmento a (arriba)
//      seg[5] = segmento b (arriba-derecha)
//      seg[4] = segmento c (abajo-derecha)
//      seg[3] = segmento d (abajo)
//      seg[2] = segmento e (abajo-izquierda)
//      seg[1] = segmento f (arriba-izquierda)
//      seg[0] = segmento g (centro)
//
// La codificación es activa-baja (0 enciende el segmento) con el patrón:
//    0 → “0”  : 7'b100_0000  (solo ‘a’ apagado)
//    1 → “1”  : 7'b111_1001  (solo ‘b’ y ‘c’ encendidos)
//    …
//    F → “F”  : 7'b000_1110  (hexadecimal F)
//
// Si el valor de ‘bin’ está fuera de 0–F, todos los segmentos permanecen
// apagados (7'b111_1111).
//==============================================================================

module hex_to_sseg (
    input  logic [3:0] bin,   // valor hexadecimal 0–F en bits
    output logic [6:0] seg    // segmentos del display de 7 segmentos
);

    // Decodificación combinacional:
    // Selecciona la combinación de segmentos para cada valor de 'bin'.
    always_comb begin
        case (bin)
            4'h0: seg = 7'b100_0000;
            4'h1: seg = 7'b111_1001;
            4'h2: seg = 7'b010_0100;
            4'h3: seg = 7'b011_0000;
            4'h4: seg = 7'b001_1001;
            4'h5: seg = 7'b001_0010;
            4'h6: seg = 7'b000_0010;
            4'h7: seg = 7'b111_1000;
            4'h8: seg = 7'b000_0000;
            4'h9: seg = 7'b001_0000;
            4'hA: seg = 7'b000_1000; // “A”
            4'hB: seg = 7'b000_0011; // “b”
            4'hC: seg = 7'b100_0110; // “C”
            4'hD: seg = 7'b010_0001; // “d”
            4'hE: seg = 7'b000_0110; // “E”
            4'hF: seg = 7'b000_1110; // “F”
            default: seg = 7'b111_1111; // apagado
        endcase
    end

endmodule
