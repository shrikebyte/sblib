################################################################################
# File     : Makefile
# Author   : David Gussler
# ==============================================================================
# Project maintenance
################################################################################
-include local.mk

################################################################################
# Project Settings
################################################################################
PROJECT_VERSION := 0.2.0


################################################################################
# Rules
################################################################################

# Defaults (can be overridden by local.mk)
VIVADO ?= $(shell which vivado 2>/dev/null)

# Paths & tools
THIS_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
SRC_DIR := $(THIS_DIR)src
TEST_DIR := $(THIS_DIR)test
BUILD_DIR := $(THIS_DIR)build
VENV_DIR = $(THIS_DIR).venv
VER_STRING := v$(PROJECT_VERSION)
REGS_SRC := $(SRC_DIR)/*/regs/*.toml
STYLE_SRC := $(shell find $(SRC_DIR) $(TEST_DIR) -type f -name "*.vhd" -not -path "$(SRC_DIR)/hdlm/hdl/*")
REGS_STAMP := $(BUILD_DIR)/regs_out/.regs_stamp
VENV_STAMP := $(VENV_DIR)/.venv_stamp

ifeq ($(OS),Windows_NT)
	PYTHON_SYS := python.exe
	PYTHON := $(VENV_DIR)/Scripts/python.exe
else
	PYTHON_SYS := python3
	PYTHON := $(VENV_DIR)/bin/python
endif
PIP := $(PYTHON) -m pip
VSG := $(PYTHON) -m vsg

# Phony rules
.PHONY: release sim regs style style-fix clean synth

# Run the VUnit simulation
sim: $(REGS_STAMP)
	$(PYTHON) scripts/sim.py --vhdl_ls
	$(PYTHON) scripts/sim.py --xunit-xml $(BUILD_DIR)/sim_report.xml

# Check the coding style of the VHDL src files
style: $(VENV_STAMP) $(STYLE_SRC)
	mkdir -p $(BUILD_DIR)
	$(VSG) -f $(STYLE_SRC) \
	-c vsg_rules.yaml \
	-of vsg \
	--all_phases \
	--quality_report $(BUILD_DIR)/style_report.json

# Check AND FIX the coding style of the VHDL src files
style-fix: $(VENV_STAMP) $(STYLE_SRC)
	mkdir -p $(BUILD_DIR)
	$(VSG) -f $(STYLE_SRC) \
	-c vsg_rules.yaml \
	-of vsg \
	--fix

# Synthesize each submodule and save utilization & timing results
synth: $(REGS_STAMP)
	cd scripts && $(VIVADO) -mode batch -nojournal -nolog -notrace -source synth.tcl | tee $(BUILD_DIR)/vivado_out/synth.log

# Generate register output products
$(REGS_STAMP): $(VENV_STAMP) $(REGS_SRC)
	$(PYTHON) scripts/regs.py $(REGS_SRC)
	touch $(REGS_STAMP)

# Install venv and python packages
$(VENV_STAMP): python-requirements.txt
	test -d $(VENV_DIR) || $(PYTHON_SYS) -m venv $(VENV_DIR)
	$(PIP) install --upgrade pip
	$(PIP) install -r python-requirements.txt
	touch $(VENV_STAMP)

# Create a new git tag and Github release for this version of the code. A Github
# action will generate the release from source.
release:
	@if ! git diff-index --quiet HEAD --; then \
		echo "ERROR: Uncommitted changes detected. Commit them before proceeding." >&2; \
		exit 1; \
	fi
	@echo "Last tag: $(shell git describe --tags --abbrev=0 2>/dev/null || echo "NA")"
	@echo "New tag : $(VER_STRING)"
	@echo
	@echo "NOTICE: If the value for the new tag is unacceptable, then the tag"
	@echo "may be changed by modifying the PROJECT_VERSION Makefile variable."
	@echo
	@echo "NOTICE: Before proceeding, don't forget to update CHANGELOG.md with the"
	@echo "details of this release."
	@echo
	@read -p "Do you want to proceed? (y/n): " user_input; \
	if [ "$$user_input" != "y" ]; then \
		echo "Aborting..."; \
		exit 1; \
	fi
	git tag -a $(VER_STRING) -m "Release $(VER_STRING)"
	git push origin $(VER_STRING)

clean:
	rm -rf $(BUILD_DIR) scripts/__pycache__ scripts/vunit_out
