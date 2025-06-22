//------------------------------------------------------------------------------
// control_unit.sv – Control Unit for Systolic Neural Processing Unit
// 
// Description:
//   FSM that orchestrates the execution flow:
//     • Load matrices from MRAM
//     • Prefetch into Systolic Neural Core (SNC)
//     • Compute in SNC
//     • Commit results via Matrix Commit Unit
//     • Wait for performance monitor snapshot
//     • Handshake with external user interface (UJI)
//
//   Forwards key signals unchanged for downstream modules.
//
// Ports:
//   clk                   : System clock                            (in)
//   rst                   : Synchronous reset (active high)         (in)
//
//   // External interface (UJI)
//   start_exec            : Host starts execution cycle             (in)
//   stop_exec             : Host clears exec_done & returns to IDLE (in)
//   exec_active           : High while any stage is active          (out)
//   exec_done             : High when full cycle completes          (out)
//
//   // Data readiness
//   matrices_loaded       : MRAM → CU flags A/B ready               (in)
//   matrices_loaded_fw    : Forward to SNC for prefetch gating      (out)
//
//   // Prefetch stage (SNC)
//   prefetch_start        : CU → SNC 1-clk pulse to start prefetch  (out)
//
//   // Compute stage (SNC)
//   npu_busy              : SNC → CU busy flag during compute       (in)
//   npu_done              : SNC → CU flag when compute finishes     (in)
//
//   // Commit stage (Matrix Commit Unit)
//   commit_start          : CU → SNC 1-clk pulse to start commit    (out)
//   result_stored         : Commit unit → CU when write-back done   (in)
//   result_stored_fw      : Forward to perf_monitor gating          (out)
//
//   // Performance monitor
//   counters_ready        : perf_monitor → CU snapshot complete     (in)
//
//   // Flow control/config
//   use_relu              : Host → CU configuration flag            (in)
//   use_relu_fw           : Forward to SNC                          (out)
//
// States:
//   IDLE      — waiting for start_exec
//   WAIT_LOAD — waiting for matrices_loaded
//   PREFETCH  — issue prefetch_start pulse
//   COMPUTE   — wait on npu_done (exec_active driven by npu_busy)
//   COMMIT    — issue commit_start pulse, wait on result_stored
//   SNAPSHOT  — wait on counters_ready
//   DONE      — assert exec_done, wait for stop_exec
//------------------------------------------------------------------------------
`timescale 1ns/1ps

module control_unit #(
    parameter int P = 32                // Width of performance counters
)(
    input  logic clk,
    input  logic rst,

    // External interface
    input  logic start_exec,            // Start command from host                  // [n] from UJI
    input  logic stop_exec,             // Clear done & go to IDLE                  // [n] from UJI
    // Data readiness
    input  logic matrices_loaded,       // Flag de que MRAM ya cargó matrices A/B   // [n] from UJI
    // Compute stage
    input  logic npu_busy,              // Busy flag                                // [n] from SNC 
    input  logic npu_done,              // Compute done                             // [n] from SNC
    // Commit stage
    input  logic result_stored,         // Commit done                              // [n] from SNC
    // Performance monitor
    input  logic counters_ready,        // From performance_monitor snapshot        // [n] from PM
    // Flow Control
    input  logic use_relu,              // Forwarded to SNC (not used here)         // [n] from UJI

    // Forwarding Data readiness
    output logic matrices_loaded_fw,    // Forwarding out                           // to SNC [n]
    // Prefetch stage output
    output logic prefetch_start,        // 1-cycle pulse to SNC                     // to SNC [n]
    // Compute stage Status for user
    output logic exec_active,           // High during execution                    // to UJI [n]
    output logic exec_done,             // High when cycle completes                // to UJI [n]
    // Commit stage output
    output logic commit_start,          // 1-cycle pulse to SNC                     // to SNC [n]
    // Forwarding Commit stage
    output logic result_stored_fw,      // Forwarding out if commit is done         // to PM [n]
    // Forwarding Flow Control
    output logic use_relu_fw            // Forwarding out                           // to SNC [n]
);

    // FSM state encoding
    typedef enum logic [2:0] {
        IDLE      = 3'd0,
        WAIT_LOAD = 3'd1,
        PREFETCH  = 3'd2,
        COMPUTE   = 3'd3,
        COMMIT    = 3'd4,
        SNAPSHOT  = 3'd5,
        DONE      = 3'd6
    } state_t;

    state_t state, next_state;

    // State register
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic and output generation
    always_comb begin
        // Defaults
        next_state     = state;
        prefetch_start = 1'b0;
        commit_start   = 1'b0;
        exec_active    = 1'b0;
        exec_done      = 1'b0;

        // Forwarding
        use_relu_fw = use_relu;
        result_stored_fw = result_stored;
        matrices_loaded_fw = matrices_loaded; 

        case (state)
            //-------------------------------------------------------------------------
            IDLE: begin
                // Wait for host to assert start_exec
                if (start_exec)
                    next_state = WAIT_LOAD;
            end

            //-------------------------------------------------------------------------
            WAIT_LOAD: begin
                // Active while loading matrices
                exec_active = 1'b1;
                if (matrices_loaded)
                    next_state = PREFETCH;
            end

            //-------------------------------------------------------------------------
            PREFETCH: begin
                // Issue 1-cycle prefetch pulse
                exec_active    = 1'b1;
                prefetch_start = 1'b1;
                next_state     = COMPUTE;
            end

            //-------------------------------------------------------------------------
            COMPUTE: begin
                // Active only while NPU is busy computing
                exec_active = npu_busy;
                if (npu_done)
                    next_state = COMMIT;
            end

            //-------------------------------------------------------------------------
            COMMIT: begin
                // Issue 1-cycle commit pulse
                exec_active  = 1'b1;
                commit_start = 1'b1;
                // Wait until matrix_store_unit signals result written
                if (result_stored)
                    next_state = SNAPSHOT;
            end

            //-------------------------------------------------------------------------
            SNAPSHOT: begin
                // Active while waiting for performance snapshot
                exec_active = 1'b1;
                if (counters_ready)
                    next_state = DONE;
            end

            //-------------------------------------------------------------------------
            DONE: begin
                // Notify host that cycle is complete
                exec_done = 1'b1;
                // Remain until host clears with stop_exec
                if (stop_exec)
                    next_state = IDLE;
            end

            //-------------------------------------------------------------------------
            default: begin
                // Fallback to a safe state
                next_state = IDLE;
            end
        endcase
    end

endmodule
