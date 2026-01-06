################################################################################
# File : cdc_pulse.tcl
# Auth : David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_pulse cdc_pulse.tcl"
################################################################################

set src_clk [get_clocks -quiet -of_objects [get_ports "src_clk"]]
set dst_clk [get_clocks -quiet -of_objects [get_ports "dst_clk"]]

if {${src_clk} != ""} {
  set src_clk_period [get_property "PERIOD" ${src_clk}]
  puts "INFO: cdc_pulse: Using src_clk period: ${src_clk_period}."
} else {
  set src_clk_period 2
  puts "WARNING: cdc_pulse: Could not find src_clk."
}

if {${dst_clk} != ""} {
  set dst_clk_period [get_property "PERIOD" ${dst_clk}]
  puts "INFO: cdc_pulse: Using dst_clk period: ${dst_clk_period}."
} else {
  set dst_clk_period 2
  puts "WARNING: cdc_pulse: Could not find dst_clk."
}

set min_period [expr {min(${src_clk_period}, ${dst_clk_period})}]
puts "INFO: cdc_pulse: Using min period: ${min_period}."

set src_toggl [get_cells "gen_src.src_toggl_reg"]
set dst_toggl_cdc [get_cells "dst_toggl_cdc_reg[0]"]
set_max_delay -datapath_only -from ${src_toggl} -to ${dst_toggl_cdc} ${min_period}

# Get the highest index of the src to dest toggle register sync chain
set dst_toggl [lindex [lsort [get_cells "dst_toggl_cdc_reg[*]"]] end]
set src_toggl_fdbk_cdc [get_cells -quiet "gen_src.src_toggl_fdbk_cdc_reg[0]"]

if {${src_toggl_fdbk_cdc} != ""} {
  puts "INFO: cdc_pulse: Applying constraint to feedback path."
  set_max_delay -datapath_only -from ${dst_toggl} -to ${src_toggl_fdbk_cdc} ${min_period}
} else {
  puts "INFO: cdc_pulse: No feedback path found."
}
