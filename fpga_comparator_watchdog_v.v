
/******************************************************************************
 * FILE: comparator_watchdog.v
 * PURPOSE: Compares Primary vs Backup outputs and confirms persistent faults.
 *
 * HOW IT WORKS:
 *   1. COMPARATOR:
 *      - Computes |roll_a - roll_b| and |pitch_a - pitch_b| every clock cycle.
 *      - If either difference exceeds THRESHOLD, sets fault_raw = 1.
 *
 *   2. WATCHDOG TIMER:
 *      - If fault_raw stays 1 for WATCHDOG_LIMIT consecutive cycles,
 *        asserts fault_confirmed = 1.
 *      - If fault_raw goes to 0, resets the counter (it was just a glitch).
 *
 * PARAMETERS:
 *   THRESHOLD: Minimum difference in centi-degrees to consider a fault.
 *              Default = 50 (i.e., 0.50 degrees).
 *   WATCHDOG_LIMIT: Number of clock cycles fault_raw must persist.
 *                   At 27 MHz, 270000 cycles = ~10 ms.
 ******************************************************************************/

module comparator_watchdog #(
    parameter THRESHOLD     = 16'd50,     // 0.50 degree in centi-degrees
    parameter WATCHDOG_LIMIT = 32'd270000 // ~10 ms at 27 MHz
)(
    input  wire        clk,
    input  wire        rst,
    input  wire signed [15:0] roll_a,     // Primary roll
    input  wire signed [15:0] pitch_a,    // Primary pitch
    input  wire signed [15:0] roll_b,     // Backup roll
    input  wire signed [15:0] pitch_b,    // Backup pitch
    output reg         fault_confirmed    // 1 = persistent fault detected
);

    /* ---- Step 1: Compute absolute differences ---- */
    wire signed [15:0] roll_diff  = roll_a  - roll_b;
    wire signed [15:0] pitch_diff = pitch_a - pitch_b;

    // Absolute value using ternary (if negative, negate)
    wire [15:0] roll_abs  = roll_diff[15]  ? (~roll_diff  + 1) : roll_diff;
    wire [15:0] pitch_abs = pitch_diff[15] ? (~pitch_diff + 1) : pitch_diff;

    /* ---- Step 2: Check threshold ---- */
    wire fault_raw = (roll_abs > THRESHOLD) || (pitch_abs > THRESHOLD);

    /* ---- Step 3: Watchdog counter ---- */
    reg [31:0] wd_counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wd_counter      <= 32'd0;
            fault_confirmed <= 1'b0;
        end
        else begin
            if (fault_raw) begin
                // Fault detected: increment counter
                if (wd_counter < WATCHDOG_LIMIT) begin
                    wd_counter <= wd_counter + 1;
                end
                // If counter reaches limit, confirm fault
                if (wd_counter >= WATCHDOG_LIMIT) begin
                    fault_confirmed <= 1'b1;
                end
            end
            else begin
                // No fault: reset counter and clear confirmation
                wd_counter      <= 32'd0;
                fault_confirmed <= 1'b0;
            end
        end
    end

endmodule
