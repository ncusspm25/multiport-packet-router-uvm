# Tool scope and limitations

## Validated toolchain

The project pins Verilator **5.054** and the official Accellera **UVM 2020.3.2**
archive. The requested Verilator baseline is 5.052 or newer. This project has been
developed against 5.054, which adds native covergroup coverage-query support.
Do not interpret the version-number gate as evidence that every 5.052 feature
works. Run both the minimal UVM smoke and the feature probe when changing tools.
The bootstrap script selects the validated version.

The original WSL installation contained Verilator 5.020. The version gate rejected
that executable before compiling UVM. No compatibility fork of UVM is substituted.
The Accellera kit is loaded with its original DPI implementation and without
`UVM_NO_DPI` or a stripped-down UVM package.

## Executed subset

The smoke checks factory registration, test construction, phasing, objections and
time advance. The feature probe checks constrained randomization through Z3,
virtual-interface traffic, native covergroup sampling and coverage queries.
The actual router testbench exercises analysis ports/FIFOs, configurable agents,
sequencer/driver handshakes, assertions, reset, random backpressure and coverage.
The simulator's full IEEE/UVM conformance suite is outside this project.

## Verification boundaries

- Verilator uses two-state simulation for this project. X/Z propagation,
  metastability, analog behavior and four-state reset checks are unverified.
- Protocol assertions are enabled in all positive and negative runs. Expected
  negatives retain their error/assertion logs and are explicitly classified.
- The RTL supports positive data widths. The directed matrix covers 1, 8, 16,
  32 and 64 bits. The full UVM coverage/mutation acceptance suite uses 32 bits.
  The three data-pattern coverage bins are intended for widths of at least two
  bits, because a one-bit payload has no mixed-bit value.
- One beat is one whole packet. Multi-beat packets, CDC, packet framing protocols,
  CRC, cut-through routing and larger port counts are outside this design.
- Ordering is checked per output in input-acceptance order. There is no global
  completion order between independently backpressured outputs.
- Reset explicitly aborts already accepted packets that are still buffered.
- Synthesizable coding style and lint are checked. Synthesis, formal proof, CDC,
  gate-level simulation, power, PPA and STA have not been executed.
- Waveform dumping is not required by the regression. The cycle/transfer CSV
  captures observed handshakes for independent checking and deterministic replay.
- Simulator process-control and virtual-interface limitations remain documented
  by the [Verilator UVM tracker](https://github.com/verilator/verilator/issues/1538).
  This repository's passing subset does not establish complete UVM support.

No assertion is disabled to make a failing testcase pass. The common `1ns/1ps`
timescale is set explicitly for the testbench and the unmodified UVM package.
Project compilation retains fatal lint warnings.
