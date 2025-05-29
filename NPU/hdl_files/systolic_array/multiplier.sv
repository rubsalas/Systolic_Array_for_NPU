//------------------------------------------------------------------------------
// multiplier.sv  –  Producto combinacional
//------------------------------------------------------------------------------
import pkg_systolic::*;

module multiplier (
  	input  s16_t a_in,                 // DATA_W-1 : 0  (16 bits con signo)
  	input  s16_t b_in,
  	output s32_t p_out                 // ACC_W   (32 bits con signo)
);

  	assign p_out = a_in * b_in;        // el sintetizador lo mapea a un DSP

endmodule
