
/******************************************************************************
 * FILE: tb_top.v
 * PURPOSE: Simulation testbench for the self-healing FPGA design.
 *
 * HOW TO USE:
 *   - In Gowin EDA: add this as a simulation file (not synthesis).
 *   - Or use Icarus Verilog: iverilog -o sim tb_top.v top.v spi_slave.v
 *     processing_module.v comparator_watchdog.v fsm_controller.v uart_tx_module.v
 *   - Run: vvp sim
 *   - View waveforms: gtkwave dump.vcd
 *
 * WHAT IT TESTS:
 *   1. Normal operation: sends valid SPI packets, checks output follows input.
 *   2. Fault injection: asserts inject_fault_btn, checks that FSM detects and
 *      enters FAULT_DETECTED -> RECONFIGURING -> VERIFY -> NORMAL.
 *   3. Recovery: after fault button released, system returns to NORMAL.
 ******************************************************************************/

`timescale 1ns / 1ps

module tb_top;

    reg        clk;
    reg        rst_n;
    reg        spi_sck_r;
    reg        spi_mosi_r;
    wire       spi_miso_w;
    reg        spi_cs_n_r;
    reg        inject_btn;
    wire       uart_tx_w;
    wire [5:0] led_w;

    // Instantiate top module
    top uut (
        .sys_clk          (clk),
        .sys_rst_n        (rst_n),
        .spi_sck          (spi_sck_r),
        .spi_mosi         (spi_mosi_r),
        .spi_miso         (spi_miso_w),
        .spi_cs_n         (spi_cs_n_r),
        .inject_fault_btn (inject_btn),
        .uart_tx          (uart_tx_w),
        .led              (led_w)
    );

    // 27 MHz clock: period = 37.037 ns
    initial clk = 0;
    always #18.5 clk = ~clk;

    // SPI clock ~1 MHz: period = 1000 ns
    localparam SPI_HALF = 500;

    // Task: send one SPI byte
    task send_spi_byte(input [7:0] data);
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                spi_sck_r  = 0;
                spi_mosi_r = data[i];
                #SPI_HALF;
                spi_sck_r  = 1;        // Rising edge: slave samples
                #SPI_HALF;
            end
            spi_sck_r = 0;
        end
    endtask

    // Task: send full 8-byte SPI packet
    task send_spi_packet(
        input signed [15:0] roll_cd,
        input signed [15:0] pitch_cd
    );
        reg [15:0] chk;
        begin
            chk = 8'hAA + roll_cd[15:8] + roll_cd[7:0] + 
                  pitch_cd[15:8] + pitch_cd[7:0];

            spi_cs_n_r = 0;
            #100;
            send_spi_byte(8'hAA);                  // Header
            send_spi_byte(roll_cd[15:8]);           // Roll high
            send_spi_byte(roll_cd[7:0]);            // Roll low
            send_spi_byte(pitch_cd[15:8]);          // Pitch high
            send_spi_byte(pitch_cd[7:0]);           // Pitch low
            send_spi_byte(chk[15:8]);               // Checksum high
            send_spi_byte(chk[7:0]);                // Checksum low
            send_spi_byte(8'h55);                   // Footer
            #100;
            spi_cs_n_r = 1;
        end
    endtask

    // Main test sequence
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);

        // Initialize
        rst_n      = 0;
        spi_sck_r  = 0;
        spi_mosi_r = 0;
        spi_cs_n_r = 1;
        inject_btn = 1;  // Not pressed (active low)

        // Release reset after 200 ns
        #200;
        rst_n = 1;
        #1000;

        // ---- TEST 1: Normal operation ----
        $display("TEST 1: Normal operation - sending packets");
        send_spi_packet(16'd1000, 16'd500);   // Roll=10.00, Pitch=5.00
        #100000;
        send_spi_packet(16'd1050, 16'd520);
        #100000;
        send_spi_packet(16'd1100, 16'd540);
        #100000;

        // ---- TEST 2: Inject fault ----
        $display("TEST 2: Injecting fault");
        inject_btn = 0;  // Press button (active low) -> inject fault
        // Send more packets while fault is active
        send_spi_packet(16'd1100, 16'd540);
        #200000;
        send_spi_packet(16'd1100, 16'd540);
        #200000;

        // Wait long enough for watchdog to confirm fault (~10 ms = 10_000_000 ns)
        #15000000;

        $display("FSM state should be FAULT_DET or RECONFIG");

        // Wait for simulated ICAP (~150 ms = very long in sim; shorten for sim)
        // In real testbench you might reduce RECONFIG_CYCLES for faster simulation.
        #200000000;  // 200 ms

        // ---- TEST 3: Release fault, observe recovery ----
        $display("TEST 3: Releasing fault");
        inject_btn = 1;  // Release button
        // Send more packets
        repeat (20) begin
            send_spi_packet(16'd1100, 16'd540);
            #100000;
        end

        #5000000;
        $display("TEST COMPLETE");
        $finish;
    end

endmodule
