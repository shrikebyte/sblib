# Shrikebyte VHDL Library

[![test](https://github.com/shrikebyte/sblib/actions/workflows/test.yaml/badge.svg)](https://github.com/shrikebyte/sblib/actions/workflows/test.yaml)

This repository holds Shrikebyte's open-source VHDL library of reusable HDL building blocks.

## Getting Started

### Get the Source Code

This repository is hosted on [GitHub](https://github.com/shrikebyte/sblib) and can be directly cloned using this command:

`git clone https://github.com/shrikebyte/sblib.git`

### Install Project Tools

- HDL Registers
- VHDL Style Guide
- VUnit
- NVC
- Vivado (optional)

#### Install Python Tools

Python tools are automatically installed in a venv as part of the makefile flow.

#### Install NVC

NVC is an open-source VHDL simulator.

The latest version can be compiled from source and manually installed from here:

```sh
git clone https://github.com/nickg/nvc.git
```

Alternatively, a pre-compiled release can be downloaded from [Github](https://github.com/nickg/nvc/releases), however, this is a rapidly evolving project so compiling the most up-to-date code yourself is recommended.

#### Install Vivado

Vivado can optionally be used to synthesize each module in out-of-context mode. This is useful for checking preliminary timing and utilization results after making changes to a module.

### Test

Run the following command to start the simulation regression. It will run the sub-tests in parallel, making full use of all the available CPU cores.

```sh
make sim
```

Run the following command to start the synthesis regression.

```sh
make synth
```

## Release Process

This project uses Github actions to manage releases. Once a new version of the
code is ready to be deployed:

1. Run `make style-fix` from the repo's root to run the code style tool over
   the new code. This ensures style consistency across the codebase without
   the need for manual code reviews.
2. Update the version number at the top of the [Makefile](Makefile), following
   Semantic Versioning.
3. Update the [changelog](CHANGELOG.md) with a summary the changes for the
   release.
4. Add, commit, and push the changes using git.
5. Run the following command, which triggers a Github action to create a new git
   tag and Github release.

   `make release`

### Versioning

This project uses [Semantic Versioning](http://semver.org/).
For a list of available versions and the design change history see the
[changelog](CHANGELOG.md).

Semantic versioning shall be used with respect to the module's HDL interfaces.
A major changes breaks at least one module interface. A minor change can add
a new interface and/or feature to a module without breaking compatibility.
A patch change fixes a bug without breaking compatibility.
