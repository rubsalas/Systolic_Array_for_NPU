module tdi_display (
    input  logic clk,                     // Reloj del sistema
    input  logic rst,                     // Reset síncrono
    input  logic tck,                     // Reloj de JTAG
    input  logic tdi,                     // Dato serial desde JTAG
    input  logic shift_dr,               // Activo mientras se reciben bits
    input  logic virtual_state_udr,      // Pulso que indica que el dato está completo

    output logic [6:0] hex0,             // Display de 7 segmentos: parte baja
    output logic [6:0] hex1              // Display de 7 segmentos: parte alta
);

    logic [7:0] shift_reg;               // Registro de desplazamiento
    logic [3:0] nibble_lsb, nibble_msb;  // 2 mitades del byte para los displays

    // Registro que recibe bits de TDI uno a uno
    always_ff @(posedge tck or posedge rst) begin
        if (rst)
            shift_reg <= 8'b0;
        else if (shift_dr)
            shift_reg <= {shift_reg[6:0], tdi}; // LSB por la derecha
    end

    // Al finalizar el shift, actualiza los displays
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            nibble_lsb <= 4'd0;
            nibble_msb <= 4'd0;
        end else if (virtual_state_udr) begin
            nibble_lsb <= shift_reg[3:0];
            nibble_msb <= shift_reg[7:4];
        end
    end

    // Conversión de número hexadecimal a 7 segmentos
    function automatic [6:0] to_7seg(input logic [3:0] nibble);
        case (nibble)
            4'h0: to_7seg = 7'b1000000;
            4'h1: to_7seg = 7'b1111001;
            4'h2: to_7seg = 7'b0100100;
            4'h3: to_7seg = 7'b0110000;
            4'h4: to_7seg = 7'b0011001;
            4'h5: to_7seg = 7'b0010010;
            4'h6: to_7seg = 7'b0000010;
            4'h7: to_7seg = 7'b1111000;
            4'h8: to_7seg = 7'b0000000;
            4'h9: to_7seg = 7'b0010000;
            4'hA: to_7seg = 7'b0001000;
            4'hB: to_7seg = 7'b0000011;
            4'hC: to_7seg = 7'b1000110;
            4'hD: to_7seg = 7'b0100001;
            4'hE: to_7seg = 7'b0000110;
            4'hF: to_7seg = 7'b0001110;
            default: to_7seg = 7'b1111111; // apagado
        endcase
    endfunction

    assign hex0 = to_7seg(nibble_lsb);
    assign hex1 = to_7seg(nibble_msb);

endmodule
