# FYP---Self-Healing-Computing-Elements
FPGA - Microcontrollers - Digital Design : project 

Our project implements a self‑healing computing system that can detect hardware faults in real time and recover automatically within about 160 milliseconds fast enough that the user or external system does not notice any interruption. 
Two identical computation modules run in parallel, their outputs are continuously compared, and any mismatch is treated as a fault indicator. 
A hardware watchdog and state machine then confirm the fault and trigger partial reconfiguration of the FPGA, switching cleanly to a healthy backup path. 
The goal is to bring this kind of fast, autonomous fault tolerance usually seen only in expensive aerospace and defense systems into low‑cost, educational, and commercial FPGA designs.
