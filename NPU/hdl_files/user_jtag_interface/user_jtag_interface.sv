//
//
//
`timescale 1ns/1ps
import pkg_systolic::*;

module user_jtag_interface #(
    parameter int K = 4            // dimensión de matriz (K×K)
)(
    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] cmd_in,
    input  logic       use_relu_in,
    input  logic       use_stepping_in,
    input  logic       mat_sel,
    input  logic [$clog2(K*K)-1:0] address,
    input  s16_t       din16,
    input  logic       perf_sel,

    // Command strobe
    input  logic       confirm,

    // Outputs to Control Unit
    output logic       use_relu_out,
    output logic       use_stepping_out,
    output logic       start_exec,
    output logic       matrices_loaded,
    output logic       stop_exec
);

    logic cmd_reg;

    //-------------------------------------------------------------------------
    // 1) Detect falling edge of `confirm`: 1 → 0 transition
    //-------------------------------------------------------------------------
    logic confirm_d;
    logic confirm_fall;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            confirm_d <= 1'b0;
        else
            confirm_d <= confirm;
    end
    assign confirm_fall = (confirm_d == 1'b1 && confirm == 1'b0);


    //-------------------------------------------------------------------------
    // 2) FSM state encoding: only used transiently to select the action
    //-------------------------------------------------------------------------
    typedef enum logic [3:0] {
        IDLE         = 4'd0,
        SET_RELU     = 4'd1,
        SET_STEPPING = 4'd2,
        WRITE        = 4'd3,
        START        = 4'd4,
        STEP         = 4'd5,
        READ         = 4'd6,
        PERF_COUNTER = 4'd7,
        RESET        = 4'd8,
        DONE         = 4'd9
    } state_t;

    state_t state, next_state;

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        if (confirm_fall) begin
            next_state = state_t'(cmd_in);     // jump to the selected action state
            cmd_reg = cmd_in;
        end else begin
            case (state)
                SET_RELU,
                SET_STEPPING,
                WRITE,
                START,
                STEP,
                READ,
                PERF_COUNTER,
                RESET,
                DONE: next_state = IDLE; // return automatically to IDLE
                default: next_state = state;
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 3) Persistent registers for each control bit
    //-------------------------------------------------------------------------
    

    logic use_relu_reg;
    logic start_exec_reg;
    logic matrices_loaded_reg;
    logic stop_exec_reg;
    // Optional: stepping register, for future STEP usage
    logic use_stepping_reg;

    // Update registers based on state
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            use_relu_reg        <= 1'b0;
            start_exec_reg      <= 1'b0;
            matrices_loaded_reg <= 1'b0;
            stop_exec_reg       <= 1'b0;
            use_stepping_reg    <= 1'b0;
        end else begin

            // Por defecto, mantenemos todo a 0 (o su valor actual)
            use_relu_reg        <= use_relu_reg;
            start_exec_reg      <= 1'b0;  // <— pulso por defecto en 0
            matrices_loaded_reg <= matrices_loaded_reg;
            stop_exec_reg       <= stop_exec_reg;
            use_stepping_reg    <= use_stepping_reg;

            case (state)
                //-------------------------------------------------------------------------
                SET_RELU: begin
                    use_relu_reg <= use_relu_in;
                end

                //-------------------------------------------------------------------------
                SET_STEPPING: begin
                    use_stepping_reg <= use_stepping_in;
                end

                //-------------------------------------------------------------------------
                WRITE: begin
                    // toggle matrices_loaded
                    matrices_loaded_reg <= ~matrices_loaded_reg;
                end

                //-------------------------------------------------------------------------
                START: begin
                    // Se genera un pulso de 1 ciclo
                    start_exec_reg <= 1'b1;
                end

                //-------------------------------------------------------------------------
                RESET: begin
                    // clear all
                    use_relu_reg        <= 1'b0;
                    start_exec_reg      <= 1'b0;
                    matrices_loaded_reg <= 1'b0;
                    stop_exec_reg       <= 1'b0;
                    use_stepping_reg    <= 1'b0;
                end

                //-------------------------------------------------------------------------
                DONE: begin
                    // toggle stop_exec
                    stop_exec_reg <= ~stop_exec_reg;
                end

                // other states (STEP, READ, PERF_COUNTER) can be populated later
                default: begin
                    // no change
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 4) Drive outputs from registers
    //-------------------------------------------------------------------------
    assign use_relu_out     = use_relu_reg;
    assign use_stepping_out = use_stepping_reg;
    assign start_exec       = start_exec_reg;
    assign matrices_loaded  = matrices_loaded_reg;
    assign stop_exec        = stop_exec_reg;

endmodule
