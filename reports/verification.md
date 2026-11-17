# Executed verification results

Run timestamp (UTC): 2026-11-17T18:58:22.660501+00:00

Simulator: `Verilator 5.054 2026-11-01 rev v5.054`. UVM: Accellera **2020.3.2** with DPI enabled.

Toolchain sources and immutable checksums are recorded in `toolchain.lock.json`.

- Minimal UVM smoke and feature probes passed.
- RTL directed matrix passed **25** runs across widths 1, 8, 16, 32 and 64.
- UVM/Python-oracle positive runs passed **13** runs.
- Expected-negative checks detected **7** defects/protocol violations.
- Native functional coverage hit **21/21** bins.

## Positive UVM runs

| Run | Seed | Cycles | Accepted | Delivered | Reset-aborted |
| --- | ---: | ---: | ---: | ---: | ---: |
| single | 1 | 132 | 64 | 64 | 0 |
| simultaneous | 1 | 100 | 64 | 64 | 0 |
| contention | 1 | 131 | 64 | 64 | 0 |
| backpressure | 1 | 135 | 64 | 64 | 0 |
| reset | 1 | 142 | 64 | 63 | 1 |
| random-1 | 1 | 1767 | 1024 | 1024 | 0 |
| random-17 | 17 | 1814 | 1024 | 1024 | 0 |
| random-123 | 123 | 1800 | 1024 | 1024 | 0 |
| stress | 1 | 16679 | 10000 | 10000 | 0 |
| all | 1 | 17539 | 10384 | 10383 | 1 |
| random-17-replay | 17 | 1814 | 1024 | 1024 | 0 |
| passive-source1 | 1 | 100 | 32 | 32 | 0 |
| mutation-wrapper-clean | 1 | 132 | 64 | 64 | 0 |

All positive runs required zero UVM errors/fatals, a completion marker, a valid JSON
report, native coverage output, and matching independent Python FIFO replay results.

## Expected-negative runs

| Inserted defect | Required detection | Python data oracle |
| --- | --- | --- |
| drop | `SB_LOSS` | Detected |
| duplicate | `SB_DUPLICATE` | Detected |
| corrupt | `SB_CORRUPTION_OR_ORDER` | Detected |
| route | `SB_ROUTING` | Detected |
| priority | `SB_ARBITRATION` | Protocol/arbitration check |
| unstable | `SVA_OUTPUT_STABLE` | Protocol/arbitration check |
| protocol_negative | `SVA_INPUT_STABLE` | Protocol/arbitration check |

## Deterministic replay

Random seed **17** was rerun with an identical cycle/transfer trace.

Trace SHA-256: `b7bcb05a0bbb87bf6bf172e1bca8684fb9d06ead29ad8d498cbbf0798537a234`

The clean mutation wrapper also reproduced the production router's single-port trace.

## Evidence and limits

Raw simulation logs are in [logs/](logs/).
Machine-readable results are in [regression.json](regression.json) and [directed.json](directed.json).
See [coverage.md](coverage.md) for native coverage details and
[tool limitations](../docs/tool-limitations.md) for unexecuted checks.
