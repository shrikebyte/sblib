# HDL Modules External Dependency

Some files from the [HDL-Modules](https://github.com/hdl-modules/hdl-modules) library have been added as a dependency to sblib because they are used by the register file generator scripts.

These files have been changed as outlined below:

1. They are no longer tied to specific vhdl library namespaces.
2. Code style update for sblib.
3. The `hdlm_conv_pkg` was added as a converter interface between the hdl-modules axi-lite interface and the sblib axi-lite interface.
