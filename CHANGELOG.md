# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - Unreleased

### Added

- Add AXI Stream components and interface definition.
- Add license and standard headers.

### Changed

- Change from resolved to unresolved types for better compile-time error checking.
- Automatically resolve vector lengths, rather than defining them with generics, where applicable.
- Change axi lite components to use VHDL'19 record view interfaces rather than dual i/o records.

### Removed

- Remove legacy FIFOs

## [0.1.0] - 2025-11-18

### Added

- Initial release.
