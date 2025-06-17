//==============================================================================
// sseg_display.sv
//------------------------------------------------------------------------------
// Despliega en dos displays de 7 segmentos (HEX1:alto, HEX0:bajo) los últimos
// 8 bits recibidos por la señal serial TDI.
//
// Funcionamiento:
// 1) Registro de desplazamiento de 8 bits:
//     • En cada flanco de subida de 'tdi' captura el bit entrante.
//     • Desplaza hacia la izquierda los bits previos, manteniendo un histórico
//       de los últimos 8 pulsos de TDI.
// 2) Decodificación a 7 segmentos:
//     • tdi_data[3:0] → nibble bajo → display HEX0.
//     • tdi_data[7:4] → nibble alto → display HEX1.
// 3) Los bloques 'hex_to_sseg' convierten un valor binario de 4 bits a la
//    codificación activa-baja/activa-alta del display (depende de la implementación).
//
// Puertos:
//   • tdi   : entrada serial de datos (uno por pulso de reloj TDI).
//   • HEX0  : segmentos [6:0] del display de nibble bajo.
//   • HEX1  : segmentos [6:0] del display de nibble alto.
//
// Uso típico:
//   • Conectar la señal TDI de un JTAG/UART o generador de patrones para ver
//     en tiempo real los bits de datos desplazados en los displays.
//==============================================================================

module sseg_display (
    input  logic      tdi,    // señal de datos serial entrante (tactil de reloj implícito)
    output logic [6:0] HEX0,  // segmentos del display de 7 segmentos (nibble bajo)
    output logic [6:0] HEX1   // segmentos del display de 7 segmentos (nibble alto)
);

    // Registro de desplazamiento de 8 bits:
    //   tdi_data[7] = bit más antiguo, tdi_data[0] = último bit capturado
    logic [7:0] tdi_data;

    // Captura un bit en cada subida de TDI:
    //   - Desplaza a la izquierda el registro
    //   - Inserta tdi en la posición LSB
    always_ff @(posedge tdi) begin
        tdi_data <= {tdi_data[6:0], tdi};
    end

    // Instancia decodificadores de 4 bits a 7 segmentos:
    //  • HEX0 muestra el nibble bajo de tdi_data
    //  • HEX1 muestra el nibble alto de tdi_data
    hex_to_sseg h0 (
        .bin (tdi_data[3:0]),
        .seg (HEX0)
    );
    hex_to_sseg h1 (
        .bin (tdi_data[7:4]),
        .seg (HEX1)
    );

endmodule
