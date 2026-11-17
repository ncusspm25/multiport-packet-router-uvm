# Measured coverage

Native covergroup bins are read from merged Verilator coverage data.
Ignore bins represent idle sampling values and are excluded by their native metadata.
Only `rtl/packet_router.sv` contributes to the RTL counter table.

Functional bins hit: **21/21**.

| Native functional bin | Hits |
| --- | ---: |
| route_cp.i0_o0 | 6199 |
| route_cp.i0_o1 | 6233 |
| route_cp.i1_o0 | 6141 |
| route_cp.i1_o1 | 6259 |
| contention_cp.o0_i0 | 1058 |
| contention_cp.o0_i1 | 1017 |
| contention_cp.o1_i0 | 974 |
| contention_cp.o1_i1 | 1038 |
| stall_cp.output0 | 8610 |
| stall_cp.output1 | 8217 |
| reset_cp.pending_traffic | 2 |
| data_cp.zero | 35 |
| data_cp.ones | 35 |
| data_cp.mixed | 24762 |
| scenario_cp.single | 3 |
| scenario_cp.simultaneous | 2 |
| scenario_cp.contention | 2 |
| scenario_cp.backpressure | 2 |
| scenario_cp.reset_traffic | 2 |
| scenario_cp.random_traffic | 5 |
| scenario_cp.stress | 2 |

| RTL counter type | Covered | Total | Percent |
| --- | ---: | ---: | ---: |
| branch | 10 | 10 | 100.0% |
| line | 7 | 7 | 100.0% |
| toggle | 292 | 292 | 100.0% |

These are instrumentation-counter results. They do not establish exhaustive functional
correctness, formal proof, or X-propagation coverage. Raw merged data and LCOV output
are generated in the build directory's `coverage/` folder.
