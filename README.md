# AMBA APB-Integrated Mini-TPU Accelerator

![Status](https://img.shields.io/badge/Status-Verified-success)
![Bus](https://img.shields.io/badge/Bus-AMBA_APB-blue)

This repo holds a custom Tensor Processing Unit (TPU) core integrated with an industry-standard AMBA APB memory-mapped bus wrapper. It is a small systolic-array matrix multiplier designed from scratch, verified cycle-by-cycle against a NumPy golden model, and cleanly simulated to prove seamless master-slave System-on-Chip (SoC) communication.

---

### Motivation

As an EE student, I noticed a gap between studying digital logic in class and understanding how hardware components actually communicate in modern System-on-Chip designs. While my classes gave me the theory for the compute logic, I took this project on to get hands-on with real industry bus protocols and cycle-accurate verification testbenches. 

I wanted to write a systolic array, prove the math works, and then wrap it in a standard AMBA APB interface to simulate exactly how this IP block would drop into a larger SoC hierarchy.

## Architecture

### The AMBA APB System Wrapper (`apb_system_wrapper.v`)
The TPU is entirely encapsulated within a 32-bit AMBA APB bus interface, meaning it acts as a standard memory-mapped peripheral. It decodes standard APB signals (`PSEL`, `PENABLE`, `PWRITE`, `PADDR`) to route data into the internal memory or read the status registers. 
* Writing to `0x00` - `0x0C` loads the 2x2 Weight Matrix (Matrix A).
* Writing to `0x10` - `0x1C` loads the 2x2 Input Matrix (Matrix B).
* Writing to `0x20` triggers the `start` flag to kick off the TPU computation.
* Polling `0x24` allows a master device to check the `tpu_done` flag before reading back the results.

### The Processing Element (PE)
At the core of the accelerator is the Processing Element (`mac.v`). Unlike a normal CPU core that deals with branching and memory, a PE is specialized to do exactly one thing: Multiply-Accumulate (MAC).

* **The Operation:** `result <= result + (a * b)`, computed every cycle `en` is asserted.
* Four of these are instantiated to form the 2x2 array.

### The Systolic Array (`systolic_2x2.v`)
The four PEs are wired into a 2x2 grid where each one is fixed in place and accumulates a single output element (`result_00` to `result_11`). This makes it closer to an **output-stationary** array than a weight-stationary one. Both the input matrix (`A`, coming from the left) and the weight matrix (`B`, coming from the top) stream in together. They are skewed by one clock cycle per row so each PE gets the right operands on the right cycle.

### Control & Memory
`control_fsm.v` is a basic 3-state FSM (`IDLE -> COMPUTE -> DONE`). It walks a step counter from 0 to 6 on `start`, sequences reads out of a small block-RAM (`bsram.v`), and drives the systolic array's enable window. This ensures the pre-packed, skewed rows hit the array at the exact right cycle, and then holds the array enabled for a few extra cycles to flush the pipeline before firing the `done` signal.

## Simulation & Verification

Hardware is unforgiving, so proving the logic gates and bus protocols worked in software was the primary focus of this project.

* **Cycle-Accurate AMBA Testbench:** `tb_apb_wrapper.v` verifies the full SoC integration at a 100 MHz simulated clock frequency. It utilizes encapsulated Verilog tasks (`apb_write`, `apb_read`) to drive the `PSEL` setup and `PENABLE` access phases, writes the matrices into memory, triggers the FSM, polls the status register, and reads back the computed hex values. 
* **Randomized golden-model regression:** Powered by Cocotb and `test_mini_tpu.py`. This generates a fresh random 2x2 input pair every run, calculates the expected result with NumPy, drives the DUT, and asserts that the hardware output matches perfectly.
* **Elaboration Debugging:** Resolved critical X-propagation errors caused by uninitialized block RAMs (`$readmemh` faults) and disconnected internal data paths during the APB integration phase.

## Roadmap

* **Scale up to AMBA AXI:** The current APB bus is great for simple memory-mapped control, but migrating the wrapper to AXI4 would allow for burst transfers, significantly increasing the throughput for loading larger matrices.
* **BRAM routing & matrix scaling:** Moving weight and input buffers explicitly into dedicated Block RAM instead of distributed logic is the next architectural step to scale this past a 2x2 array.
