//------------------------------------------------------------------------------
// simple_user_jtag_interface.sv – Command interface with persistent toggling
//
// Description:
//   This module provides a simple way to toggle four control signals
//   (`use_relu`, `start_exec`, `matrices_loaded`, `stop_exec`) by issuing
//   a “confirm” pulse on the falling edge of `confirm`. Each command is
//   encoded on a 2-bit bus `cmd_in`:
//
//     cmd_in == 2'b00 → toggle `use_relu`
//     cmd_in == 2'b01 → toggle `start_exec`
//     cmd_in == 2'b10 → toggle `matrices_loaded`
//     cmd_in == 2'b11 → toggle `stop_exec`
//
//   On reset, all outputs start at 0. Whenever `confirm` goes 1→0, the
//   module inverts the bit corresponding to the current `cmd_in` and
//   holds it until the next toggle of that same command.
//
// Ports:
//   clk             : System clock                               (in)
//   rst             : Synchronous reset (active high)            (in)
//   cmd_in[1:0]     : Command select                             (in)
//   confirm         : Toggle strobe (detect falling edge)        (in)
//   use_relu        : Persistent output, toggled by cmd 00       (out)
//   start_exec      : Persistent output, toggled by cmd 01       (out)
//   matrices_loaded : Persistent output, toggled by cmd 10       (out)
//   stop_exec       : Persistent output, toggled by cmd 11       (out)
//------------------------------------------------------------------------------

module simple_user_jtag_interface (
    input  logic       clk,
    input  logic       rst,
    input  logic [1:0] cmd_in,
    input  logic       confirm,

    output logic       use_relu,
    output logic       start_exec,
    output logic       matrices_loaded,
    output logic       stop_exec
);

    //-------------------------------------------------------------------------
    // 1) Detect falling edge of `confirm`: 1 → 0 transition
    //-------------------------------------------------------------------------
    logic confirm_d;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            confirm_d <= 1'b0;
        else
            confirm_d <= confirm;
    end
    wire confirm_fall = (confirm_d == 1'b1 && confirm == 1'b0);

    //-------------------------------------------------------------------------
    // 2) Registers holding the persistent state of each command bit
    //-------------------------------------------------------------------------
    logic use_relu_reg;
    logic start_exec_reg;
    logic matrices_loaded_reg;
    logic stop_exec_reg;

    // Initialize on reset; otherwise toggle on confirm_fall
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            use_relu_reg        <= 1'b0;
            start_exec_reg      <= 1'b0;
            matrices_loaded_reg <= 1'b0;
            stop_exec_reg       <= 1'b0;
        end else if (confirm_fall) begin
            case (cmd_in)
                2'b00: use_relu_reg        <= ~use_relu_reg;
                2'b01: start_exec_reg      <= ~start_exec_reg;
                2'b10: matrices_loaded_reg <= ~matrices_loaded_reg;
                2'b11: stop_exec_reg       <= ~stop_exec_reg;
                default: /* unreachable */;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 3) Drive outputs from the registers
    //-------------------------------------------------------------------------
    assign use_relu        = use_relu_reg;
    assign start_exec      = start_exec_reg;
    assign matrices_loaded = matrices_loaded_reg;
    assign stop_exec       = stop_exec_reg;

endmodule
