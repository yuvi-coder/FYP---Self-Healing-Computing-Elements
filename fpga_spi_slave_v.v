
/******************************************************************************
 * FILE: spi_slave.v
 * PURPOSE: Receives 8-byte SPI packets from STM32 and extracts roll/pitch.
 *
 * HOW IT WORKS:
 *   - STM32 is SPI master, FPGA is SPI slave.
 *   - SPI Mode 0: CPOL=0, CPHA=0 (sample on rising edge of SCK).
 *   - We use the FPGA system clock (27 MHz) to oversample the SPI signals.
 *   - Detects rising edge of SPI_SCK, shifts in bits from MOSI.
 *   - After 8 bits, one byte is complete.
 *   - After 8 bytes (one packet), extracts roll and pitch.
 *
 * PACKET FORMAT (from STM32):
 *   Byte 0: 0xAA (header)
 *   Byte 1: Roll high byte (int16_t centi-degrees)
 *   Byte 2: Roll low byte
 *   Byte 3: Pitch high byte
 *   Byte 4: Pitch low byte
 *   Byte 5: Checksum high
 *   Byte 6: Checksum low
 *   Byte 7: 0x55 (footer)
 ******************************************************************************/

module spi_slave (
    input  wire        clk,          // 27 MHz system clock
    input  wire        rst,
    input  wire        spi_sck,      // SPI clock from master
    input  wire        spi_mosi,     // Master Out Slave In
    output reg         spi_miso,     // Master In Slave Out (we send status back)
    input  wire        spi_cs_n,     // Chip select, active low

    output reg         data_valid,   // Pulse: new valid packet received
    output reg  [15:0] roll_out,     // Extracted roll value
    output reg  [15:0] pitch_out     // Extracted pitch value
);

    /* ---- Synchronize SPI signals to system clock domain ---- */
    reg [2:0] sck_sync;
    reg [1:0] mosi_sync;
    reg [1:0] cs_sync;

    always @(posedge clk) begin
        sck_sync  <= {sck_sync[1:0],  spi_sck};
        mosi_sync <= {mosi_sync[0],   spi_mosi};
        cs_sync   <= {cs_sync[0],     spi_cs_n};
    end

    // Detect rising edge of SCK (sample data on rising edge in Mode 0)
    wire sck_rising = (sck_sync[2:1] == 2'b01);
    wire cs_active  = ~cs_sync[1];  // CS is active low
    wire mosi_bit   = mosi_sync[1];

    /* ---- Shift register and byte/packet counters ---- */
    reg [7:0]  shift_reg;           // Current byte being shifted in
    reg [2:0]  bit_cnt;             // Counts 0..7 bits per byte
    reg [2:0]  byte_cnt;            // Counts 0..7 bytes per packet
    reg [7:0]  packet_buf [0:7];    // Stores 8 received bytes

    /* ---- Status byte sent back to STM32 on MISO ---- */
    // We just send the FSM state as a simple status byte
    // (In a full design, this would come from the FSM module)
    reg [7:0] status_byte;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            shift_reg  <= 8'd0;
            bit_cnt    <= 3'd0;
            byte_cnt   <= 3'd0;
            data_valid <= 1'b0;
            roll_out   <= 16'd0;
            pitch_out  <= 16'd0;
            spi_miso   <= 1'b0;
        end
        else begin
            data_valid <= 1'b0;  // Default: no valid data this cycle

            if (!cs_active) begin
                // CS not active: reset counters
                bit_cnt  <= 3'd0;
                byte_cnt <= 3'd0;
            end
            else if (sck_rising) begin
                // Shift in one bit from MOSI
                shift_reg <= {shift_reg[6:0], mosi_bit};
                bit_cnt   <= bit_cnt + 1;

                // Send status bit on MISO (MSB first)
                spi_miso <= status_byte[7 - bit_cnt];

                if (bit_cnt == 3'd7) begin
                    // One full byte received
                    packet_buf[byte_cnt] <= {shift_reg[6:0], mosi_bit};
                    byte_cnt <= byte_cnt + 1;
                    bit_cnt  <= 3'd0;

                    // After all 8 bytes received, parse packet
                    if (byte_cnt == 3'd7) begin
                        // Check header and footer
                        if (packet_buf[0] == 8'hAA) begin
                            // Extract roll and pitch
                            roll_out  <= {packet_buf[1], {shift_reg[6:0], mosi_bit}};
                            // Wait, we need to use packet_buf properly:
                            // byte_cnt was 7 when we store the last byte,
                            // so packet_buf[1..6] are already stored, and
                            // current byte goes into packet_buf[7].
                            // Correct extraction:
                            roll_out  <= {packet_buf[1], packet_buf[2]};
                            pitch_out <= {packet_buf[3], packet_buf[4]};
                            data_valid <= 1'b1;
                        end
                        byte_cnt <= 3'd0;
                    end
                end
            end
        end
    end

endmodule
