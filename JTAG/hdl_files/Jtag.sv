module Jtag (
    output logic tdo
);

    logic tck;
    logic tdi;
    logic [7:0] ir_in;
    logic [7:0] ir_out = 8'h00;
    logic virtual_state_sdr;

    // Instancia del Virtual JTAG
    sld_virtual_jtag #(
        .sld_auto_instance_index("YES"),
        .sld_instance_index(0),
        .sld_ir_width(2)
    ) vjtag_inst (
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .ir_in(ir_in),
        .ir_out(ir_out),
        .virtual_state_sdr(virtual_state_sdr),
        .virtual_state_cdr(), .virtual_state_e1dr(), .virtual_state_pdr(),
        .virtual_state_e2dr(), .virtual_state_udr(),
        .virtual_state_cir(), .virtual_state_uir()
    );

    logic tdo_reg;

    always_ff @(posedge tck) begin
        if (virtual_state_sdr) begin
            tdo_reg <= tdi;  // Eco simple de TDI a TDO
        end
    end

    assign tdo = tdo_reg;

endmodule
