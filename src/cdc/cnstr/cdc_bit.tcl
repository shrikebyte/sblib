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
set dst_clk [get_clocks -of_objects [get_ports "dst_clk"]]

if {$src_clk != "" && $dst_clk != ""} {

  set first_cdc_reg [get_cells {cdc_regs_reg[0][*]}]
  set src_reg [get_cells {gen_src_clk.src_reg_reg[*]}]
  set min_period [expr {min([get_property PERIOD $src_clk], [get_property PERIOD $dst_clk])}]

  puts "INFO: cdc_bit: Applying set_max_delay of '$min_period' from src_reg '$src_reg' to first_cdc_reg '$first_cdc_reg'."
  set_max_delay -datapath_only -from $src_reg -to $first_cdc_reg $min_period
  set_bus_skew -from $src_reg -to $first_cdc_reg $min_period

} else {

  set min_period [get_property PERIOD $dst_clk]
  set cdc_nets [get_nets {src_reg[*]}]

  foreach net $cdc_nets {

    set reg [get_cells -of_objects $net]
    set src_port [get_ports -scoped_to_current_instance -prop_thru_buffers -of_objects $net]

    if {[get_property CLASS $src_port] == "port"} {

      puts "INFO: cdc_bit: Applying set_max_delay of $min_period from src_port '$src_port' to first_cdc_reg '$reg'."
      set_max_delay -datapath_only -from $src_port -to $reg $min_period
      set_property IOB FALSE $src_port

    } else {

      puts "WARNING: cdc_bit: No source reg or port found for $reg. Applying set_false_path."
      set_false_path -setup -hold -to $reg

    }
  }
}
