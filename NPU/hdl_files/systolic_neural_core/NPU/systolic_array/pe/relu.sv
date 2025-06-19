//------------------------------------------------------------------------------
// relu.sv  –  Función de activación ReLU para hardware
//
//   y = max(0 , x)
//
// • 0 ciclos de latencia  →  completamente combinacional.
// • 1 comparador   (bit de signo)   +   1 multiplexor     ≈   2-3 LUTs.
// • Pasa la señal de validez sin modificarla.
//
//   Puertos
//   -------
//     x_in   : dato de entrada firmado  (W bits)
//     v_in   : pulso/flag de validez asociado a x_in
//     y_out  : resultado  ->   x_in   si x_in ≥ 0
//                             0       si x_in < 0
//     v_out  : la misma validez, re-sincronizada (wire-thru)
//------------------------------------------------------------------------------
`timescale 1ns/1ps
import pkg_systolic::*;

module relu (
    input  s32_t x_in,      // 32-bit signed input
    input  logic v_in,      // validity flag for x_in
    output s32_t y_out,     // ReLU output (32-bit signed)
    output logic v_out      // propagated validity flag
);

    // Combinational ReLU: if MSB (sign) is 1 → clamp to zero
    assign y_out = x_in[ACC_W-1] ? '0 : x_in;

    // Validity passes straight through
    assign v_out = v_in;

endmodule
