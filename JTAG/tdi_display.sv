module tdi_display (
    input  logic tdi,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1
);

    logic [7:0] tdi_data;

    // Registro de desplazamiento para capturar los últimos 8 bits enviados por TDI
    always_ff @(posedge tdi) begin
        tdi_data <= {tdi_data[6:0], tdi};
    end

    // Mostrar nibble bajo en HEX0, nibble alto en HEX1
    hex7seg h0 (.bin(tdi_data[3:0]), .seg(HEX0));
    hex7seg h1 (.bin(tdi_data[7:4]), .seg(HEX1));

endmodule
