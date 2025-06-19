//------------------------------------------------------------------------------
// multiplier.sv  –  Módulo multiplicador para hardware
//
//   p_out = a_in × b_in
//
// • 0 ciclos de latencia      →  completamente combinacional.
// • 1 multiplicador          →  mapeado a DSP (o LUT según la FPGA).
// • Sin registros internos.
//
//   Puertos
//   -------
//     a_in   : operando A (s16_t, 16 bits con signo)
//     b_in   : operando B (s16_t, 16 bits con signo)
//     p_out  : producto   (s32_t, 32 bits con signo)
//
//------------------------------------------------------------------------------
import pkg_systolic::*;

module multiplier (
  	input  s16_t a_in,                 // DATA_W-1 : 0  (16 bits con signo)
  	input  s16_t b_in,
  	output s32_t p_out                 // ACC_W   (32 bits con signo)
);

  	assign p_out = a_in * b_in;        // el sintetizador lo mapea a un DSP

endmodule
