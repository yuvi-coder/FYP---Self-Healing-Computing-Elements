## Memory
* SDRAM (Synchronous Dynamic RAM) is fast, volatile memory for active programs, losing data without power, while Flash memory is slower, non-volatile storage for persistent data (OS, files) in devices like SSDs and USB drives, retaining info without power.
* SDRAM acts as the computer's short-term "working memory," while Flash serves as long-term storage, with both technologies crucial for different functions in a system, balancing speed, cost, and data persistence. 

## Buffer
* In digital electronics, a buffer is a simple circuit (often a logic gate) that copies a digital input signal to its output without changing its logic level (0 remains 0, 1 remains 1) but provides increased current-driving capability, acting as a non-inverting amplifier.
* Its primary functions are isolation (preventing one circuit's impedance from affecting another) and power amplification (increasing fan-out to drive more loads or higher current devices like LEDs).
* Tri-state buffers add an enable/disable control, allowing output to be disconnected (high-impedance state), crucial for data buses. 

## Bitstream
* A bitstream is a file that describes the physical hardware configuration and interconnections of the FPGA's logic gates, effectively turning the blank chip into a specific, custom hardware circuit. 
* In many modern boards, a dedicated microcontroller (e.g., Cypress FX2/FX3, or an integrated soft-core processor like a NIOS or Zynq ARM core) runs actual firmware, and this firmware, in turn, manages the FPGA's bitstream loading process.

## Skew
* In electronics, skew primarily refers to clock skew, the unwanted time difference when a clock signal arrives at different parts of a digital circuit, causing timing issues like data arriving too early or late for setup/hold violations.
* It's caused by varying wire lengths, propagation delays, and buffer delays in the clock distribution network.
* While harmful, designers use techniques like H-trees and PLLs to manage it, sometimes even introducing "useful skew" to meet timing requirements. 

## Constraint file
* A constraint file in FPGA/VLSI design is a crucial text file that guides Electronic Design Automation (EDA) tools, mapping logical nets to physical pins, defining timing (clocks, I/O delays), power, and area requirements, making the HDL code "hardware-ready" by translating abstract designs into physical implementation rules for synthesis, place & route, and timing analysis.
* Common formats include XDC (Xilinx Design Constraints for Vivado), SDC (Synopsys Design Constraints for ASICs), and older ones like UCF (User Constraints File for ISE). 

## PLL - Phase-Locked Loop
* In electronics, a Phase-Locked Loop (PLL) is a feedback control system that generates an output signal whose phase (and frequency) is synchronized to an input reference signal, effectively locking them together, and it's used for frequency synthesis, clock recovery, and signal demodulation in everything from radios to Wi-Fi.
* It works by comparing the phase of the input with its own generated signal (from a Voltage-Controlled Oscillator, or VCO) and continuously adjusting the VCO's frequency until the phases match, forming a closed loop. 

## Verliog and VHDL
* VHDL and Verilog are Hardware Description Languages (HDLs) for designing digital circuits, differing mainly in syntax, typing, and common usage: VHDL is strongly typed, verbose (Ada-like), popular in Europe/defense/academia for large systems (ASICs, FPGAs), while Verilog is weakly typed, C-like, more concise, prevalent in US industry/ASICs, with SystemVerilog now dominant for verification. VHDL offers strict type safety, catching errors early, while Verilog is quicker to write but can hide subtle bugs.
* Both describe concurrency, but VHDL uses entity/architecture, Verilog uses module, and learning one aids the other.

## FPU - Floating-Point Unit
* A Floating-Point Unit (FPU), sometimes called a math coprocessor, is a specialized circuit within a computer's processor (CPU or GPU) designed specifically to handle floating-point numbers—numbers with decimal points or very large/small values (e.g., 3.14159, -0.0000001, 1.2 x 10^30).
* Unlike a standard Arithmetic Logic Unit (ALU), which handles integer arithmetic, the FPU is optimized to perform complex, high-precision mathematical operations—such as multiplication, division, addition, and square roots—directly in hardware. 
### Why the FPU is More Important :
* The FPU is crucial because it significantly boosts the speed and efficiency of numerical computing, which is essential for modern applications.
* Without a dedicated FPU, the main processor would have to emulate these calculations in software, a process that is much slower, more power-hungry, and requires more code space. 
### Drastic Performance Boost:
* An FPU can perform complex calculations (like multiplication) in a single cycle, whereas doing the same task in software could take hundreds.
* High-Precision Demands: The FPU uses IEEE 754 standards, ensuring accurate handling of fractional and decimal numbers necessary for engineering simulations and financial calculations.
* Multimedia and Gaming Acceleration: Modern graphics cards, video games, and video/audio processing rely heavily on 3D physics and real-time calculations.
* A strong FPU ensures smooth, high-speed performance.
### Energy Efficiency:
* By handling intense calculations in dedicated hardware, the CPU can complete tasks faster and return to a lower-power state, extending battery life in mobile devices.
* Parallel Processing (SIMD): Modern FPUs (like those using SSE or AVX instructions) can process multiple data points simultaneously (Single Instruction, Multiple Data), accelerating AI, machine learning, and complex scientific tasks.
* In essence, while a CPU acts as the general-purpose, decision-making engine, the FPU is the specialized, high-performance math engine that makes modern multimedia, 3D graphics, and scientific applications possible
