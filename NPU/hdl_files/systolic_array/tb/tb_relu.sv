`timescale 1ns/1ps
import pkg_systolic::*;

// -----------------------------------------------------------------------------
// tb_relu.sv  –  Banco de pruebas básico para relu.sv (5 estímulos)
// -----------------------------------------------------------------------------
module tb_relu;

    // Reloj a 100 MHz ----------------------------------------------------------
    logic clk = 0;
    always #5 clk = ~clk;   // período 10 ns

    // DUT ---------------------------------------------------------------------
    s32_t x_in;
    logic v_in;
    s32_t y_out;
    logic v_out;

    relu uut (
        .x_in  (x_in),
        .v_in  (v_in),
        .y_out (y_out),
        .v_out (v_out)
    );

    // Vectores de prueba ------------------------------------------------------
    s32_t stim_vec [5:0];          // 5 valores (index 0‥4)
    initial begin
        stim_vec[0] =  123;        // positivo pequeño
        stim_vec[1] = -456;        // negativo
        stim_vec[2] =    0;        // cero
        stim_vec[3] = 32767;       // positivo grande
        stim_vec[4] =   -1;        // -1
    end

    // Variables auxiliares ----------------------------------------------------
    int   err_cnt   = 0;
    int   i;                        // índice del bucle
    s32_t exp_val;                  // valor esperado

    // Procedimiento principal -------------------------------------------------
    initial begin
        // valores seguros antes de arrancar
        x_in = 0;
        v_in = 0;
        @(posedge clk);

        for (i = 0; i < 5; i = i + 1) begin
            // 1) aplicar estímulo
            @(posedge clk);
            x_in = stim_vec[i];
            v_in = 1;

            // 2) esperar pequeña δ
            #1;

            // 3) referencia y chequeo
            if (stim_vec[i][ACC_W-1] == 1'b1)
                exp_val = 0;
            else
                exp_val = stim_vec[i];

            $display("[%0t ns] Test %00d  x_in=%0d  y_out=%0d  exp=%0d",
                     $time, i, stim_vec[i], y_out, exp_val);

            if (v_out !== v_in) begin
                $display("ERROR: v_out incorrecto en test %00d", i);
                err_cnt = err_cnt + 1;
            end
            if (y_out !== exp_val) begin
                $display("ERROR: Resultado incorrecto en test %00d", i);
                err_cnt = err_cnt + 1;
            end

            // 4) retirar validez un ciclo
            @(posedge clk);
            v_in = 0;
        end

        // Informe final -------------------------------------------------------
        if (err_cnt == 0)
            $display("\n[RESUMEN] Todas las pruebas PASARON");
        else
            $display("\n[RESUMEN] Se detectaron %0d errores", err_cnt);

        $finish;
    end
endmodule
