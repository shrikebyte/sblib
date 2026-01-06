################################################################################
# File : cdc_vector.tcl
# Auth : David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_vector cdc_vector.tcl"
################################################################################

set src_clk [get_clocks -quiet -of_objects [get_ports "s_clk"]]
set dst_clk [get_clocks -quiet -of_objects [get_ports "m_clk"]]

if {${src_clk} != ""} {
  set src_clk_period [get_property "PERIOD" ${src_clk}]
  puts "INFO: cdc_vector: Using src_clk period: ${src_clk_period}."
} else {
  set src_clk_period 2
  puts "WARNING: cdc_vector: Could not find src_clk."
}

if {${dst_clk} != ""} {
  set dst_clk_period [get_property "PERIOD" ${dst_clk}]
  puts "INFO: cdc_vector: Using dst_clk period: ${dst_clk_period}."
} else {
  set dst_clk_period 2
  puts "WARNING: cdc_vector: Could not find dst_clk."
}

set min_period [expr {min(${src_clk_period}, ${dst_clk_period})}]
puts "INFO: cdc_vector: Using min period: ${min_period}."

set src_data [get_cells {src_data_reg_reg[*]}]
set dst_data [get_cells {m_data_reg[*]}]

set_max_delay -datapath_only -from $src_data -to $dst_data $min_period
set_bus_skew -from $src_data -to $dst_data $min_period
