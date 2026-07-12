# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] - Unreleased

No notable changes yet

## [0.2.0] - 2026-07-11

### Added

- AXI Stream components and interface definition.
- License and standard headers.
- Generate vhdl_ls config from script.
- SPI manager.
- Block averager.
- AXI Lite and Wishbone shared ram.
- AXI Lite pipe
- Various new utility functions.
- Other odds and ends.

### Changed

- Change from resolved to unresolved types for better compile-time error checking.
- Automatically resolve vector lengths, rather than defining them with generics, where applicable.
- Replace dual-record AXI Lite interfaces VHDL'19 record views.
- Update build tool dependency versions.
- Change primary simulator from GHDL to NVC.
- Improve AXIL decoder to allow different decoder bit widths per subordinate.
- Improve AXIL init mgr to allow the use of BRAM for startup ROM.
- Simplify AXIL GPIO
- Improve stdver register format for better readability.

### Fixed

- Fix a few axil handshaking bugs in various modules.

### Removed

- Remove legacy FIFOs

## [0.1.0] - 2025-11-18

### Added

- Initial release.
