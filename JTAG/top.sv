`default_nettype none

module top (
    input  logic clk,
    //input  logic rst,
	 input logic key0,
    output logic [6:0] HEX0,
    output logic [6:0] HEX1
);

    // Señales internas para el JTAG
    logic tck, tdi;
    logic [7:0] ir_in, ir_out;
    logic tdo;
	 logic rst;
	 assign rst = ~key0;         // Reset activo en alto

    logic virtual_state_cdr;
    logic virtual_state_sdr;
    logic virtual_state_e1dr;
    logic virtual_state_pdr;
    logic virtual_state_e2dr;
    logic virtual_state_udr;
    logic virtual_state_cir;
    logic virtual_state_uir;

    // Instancia del módulo sld_virtual_jtag
    sld_virtual_jtag #(
        .sld_auto_instance_index("YES"),
        .sld_instance_index(0),
        .sld_ir_width(8),
        .sld_sim_action(""),
        .sld_sim_n_scan(""),
        .sld_sim_total_length(0)
    ) jtag_inst (
        .tck(tck),
        .tdi(tdi),
        .tdo(tdo),
        .ir_in(ir_in),
        .ir_out(ir_out),
        .virtual_state_cdr(virtual_state_cdr),
        .virtual_state_sdr(virtual_state_sdr),
        .virtual_state_e1dr(virtual_state_e1dr),
        .virtual_state_pdr(virtual_state_pdr),
        .virtual_state_e2dr(virtual_state_e2dr),
        .virtual_state_udr(virtual_state_udr),
        .virtual_state_cir(virtual_state_cir),
        .virtual_state_uir(virtual_state_uir)
    );

    // Instancia del módulo que muestra el valor de TDI en HEX0 y HEX1
    tdi_display tdi_disp_inst (
        .tdi(tdi),
        .HEX0(HEX0),
        .HEX1(HEX1)
    );

endmodule
