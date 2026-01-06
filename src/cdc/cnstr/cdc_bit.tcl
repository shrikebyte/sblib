################################################################################
# File : cdc_bit.tcl
# Auth : David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_bit cdc_bit.tcl"
################################################################################

set src_clk [get_clocks -quiet -of_objects [get_ports "src_clk"]]
set dst_clk [get_clocks -quiet -of_objects [get_ports "dst_clk"]]

set first_cdc_reg [get_cells {cdc_regs_reg[0][*]}]

if {$src_clk != "" && $dst_clk != ""} {

  set src_reg [get_cells {gen_src_clk.src_reg_reg[*]}]

  set min_period [expr {min([get_property PERIOD $src_clk], [get_property PERIOD $dst_clk])}]
  puts "INFO: cdc_bit: Found source register. Applying set_max_delay."
  puts "INFO: cdc_bit: Using min period: ${min_period}."
  set_max_delay -datapath_only -from $src_reg -to $first_cdc_reg $min_period
  set_bus_skew -from $src_reg -to $first_cdc_reg $min_period

} else {

  puts "INFO: cdc_bit: No source register found. Applying set_false_path."
  set_false_path -setup -hold -to $first_cdc_reg

}
