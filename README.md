# AMBA APB-Integrated Mini-TPU Accelerator

![Status](https://img.shields.io/badge/Status-Verified-success)
![Bus](https://img.shields.io/badge/Bus-AMBA_APB-blue)

This repo contains a custom Tensor Processing Unit (TPU) core that I designed and wrapped in a standard AMBA APB bus. I built this to get hands-on experience with System-on-Chip (SoC) integration and automated Python verification.
---

### Motivation

In my digital logic classes, we spend a lot of time on theory and building standalone ALUs. But there is a huge gap between academic labs and understanding how different hardware IP blocks actually communicate in the real world. 

I wanted to design a systolic array, prove the math worked, and then figure out how to integrate it into an industry-standard AMBA APB interface so it acts just like a real memory-mapped peripheral.

## Architecture

### The AMBA APB System Wrapper (`apb_system_wrapper.v`)
The TPU is completely wrapped inside a 32-bit AMBA APB bus interface. It decodes the standard APB signals (`PSEL`, `PENABLE`, `PWRITE`, `PADDR`) to route data into the internal RAM or read the status registers. Here is the memory map I set up:
* Writing to `0x00` - `0x0C` loads the 2x2 Weight Matrix (Matrix A).
* Writing to `0x10` - `0x1C` loads the 2x2 Input Matrix (Matrix B).
* Writing to `0x20` triggers the `start` flag to kick off the TPU computation.
* Polling `0x24` lets the master device check the `tpu_done` flag before reading back the results.

### The Processing Element (PE)
At the core of the accelerator is the Processing Element (`mac.v`). Unlike a normal CPU core that deals with branching, a PE is specialized to do exactly one thing: Multiply-Accumulate (MAC).

* **The Operation:** `result <= result + (a * b)`, computed every cycle the `en` signal is high.
* I instantiated four of these to form the 2x2 grid.

### The Systolic Array (`systolic_2x2.v`)
The four PEs are wired into an output-stationary 2x2 grid, meaning each PE is fixed in place and accumulates a single output element (`result_00` to `result_11`). Both the input matrix (`A`) and the weight matrix (`B`) stream in together. They are skewed by one clock cycle per row so each PE gets the right operands on the exact right cycle.

### Control & Memory
`control_fsm.v` is a standard 3-state Moore FSM (`IDLE -> COMPUTE -> DONE`). It uses a step counter to sequence reads out of a small block-RAM (`bsram.v`) and drives the systolic array's enable window. This makes sure the pre-packed, skewed rows hit the array perfectly, and holds the pipeline open just long enough to flush the final math before firing the `done` signal.

## Simulation & Debugging

Hardware is super unforgiving, so getting the simulations completely clean was the main focus of this project.

* **Verilog APB Testbench:** I wrote `tb_apb_wrapper.v` to simulate a 100 MHz clock. I used standard Verilog tasks (`apb_write`, `apb_read`) to mimic the setup and access phases of the bus protocol, load the matrices into memory, trigger the FSM, poll the status register, and read back the final hex values. 
* **Automated Python/Cocotb Verification:** Instead of just staring at GTKWave all day, I used Cocotb to generate random 2x2 matrices (`test_mini_tpu.py`), calculate the expected answer using NumPy, and automatically assert that the hardware output matched exactly.
* **Squashing Elaboration Bugs:** Tracking down floating `x` states in simulation was a pain. I eventually resolved them by fixing uninitialized block RAMs (a `$readmemh` file path issue) and tying off disconnected internal wires during the APB integration.

## Roadmap

* **Scale up to AMBA AXI:** The APB bus is great for simple control registers, but moving to an AXI4 wrapper would allow for burst transfers, which would make loading matrices way faster.
* **BRAM routing & scaling:** Moving the buffers explicitly into dedicated Block RAM instead of using distributed logic is the next step to scale this past a 2x2 array without running out of resources.
