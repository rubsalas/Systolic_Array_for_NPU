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
  multiplier_comb uut (
    .a_in (a_in),
    .b_in (b_in),
    .p_out(p_out)
  );

  // ---------------------------------------------------------------------------
  // Bloque inicial: genera estímulos y chequea resultados
  // No hay reloj porque el DUT es 100 % combinacional
  // ---------------------------------------------------------------------------
  initial begin
    // Fija la semilla UNA vez.  $urandom_range usará esa secuencia.
    void'($urandom(seed));

    // Bucle principal de estímulo
    for (int i = 0; i < N_TESTS; i++) begin

      // Se genera un entero aleatorio con signo de 16 bits para cada operando.
      //  $urandom_range(max, min) devuelve uint;   $signed(...) -> sint.
      a_in = $signed($urandom_range((2**(DATA_W-1))-1, -(2**(DATA_W-1))));
      b_in = $signed($urandom_range((2**(DATA_W-1))-1, -(2**(DATA_W-1))));

      #1;                       // permite que p_out se estabilice

      exp_val = a_in * b_in;    // producto esperado calculado por el TB

      // ► Comparación bit-a-bit (=== / !== evita «X/Z» ambiguos)
      if (p_out !== exp_val) begin
        $error("[tb_multiplier] MISMATCH  %0d * %0d  -> got %0d, exp %0d",
               a_in, b_in, p_out, exp_val);
        err_cnt++;
      end
    end

    // -------------------------------------------------------------------------
    // Informe final
    // -------------------------------------------------------------------------
    if (err_cnt == 0)
      $display("[tb_multiplier] TODOS los %0d vectores PASARON", N_TESTS);
    else
      $display("[tb_multiplier] %0d errores sobre %0d vectores",
               err_cnt, N_TESTS);

    $finish;
  end

endmodule
