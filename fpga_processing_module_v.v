
/******************************************************************************
 * FILE: processing_module.v
 * PURPOSE: The "computing element" that both Primary and Backup instantiate.
 *
 * WHAT IT DOES:
 *   Simple first-order IIR low-pass filter on roll and pitch:
 *     output_new = (7 * output_old + 1 * input) / 8
 *
 *   This is equivalent to alpha = 7/8 = 0.875.
 *   Division by 8 is just a right-shift by 3 (very efficient in hardware).
 *
 * WHY IIR ON FPGA:
 *   - Demonstrates a real computation (not just passthrough).
 *   - Both Primary and Backup run this identically.
 *   - If a fault flips a bit in Primary's registers, its output diverges
 *     from Backup's output -> comparator catches it.
 *
 * PARAMETER:
 *   MODULE_ID: 0 for Primary, 1 for Backup (just for identification in sim).
 ******************************************************************************/

module processing_module #(
    parameter MODULE_ID = 0
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        data_valid,    // New input sample ready
    input  wire signed [15:0] roll_in,
    input  wire signed [15:0] pitch_in,
    output reg  signed [15:0] roll_out,
    output reg  signed [15:0] pitch_out
);

    /*
     * IIR low-pass filter:
     *   y[n] = (7 * y[n-1] + x[n]) >> 3
     *
     * We use 32-bit intermediates to avoid overflow.
     * Division by 8 = right shift by 3.
     */
    reg signed [31:0] roll_acc;
    reg signed [31:0] pitch_acc;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            roll_acc  <= 32'sd0;
            pitch_acc <= 32'sd0;
            roll_out  <= 16'sd0;
            pitch_out <= 16'sd0;
        end
        else if (data_valid) begin
            // IIR filter: accumulate = 7 * previous + 1 * new input
            roll_acc  <= (roll_acc  * 7 + {{16{roll_in[15]}},  roll_in})  >>> 3;
            pitch_acc <= (pitch_acc * 7 + {{16{pitch_in[15]}}, pitch_in}) >>> 3;

            // Output the filtered value (take lower 16 bits)
            roll_out  <= roll_acc[15:0];
            pitch_out <= pitch_acc[15:0];
        end
    end

endmodule
