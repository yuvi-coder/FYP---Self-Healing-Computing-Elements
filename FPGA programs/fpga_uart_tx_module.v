
/******************************************************************************
 * FILE: uart_tx_module.v
 * PURPOSE: Sends roll, pitch, and FSM state to PC via UART at 115200 baud.
 *
 * HOW IT WORKS:
 *   - Uses 27 MHz clock.
 *   - Baud rate 115200: bit period = 27_000_000 / 115200 = 234 clock cycles.
 *   - Periodically (every ~100 ms) transmits a short message:
 *       "S:<state> R:<roll> P:<pitch>\n"
 *   - Simple byte-by-byte UART TX with start bit, 8 data bits, stop bit.
 *
 * CONNECT: FPGA uart_tx pin -> CP2102 RX pin. Common GND.
 ******************************************************************************/

module uart_tx_module (
    input  wire        clk,
    input  wire        rst,
    input  wire signed [15:0] roll_val,
    input  wire signed [15:0] pitch_val,
    input  wire [2:0]  state,
    output reg         tx_out
);

    /* ---- Baud rate generator ---- */
    localparam CLKS_PER_BIT = 234;  // 27 MHz / 115200

    /* ---- TX state machine ---- */
    localparam TX_IDLE  = 3'd0;
    localparam TX_START = 3'd1;
    localparam TX_DATA  = 3'd2;
    localparam TX_STOP  = 3'd3;
    localparam TX_WAIT  = 3'd4;

    reg [2:0]  tx_state;
    reg [7:0]  tx_byte;
    reg [7:0]  clk_cnt;
    reg [2:0]  bit_idx;

    /* ---- Message buffer ---- */
    // Simple: send state byte + roll high + roll low + pitch high + pitch low + newline
    reg [7:0] msg_buf [0:5];
    reg [2:0] msg_idx;
    reg [2:0] msg_len;

    /* ---- Periodic trigger (~10 Hz = every ~2.7M clocks) ---- */
    reg [21:0] period_cnt;
    reg        send_trigger;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            period_cnt   <= 0;
            send_trigger <= 0;
        end else begin
            send_trigger <= 0;
            if (period_cnt >= 22'd2700000) begin
                period_cnt   <= 0;
                send_trigger <= 1;
            end else begin
                period_cnt <= period_cnt + 1;
            end
        end
    end

    /* ---- Load message buffer on trigger ---- */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            msg_buf[0] <= 8'h00;
            msg_buf[1] <= 8'h00;
            msg_buf[2] <= 8'h00;
            msg_buf[3] <= 8'h00;
            msg_buf[4] <= 8'h00;
            msg_buf[5] <= 8'h0A;  // newline
            msg_len    <= 3'd6;
        end else if (send_trigger && tx_state == TX_IDLE) begin
            msg_buf[0] <= {5'b0, state};               // FSM state (0-4)
            msg_buf[1] <= roll_val[15:8];               // Roll high byte
            msg_buf[2] <= roll_val[7:0];                // Roll low byte
            msg_buf[3] <= pitch_val[15:8];              // Pitch high byte
            msg_buf[4] <= pitch_val[7:0];               // Pitch low byte
            msg_buf[5] <= 8'h0A;                        // Newline
            msg_len    <= 3'd6;
        end
    end

    /* ---- UART TX state machine ---- */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_out   <= 1'b1;  // UART idle = high
            clk_cnt  <= 0;
            bit_idx  <= 0;
            msg_idx  <= 0;
        end else begin
            case (tx_state)
                TX_IDLE: begin
                    tx_out <= 1'b1;
                    if (send_trigger) begin
                        msg_idx  <= 0;
                        tx_byte  <= msg_buf[0];
                        tx_state <= TX_START;
                        clk_cnt  <= 0;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0;  // Start bit = low
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt  <= 0;
                        bit_idx  <= 0;
                        tx_state <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    tx_out <= tx_byte[bit_idx];  // LSB first
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            tx_state <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    tx_out <= 1'b1;  // Stop bit = high
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        // Move to next byte in message
                        if (msg_idx < msg_len - 1) begin
                            msg_idx  <= msg_idx + 1;
                            tx_byte  <= msg_buf[msg_idx + 1];
                            tx_state <= TX_START;
                        end else begin
                            tx_state <= TX_IDLE;
                        end
                    end
                end

                default: tx_state <= TX_IDLE;
            endcase
        end
    end

endmodule
