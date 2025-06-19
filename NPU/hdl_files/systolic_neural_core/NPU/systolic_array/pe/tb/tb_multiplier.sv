`timescale 1ns/1ps              // 1 ns de resolución, 1 ps de precisión
import pkg_systolic::*;         // Trae DATA_W, ACC_W, s16_t, s32_t

// -----------------------------------------------------------------------------
// tb_multiplier
//   • Verifica el módulo multiplier
//   • Genera N_TESTS pares (a_in, b_in) aleatorios con signo de 16 bits
//   • Calcula la referencia dorada exp_val = a_in * b_in
//   • Compara inmediatamente p_out (tras #1 δ-cycle de simulación)
// -----------------------------------------------------------------------------
module tb_multiplier;

	// ---------------------------------------------------------------------------
	// Parámetros
	// ---------------------------------------------------------------------------
	localparam int N_TESTS = 250;   // número de vectores que inyectaremos

	int   err_cnt = 0;              // contador de mismatches encontrados
	int   seed    = 42;             // semilla para reproducibilidad

	// ---------------------------------------------------------------------------
	// Señales que conectan con el UUT
	// ---------------------------------------------------------------------------
	s16_t a_in, b_in;               // operandos de 16 bits con signo
	s32_t p_out;                    // producto de 32 bits
	s32_t exp_val;                  // “golden” reference para comparación

	// ---------------------------------------------------------------------------
	// Instancia del Dispositivo Bajo Prueba (UUT)
	// ---------------------------------------------------------------------------
	multiplier uut (
		.a_in (a_in),
		.b_in (b_in),
		.p_out(p_out)
	);

	// ---------------------------------------------------------------------------
	// Bloque inicial: genera estímulos y comprueba resultados
	//  ▸ El DUT (multiplier) es combinacional, así que no necesitamos reloj.
	// ---------------------------------------------------------------------------
	initial begin
	//-----------------------------------------------------------------
	// 1) Sembrar el generador de números aleatorios
	//    Quartus/ModelSim no acepta «void'(…)», así que llamamos
	//    $urandom(seed) a secas y desechamos el valor que devuelve.
	//-----------------------------------------------------------------
	$urandom(seed);          // <—  línea corregida (sin void' cast)

	//-----------------------------------------------------------------
	// 2) Bucle principal con N_TESTS vectores aleatorios
	//-----------------------------------------------------------------
	for (int i = 0; i < N_TESTS; i++) begin
		// ► Operand-A aleatorio con signo de 16 bits
		a_in = $signed($urandom_range((2**(DATA_W-1))-1,
									-(2**(DATA_W-1))));
		// ► Operand-B aleatorio con signo de 16 bits
		b_in = $signed($urandom_range((2**(DATA_W-1))-1,
									-(2**(DATA_W-1))));

		#1;                     // δ-cycle: tiempo para que p_out se resuelva

		exp_val = a_in * b_in;  // calcula referencia dorada

		// ► Comparación estricta (!== detecta X/Z)
		if (p_out !== exp_val) begin
		$error("[tb_multiplier] MISMATCH %0d * %0d → got %0d, exp %0d",
				a_in, b_in, p_out, exp_val);
		err_cnt++;
		end
	end

	//-----------------------------------------------------------------
	// 3) Informe final
	//-----------------------------------------------------------------
	if (err_cnt == 0)
		$display("[tb_multiplier] TODOS los %0d vectores PASARON", N_TESTS);
	else
		$display("[tb_multiplier] %0d errores en %0d vectores",
				err_cnt, N_TESTS);

	$finish;
	end

endmodule
