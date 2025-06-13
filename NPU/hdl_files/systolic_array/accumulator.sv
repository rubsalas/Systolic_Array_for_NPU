//------------------------------------------------------------------------------
// accumulator.sv  —  Suma K productos y emite resultado un ciclo después
//
//   ◦ Acumula exactamente K productos de 32 b con signo.
//   ◦ El resultado FINAL aparece en acc_out y last_prod se pone a 1 durante ese
//     mismo ciclo (un latido) — es el ciclo *siguiente* al último producto.
//   ◦ Inmediatamente después borra ACC (de modo que el PE empieza limpio).
//
//   Señales
//   --------
//     clk, rst   : reloj y reset síncrono activo‑bajo
//     valid_in     : '1' cuando prod_in es válido este ciclo
//     prod_in      : producto A·B (32 bits, signed)
//     acc_out      : suma parcial / resultado final
//     last_prod    : pulso 1‑clk cuando acc_out contiene resultado final
//------------------------------------------------------------------------------
import pkg_systolic::*;

module accumulator #(
	parameter int K = 4                       // nº de productos por celda
	)(
	input  logic clk,
	input  logic rst,

	input  logic valid_in,	// validez de prod_in
	input  s32_t prod_in,

	output s32_t acc_out,
	output logic last_prod
	);
	//–––––– Ancho mínimo para el contador 0..K‑1 ––––––––––––––––––––––––––––
	localparam int CNT_W = (K <= 1) ? 1 : $clog2(K);

	//–––––– Registros internos ––––––––––––––––––––––––––––––––––––––––––––––
	logic [CNT_W-1:0] k_cnt;        // cuenta productos procesados
	s32_t             acc_reg;      // acumulador
	logic             res_ready;    // flag → emitiremos resultado en Próx. ciclo

	//–––––– Lógica secuencial principal ––––––––––––––––––––––––––––––––––––
	always_ff @(posedge clk) begin
		// RESET ---------------------------------------------------------------
		if (rst) begin
			k_cnt     <= '0;
			acc_reg   <= '0;
			res_ready <= 1'b0;
		end

		// CICLO POST‑RESULTADO: emitir salida y limpiar ACC -------------------
		else if (res_ready) begin
			// acc_out mostrará el valor *actual* de acc_reg durante todo este ciclo
			// Después lo ponemos a 0 para la próxima celda.
			acc_reg   <= '0;
			res_ready <= 1'b0;
		end

		// RECEPCIÓN DE PRODUCTO VÁLIDO ---------------------------------------
		else if (valid_in) begin
			// 1er producto → carga directa; resto → suma
			acc_reg <= (k_cnt == 0) ? prod_in : acc_reg + prod_in;

			// Actualiza contador
			if (k_cnt == K-1) begin
				k_cnt     <= '0;      // se prepara para la siguiente celda
				res_ready <= 1'b1;    // marcaremos resultado en próximo ciclo
			end else begin
				k_cnt     <= k_cnt + 1'b1;
			end
		end
	end

	//–––––– Salidas ––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	assign acc_out   = acc_reg;     // siempre refleja el valor interno
	assign last_prod = res_ready;   // pulso 1‑clk junto al resultado válido
endmodule
