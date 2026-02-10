################################################################################
# File     : Makefile
# Author   : David Gussler
# Language : gnu make
# ==============================================================================
# Project maintenance commands
# ..Windows users: Run from git bash, MSYS2, or WSL2 prompt.
################################################################################

################################################################################
# Configuration Settings
################################################################################

PROJ_NAME := sblib

# Library Version
# Use semantic versioning with respect to the module HDL interfaces.
# Update the version and add appropriate notes to the `CHANGELOG.md` each time
# a new library version is tagged and released.
VER_MAJOR := 0
VER_MINOR := 1
VER_PATCH := 0

# Required project build tool versions
REQUIRE_REGS_VER   := 8.1.0
REQUIRE_VSG_VER    := 3.35.0
REQUIRE_VUNIT_VER  := 5.0.0.dev7


################################################################################
# Rules
################################################################################

# Check Python package version
define check_python_pkg_ver
	@v=$$(python -m pip show $(1) 2>/dev/null | awk '/Version:/ {print $$2}'); \
	if [ "$$v" != "$($(2))" ]; then \
		echo "ERROR: Requires $(1) version $($(2)) (found $$v)"; \
		exit 1; \
	fi
endef

MAKEFILE_DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
SRC_DIR := $(MAKEFILE_DIR)src
TEST_DIR := $(MAKEFILE_DIR)test
BUILD_DIR := $(MAKEFILE_DIR)build
BUILD_NAME := $(PROJ_NAME)_v$(VER_MAJOR)_$(VER_MINOR)_$(VER_PATCH)
RELEASE_DIR := $(BUILD_DIR)/$(BUILD_NAME)
REGS_SRC := $(SRC_DIR)/**/regs/*.toml
STYLE_SRC := $(shell find $(SRC_DIR) $(TEST_DIR) -type f -name "*.vhd" -not -path "$(SRC_DIR)/hdlm/hdl/*")
NEW_TAG := v$(VER_MAJOR).$(VER_MINOR).$(VER_PATCH)

.PHONY: package build release sim regs style style-fix tool-check clean

# Check versions of required build tools
tool-check:
	@echo "INFO: Checking tools..."
	$(call check_python_pkg_ver,hdl_registers,REQUIRE_REGS_VER)
	$(call check_python_pkg_ver,vsg,REQUIRE_VSG_VER)
	$(call check_python_pkg_ver,vunit_hdl,REQUIRE_VUNIT_VER)
	@echo "INFO: Tool check passed."

# Create a release package with all of the built output products
package: regs
	mkdir -p $(RELEASE_DIR)
	cp $(BUILD_DIR)/regs_out/*/*.h* $(RELEASE_DIR)
	cd $(BUILD_DIR) && tar -czvf $(BUILD_NAME).tar.gz $(RELEASE_DIR)

# Run the VUnit simulation
sim: regs
	cd scripts && python sim.py --xunit-xml $(BUILD_DIR)/sim_report.xml

# Check the coding style of the src files
style:
	mkdir -p $(BUILD_DIR)
	vsg -f $(STYLE_SRC) -c ./scripts/vsg_rules.yaml -of vsg --all_phases --quality_report $(BUILD_DIR)/style_report.json

# Check AND FIX the coding style of the src files
style-fix:
	mkdir -p $(BUILD_DIR)
	vsg -f $(STYLE_SRC) -c ./scripts/vsg_rules.yaml -of vsg --fix

# Generate the register output products
regs:
	cd scripts && python regs.py $(REGS_SRC)

# Create a new git tag and Github release for this version of the code.
release:
	@if ! git diff-index --quiet HEAD --; then \
		echo "ERROR: Uncommitted changes detected. Commit them before proceeding." >&2; \
		exit 1; \
	fi
	@echo "Last tag: $(shell git describe --tags --abbrev=0 2>/dev/null || echo "NA")"
	@echo "New tag : $(NEW_TAG)"
	@echo
	@echo "NOTICE: If the value for the new tag is unacceptable, then the tag"
	@echo "may be changed by modifying the VER_* Makefile variables."
	@echo
	@echo "NOTICE: Before proceeding, don't forget to update CHANGELOG.md with the"
	@echo "details of this release."
	@echo
	@read -p "Do you want to proceed? (y/n): " user_input; \
	if [ "$$user_input" != "y" ]; then \
		echo "Aborting..."; \
		exit 1; \
	fi
	git tag -a $(NEW_TAG) -m "Release $(NEW_TAG)"
	git push origin $(NEW_TAG)

clean:
	rm -rf build
