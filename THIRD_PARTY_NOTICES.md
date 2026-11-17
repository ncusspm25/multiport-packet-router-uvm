# Third-party tools and sources

The project RTL, testbench and Python utilities are independently authored for
this portfolio. No employer RTL, verification IP, specifications, waveforms or
simulation logs are included.

| Dependency | Source | License | Handling |
| --- | --- | --- | --- |
| Accellera UVM 2020.3.2 | [Official release page](https://www.accellera.org/downloads/standards/uvm) | Apache-2.0 | Downloaded unchanged, archive SHA-256 pinned, original LICENSE.txt and NOTICE.txt retained locally |
| Verilator 5.054 | [Official repository](https://github.com/verilator/verilator) | LGPL-3.0 / Artistic-2.0 licensing in upstream distribution | Exact commit pinned, built locally, upstream LICENSE retained |
| Z3 | [Microsoft Z3](https://github.com/Z3Prover/z3) | MIT | Ubuntu package used by Verilator's constraint solver |
| GNU GCC / Make and other build prerequisites | Signed Ubuntu repositories | Upstream licenses, including GPL and runtime exceptions where applicable | Build tools only, no binaries vendored in this repository |
| GitHub Actions checkout | [actions/checkout](https://github.com/actions/checkout) | MIT | v4.2.2 commit pinned |
| GitHub Actions upload-artifact | [actions/upload-artifact](https://github.com/actions/upload-artifact) | MIT | v4.6.2 commit pinned |

`toolchain.lock.json` records the resolved Verilator commit and UVM archive
checksum. Third-party source trees, archives and compiled binaries are excluded
from Git. The bootstrap process uses ordinary Git/HTTPS downloads and no Python
third-party package installation or package lifecycle scripts.
