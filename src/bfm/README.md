# HDL Modules External Dependency

Some files from the [HDL-Modules](https://github.com/hdl-modules/hdl-modules) library have been added as an external dependency to sblib because they are used by the testbench BFMs.

These files have been changed as outlined below:

1. They are no longer tied to specific vhdl library namespaces.
2. Code style update for sblib.
3. Entity renaming for sblib.
4. The axi-stream BFMs now use VHDL'19 interfaces.
5. The axi-stream BFM tuser functionality has been changed so that it is now byte oriented, rather than beat oriented.
6. New tkeep randomization options have been added for generating and checking sparse packets.
7. Added support for arbitrary-size bytes. The hdl-modules variant only supports 8-bit fixed-size bytes.
8. Combined necessary functions into a single bfm package.
