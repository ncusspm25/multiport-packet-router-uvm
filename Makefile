SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

-include .tools/env.mk

VERILATOR ?= verilator
UVM_HOME ?= $(CURDIR)/.tools/uvm-2020.3.2
BUILD_DIR ?= $(CURDIR)/.build
JOBS ?= 2
SEED ?= 1
DATA_W ?= 32
CASE ?= single
N_PACKETS ?= 32
REPORT_DIR ?= $(CURDIR)/reports
VERILATOR_COVERAGE ?= $(dir $(VERILATOR))verilator_coverage
UVM_SOURCES := tb/router_types_pkg.sv tb/router_if.sv tb/router_uvm_pkg.sv \
	tb/router_assertions.sv tb/uvm_top.sv
UVM_HEADERS := $(wildcard tb/uvm/*.svh)

.NOTPARALLEL:
.PHONY: smoke check-tools directed features uvm-build test mutation-build regression verify lint coverage reports

check-tools:
	@python3 scripts/check_tools.py "$(VERILATOR)" "$(UVM_HOME)"

$(BUILD_DIR)/smoke/Vsmoke_top: tb/smoke/smoke.sv | check-tools
	mkdir -p "$(BUILD_DIR)/smoke"
	$(VERILATOR) --binary --timing --timescale 1ns/1ps --assert --vpi -j $(JOBS) \
		--top-module smoke_top --Mdir "$(BUILD_DIR)/smoke" \
		+incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv \
		tb/smoke/smoke.sv $(UVM_HOME)/src/dpi/uvm_dpi.cc \
		-CFLAGS "-O0 -I$(UVM_HOME)/src/dpi" \
		> "$(BUILD_DIR)/smoke/build.log" 2>&1

smoke: $(BUILD_DIR)/smoke/Vsmoke_top
	"$(BUILD_DIR)/smoke/Vsmoke_top" +verilator+seed+$(SEED) \
		+UVM_NO_RELNOTES | tee "$(BUILD_DIR)/smoke/run.log"
	@python3 scripts/check_smoke.py "$(BUILD_DIR)/smoke/run.log"

$(BUILD_DIR)/directed-$(DATA_W)/Vdirected_top: rtl/packet_router.sv tb/router_assertions.sv tb/directed/directed_top.sv | check-tools
	mkdir -p "$(BUILD_DIR)/directed-$(DATA_W)"
	$(VERILATOR) --binary --timing --timescale 1ns/1ps --assert -j $(JOBS) \
		--top-module directed_top -GDATA_W=$(DATA_W) \
		--Mdir "$(BUILD_DIR)/directed-$(DATA_W)" \
		rtl/packet_router.sv tb/router_assertions.sv tb/directed/directed_top.sv \
		> "$(BUILD_DIR)/directed-$(DATA_W)/build.log" 2>&1

directed: $(BUILD_DIR)/directed-$(DATA_W)/Vdirected_top
	@for testcase in 0 1 2 3 4; do \
		"$(BUILD_DIR)/directed-$(DATA_W)/Vdirected_top" +CASE=$$testcase \
			+verilator+seed+$(SEED) > "$(BUILD_DIR)/directed-$(DATA_W)/case-$$testcase.log" 2>&1; \
		grep 'DIRECTED_PASS' "$(BUILD_DIR)/directed-$(DATA_W)/case-$$testcase.log"; \
	done

$(BUILD_DIR)/features/Vfeature_top: tb/smoke/features.sv | check-tools
	mkdir -p "$(BUILD_DIR)/features"
	$(VERILATOR) --binary --timing --timescale 1ns/1ps --assert --coverage -j $(JOBS) \
		--top-module feature_top --Mdir "$(BUILD_DIR)/features" tb/smoke/features.sv \
		> "$(BUILD_DIR)/features/build.log" 2>&1

features: $(BUILD_DIR)/features/Vfeature_top
	cd "$(BUILD_DIR)/features" && ./Vfeature_top +verilator+seed+$(SEED) | tee run.log
	@grep 'FEATURE_PASS' "$(BUILD_DIR)/features/run.log"

$(BUILD_DIR)/uvm-$(DATA_W)/Vuvm_top: rtl/packet_router.sv $(UVM_SOURCES) $(UVM_HEADERS) | check-tools
	mkdir -p "$(BUILD_DIR)/uvm-$(DATA_W)"
	$(VERILATOR) --binary --timing --timescale 1ns/1ps --assert --vpi --coverage -j $(JOBS) \
		--top-module uvm_top --Mdir "$(BUILD_DIR)/uvm-$(DATA_W)" \
		+define+ROUTER_DATA_W=$(DATA_W) +incdir+$(UVM_HOME)/src +incdir+tb/uvm \
		$(UVM_HOME)/src/uvm_pkg.sv rtl/packet_router.sv $(UVM_SOURCES) \
		$(UVM_HOME)/src/dpi/uvm_dpi.cc -CFLAGS "-O0 -I$(UVM_HOME)/src/dpi" \
		> "$(BUILD_DIR)/uvm-$(DATA_W)/build.log" 2>&1

uvm-build: $(BUILD_DIR)/uvm-$(DATA_W)/Vuvm_top

test: uvm-build
	mkdir -p "$(BUILD_DIR)/runs/$(CASE)-$(SEED)"
	cd "$(BUILD_DIR)/runs/$(CASE)-$(SEED)" && \
		"$(BUILD_DIR)/uvm-$(DATA_W)/Vuvm_top" +CASE=$(CASE) +SEED=$(SEED) \
		+N_PACKETS=$(N_PACKETS) +verilator+seed+$(SEED) +UVM_NO_RELNOTES \
		| tee run.log
	python3 scripts/check_run.py "$(BUILD_DIR)/runs/$(CASE)-$(SEED)"

$(BUILD_DIR)/mutants/router_mutants.sv: rtl/packet_router.sv scripts/make_mutants.py
	python3 scripts/make_mutants.py --out-dir "$(BUILD_DIR)/mutants"

$(BUILD_DIR)/mutation-$(DATA_W)/Vuvm_top: $(BUILD_DIR)/mutants/router_mutants.sv rtl/packet_router.sv $(UVM_SOURCES) $(UVM_HEADERS) | check-tools
	mkdir -p "$(BUILD_DIR)/mutation-$(DATA_W)"
	$(VERILATOR) --binary --timing --timescale 1ns/1ps --assert --vpi --coverage -j $(JOBS) \
		--top-module uvm_top --Mdir "$(BUILD_DIR)/mutation-$(DATA_W)" \
		+define+ROUTER_DATA_W=$(DATA_W) +define+ROUTER_MUTATIONS \
		+incdir+$(UVM_HOME)/src +incdir+tb/uvm \
		$(UVM_HOME)/src/uvm_pkg.sv rtl/packet_router.sv "$(BUILD_DIR)/mutants/router_mutants.sv" \
		$(UVM_SOURCES) $(UVM_HOME)/src/dpi/uvm_dpi.cc \
		-CFLAGS "-O0 -I$(UVM_HOME)/src/dpi" \
		> "$(BUILD_DIR)/mutation-$(DATA_W)/build.log" 2>&1

mutation-build: $(BUILD_DIR)/mutation-$(DATA_W)/Vuvm_top

lint: check-tools
	$(VERILATOR) --lint-only --timing --timescale 1ns/1ps -Wall \
		--top-module packet_router rtl/packet_router.sv

regression: uvm-build mutation-build
	python3 scripts/regression.py --build-dir "$(BUILD_DIR)" --width $(DATA_W) --report-dir "$(REPORT_DIR)"

coverage:
	python3 scripts/coverage_report.py --build-dir "$(BUILD_DIR)" --report-dir "$(REPORT_DIR)" \
		--verilator-coverage "$(VERILATOR_COVERAGE)"

reports:
	python3 scripts/write_reports.py --build-dir "$(BUILD_DIR)" --report-dir "$(REPORT_DIR)" \
		--verilator "$(VERILATOR)"

verify:
	$(MAKE) lint smoke features
	@for width in 1 8 16 32 64; do $(MAKE) directed DATA_W=$$width; done
	$(MAKE) regression
	$(MAKE) coverage reports
