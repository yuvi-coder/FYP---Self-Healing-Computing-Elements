
/******************************************************************************
 * FILE: fsm_controller.v
 * PURPOSE: Manages the self-healing recovery process.
 *
 * STATES:
 *   S_NORMAL (0):       Both modules running, output from Primary.
 *   S_FAULT_DET (1):    Fault confirmed. Switch MUX to Backup. Start ICAP.
 *   S_RECONFIG (2):     ICAP is reloading Primary bitstream from Flash.
 *                        (Simulated here with a timer countdown.)
 *   S_VERIFY (3):       ICAP done. Check that Primary matches Backup again.
 *   S_ERROR (4):        Recovery failed (optional safety state).
 *
 * OUTPUTS:
 *   use_backup: 1 = MUX selects Backup output; 0 = MUX selects Primary.
 *   icap_start: Pulse to start ICAP controller (one cycle high).
 *   icap_done_out: Simulated ICAP completion signal (for demo).
 *   state_out: Current state for LED display and logging.
 *
 * NOTE ON ICAP:
 *   In this demo version, ICAP reconfiguration is SIMULATED with a
 *   ~150 ms timer (about 4,050,000 cycles at 27 MHz).
 *   In a real system, you would connect icap_start to an actual ICAP
 *   controller module that reads from SPI Flash and writes to ICAP port.
 ******************************************************************************/

module fsm_controller (
    input  wire       clk,
    input  wire       rst,
    input  wire       fault_confirmed,  // From comparator+watchdog
    input  wire       icap_done,        // From ICAP controller (or self-loop)

    output reg        use_backup,       // MUX control
    output reg        icap_start,       // Start ICAP reload
    output reg        icap_done_out,    // Simulated ICAP done signal
    output reg [2:0]  state_out         // Current FSM state
);

    /* ---- State encoding ---- */
    localparam S_NORMAL    = 3'd0;
    localparam S_FAULT_DET = 3'd1;
    localparam S_RECONFIG  = 3'd2;
    localparam S_VERIFY    = 3'd3;
    localparam S_ERROR     = 3'd4;

    /* ---- Internal registers ---- */
    reg [2:0]  state, next_state;
    reg [23:0] reconfig_timer;   // Counts cycles during simulated reconfig
    reg [3:0]  verify_counter;   // Counts consecutive matching samples

    /* ---- Simulated ICAP timer parameters ---- */
    // ~150 ms at 27 MHz = 4,050,000 cycles. Use 24-bit counter.
    localparam RECONFIG_CYCLES = 24'd4050000;

    // Verification: require 10 consecutive matches after reconfig
    localparam VERIFY_MATCHES  = 4'd10;

    /* ==================== STATE REGISTER (sequential) ===================== */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_NORMAL;
        end else begin
            state <= next_state;
        end
    end

    /* ==================== RECONFIG TIMER (sequential) ===================== */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reconfig_timer <= 24'd0;
            icap_done_out  <= 1'b0;
        end
        else begin
            icap_done_out <= 1'b0;  // Default

            if (state == S_RECONFIG) begin
                if (reconfig_timer < RECONFIG_CYCLES) begin
                    reconfig_timer <= reconfig_timer + 1;
                end else begin
                    icap_done_out  <= 1'b1;  // Reconfig simulation complete
                    reconfig_timer <= 24'd0;
                end
            end else begin
                reconfig_timer <= 24'd0;
            end
        end
    end

    /* ==================== VERIFY COUNTER (sequential) ===================== */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            verify_counter <= 4'd0;
        end
        else begin
            if (state == S_VERIFY) begin
                if (!fault_confirmed) begin
                    // Outputs match (no fault): count up
                    if (verify_counter < VERIFY_MATCHES)
                        verify_counter <= verify_counter + 1;
                end else begin
                    // Still mismatching: reset counter
                    verify_counter <= 4'd0;
                end
            end else begin
                verify_counter <= 4'd0;
            end
        end
    end

    /* ==================== NEXT-STATE + OUTPUT LOGIC (combinational) ======= */
    always @* begin
        // Defaults
        next_state  = state;
        use_backup  = 1'b0;
        icap_start  = 1'b0;

        case (state)
            S_NORMAL: begin
                use_backup = 1'b0;      // Use Primary
                if (fault_confirmed) begin
                    next_state = S_FAULT_DET;
                end
            end

            S_FAULT_DET: begin
                use_backup = 1'b1;      // Switch to Backup immediately
                icap_start = 1'b1;      // Start ICAP reload (one cycle)
                next_state = S_RECONFIG;
            end

            S_RECONFIG: begin
                use_backup = 1'b1;      // Keep Backup during reconfig
                if (icap_done) begin
                    next_state = S_VERIFY;
                end
            end

            S_VERIFY: begin
                use_backup = 1'b1;      // Still Backup while verifying
                if (verify_counter >= VERIFY_MATCHES) begin
                    next_state = S_NORMAL;  // Primary is healthy again
                end
                // Optional: add timeout -> S_ERROR
            end

            S_ERROR: begin
                use_backup = 1'b1;      // Stay on Backup
                // Could add a reset mechanism here
                next_state = S_ERROR;
            end

            default: next_state = S_NORMAL;
        endcase
    end

    /* ---- Export state for LEDs and logging ---- */
    always @* begin
        state_out = state;
    end

endmodule
