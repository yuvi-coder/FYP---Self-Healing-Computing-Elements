
/******************************************************************************
 * FILE: top.v
 * PROJECT: Self-Healing FPGA - Tang Nano 9K Top Module
 *
 * WHAT THIS FILE DOES:
 *   Instantiates all sub-modules and connects them together:
 *     1. SPI Slave   - receives sensor data from STM32
 *     2. Primary Module  - complementary filter (or processing block)
 *     3. Backup Module   - identical copy of Primary
 *     4. Comparator      - detects divergence between Primary and Backup
 *     5. Watchdog Timer  - confirms persistent faults
 *     6. FSM Controller  - manages recovery states
 *     7. Output MUX      - selects Primary or Backup output
 *     8. Fault Injector  - for testing (injects fault into Primary)
 *     9. UART TX         - sends status/angles to PC for logging
 *
 * TOOL: Gowin EDA (GOWIN FPGA Designer)
 * BOARD: Sipeed Tang Nano 9K (GW1NR-9C, QFN88)
 *
 * PIN ASSIGNMENTS (set in Gowin FloorPlanner or .cst file):
 *   Pin 52 = sys_clk (27 MHz onboard oscillator)
 *   Pin 4  = sys_rst_n (active-low reset, directly connected to onboard button S1)
 *   Pin 3  = inject_fault_btn (use onboard button S2 to inject fault)
 *   Pin 25 = spi_sck   (from STM32 PA5)
 *   Pin 26 = spi_mosi  (from STM32 PA7)
 *   Pin 27 = spi_miso  (to STM32 PA6)
 *   Pin 28 = spi_cs_n  (from STM32 PA4)
 *   Pin 17 = uart_tx   (to CP2102 RX, directly from FPGA for status logging)
 *   Pin 10 = led[0]    (onboard LED: ON = normal state)
 *   Pin 11 = led[1]    (onboard LED: ON = fault detected)
 *   Pin 13 = led[2]    (onboard LED: ON = reconfiguring)
 *   Pin 14 = led[3]    (onboard LED: ON = recovered)
 *   Pin 15 = led[4]    (onboard LED: ON = error state)
 *   Pin 16 = led[5]    (onboard LED: blink = heartbeat)
 ******************************************************************************/

module top (
    /* Clock and Reset */
    input  wire       sys_clk,       // 27 MHz onboard clock (Pin 52)
    input  wire       sys_rst_n,     // Active-low reset button S1 (Pin 4)

    /* SPI interface to STM32 */
    input  wire       spi_sck,       // SPI clock from STM32 (Pin 25)
    input  wire       spi_mosi,      // Master Out Slave In (Pin 26)
    output wire       spi_miso,      // Master In Slave Out (Pin 27)
    input  wire       spi_cs_n,      // Chip select, active low (Pin 28)

    /* Fault injection button */
    input  wire       inject_fault_btn, // Onboard button S2 (Pin 3), active low

    /* UART TX to PC */
    output wire       uart_tx,       // UART transmit to CP2102 (Pin 17)

    /* Onboard LEDs (active low on Tang Nano 9K) */
    output wire [5:0] led            // 6 LEDs (Pins 10-16)
);

    /* ========================== ACTIVE-HIGH RESET ========================= */
    wire rst = ~sys_rst_n;           // Convert active-low button to active-high

    /* ========================== SPI RECEIVE DATA ========================== */
    wire        spi_data_valid;      // Pulses when a complete packet is received
    wire [15:0] roll_in;             // Roll in centi-degrees from STM32
    wire [15:0] pitch_in;            // Pitch in centi-degrees from STM32

    spi_slave u_spi_slave (
        .clk        (sys_clk),
        .rst        (rst),
        .spi_sck    (spi_sck),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso),
        .spi_cs_n   (spi_cs_n),
        .data_valid (spi_data_valid),
        .roll_out   (roll_in),
        .pitch_out  (pitch_in)
    );

    /* ========================== PRIMARY MODULE ============================= */
    /*
     * Processing block. For the first version, this does a simple
     * low-pass filter (IIR) on the incoming roll/pitch values.
     * Both Primary and Backup are IDENTICAL modules.
     */
    wire signed [15:0] roll_primary, pitch_primary;

    processing_module #(.MODULE_ID(0)) u_primary (
        .clk        (sys_clk),
        .rst        (rst),
        .data_valid (spi_data_valid),
        .roll_in    (roll_in),
        .pitch_in   (pitch_in),
        .roll_out   (roll_primary),
        .pitch_out  (pitch_primary)
    );

    /* ========================== BACKUP MODULE ============================== */
    wire signed [15:0] roll_backup, pitch_backup;

    processing_module #(.MODULE_ID(1)) u_backup (
        .clk        (sys_clk),
        .rst        (rst),
        .data_valid (spi_data_valid),
        .roll_in    (roll_in),
        .pitch_in   (pitch_in),
        .roll_out   (roll_backup),
        .pitch_out  (pitch_backup)
    );

    /* ========================== FAULT INJECTION ============================ */
    /*
     * For demonstration: when inject_fault_btn is pressed (active low),
     * we XOR a bit pattern into Primary output to simulate a fault.
     * This makes Primary output different from Backup, so comparator detects it.
     */
    wire inject_active = ~inject_fault_btn;  // Active when button pressed

    wire signed [15:0] roll_primary_maybe_faulty;
    wire signed [15:0] pitch_primary_maybe_faulty;

    assign roll_primary_maybe_faulty  = inject_active ? 
                                        (roll_primary  ^ 16'h00FF) : roll_primary;
    assign pitch_primary_maybe_faulty = inject_active ? 
                                        (pitch_primary ^ 16'h00FF) : pitch_primary;

    /* ========================== COMPARATOR + WATCHDOG ====================== */
    wire fault_confirmed;

    comparator_watchdog u_cmp_wd (
        .clk            (sys_clk),
        .rst            (rst),
        .roll_a         (roll_primary_maybe_faulty),
        .pitch_a        (pitch_primary_maybe_faulty),
        .roll_b         (roll_backup),
        .pitch_b        (pitch_backup),
        .fault_confirmed(fault_confirmed)
    );

    /* ========================== FSM CONTROLLER ============================= */
    wire       use_backup;
    wire       icap_start;
    wire [2:0] fsm_state;

    // For this demo, ICAP done is simulated with a timer (see fsm_controller).
    // In a real system, ICAP hardware would assert this.
    wire icap_done;

    fsm_controller u_fsm (
        .clk             (sys_clk),
        .rst             (rst),
        .fault_confirmed (fault_confirmed),
        .icap_done       (icap_done),
        .use_backup      (use_backup),
        .icap_start      (icap_start),
        .icap_done_out   (icap_done),
        .state_out       (fsm_state)
    );

    /* ========================== OUTPUT MUX ================================= */
    wire signed [15:0] roll_out_final;
    wire signed [15:0] pitch_out_final;

    assign roll_out_final  = use_backup ? roll_backup  : roll_primary_maybe_faulty;
    assign pitch_out_final = use_backup ? pitch_backup : pitch_primary_maybe_faulty;

    /* ========================== UART TX TO PC =============================== */
    /*
     * Periodically sends: state, roll_out, pitch_out over UART at 115200 baud.
     * Connect FPGA Pin 17 (uart_tx) to CP2102 RX directly.
     */
    uart_tx_module u_uart (
        .clk       (sys_clk),
        .rst       (rst),
        .roll_val  (roll_out_final),
        .pitch_val (pitch_out_final),
        .state     (fsm_state),
        .tx_out    (uart_tx)
    );

    /* ========================== LED STATUS ================================== */
    /*
     * Tang Nano 9K LEDs are active LOW (LED on when pin = 0).
     */
    reg [23:0] heartbeat_cnt;
    always @(posedge sys_clk or posedge rst) begin
        if (rst) heartbeat_cnt <= 0;
        else     heartbeat_cnt <= heartbeat_cnt + 1;
    end

    assign led[0] = ~(fsm_state == 3'd0);  // LED0: NORMAL state
    assign led[1] = ~(fsm_state == 3'd1);  // LED1: FAULT_DETECTED
    assign led[2] = ~(fsm_state == 3'd2);  // LED2: RECONFIGURING
    assign led[3] = ~(fsm_state == 3'd3);  // LED3: VERIFY
    assign led[4] = ~(fsm_state == 3'd4);  // LED4: ERROR
    assign led[5] = ~heartbeat_cnt[23];    // LED5: heartbeat blink (~1.6 Hz)

endmodule
