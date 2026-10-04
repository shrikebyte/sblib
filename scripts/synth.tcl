################################################################################
# File : synth.tcl
# Auth : David Gussler
# ==============================================================================
# Vivado OOC synthesis script
################################################################################

set FPGA_PART "xc7a35tcpg236-1"
set SCRIPT_DIR [file normalize [file dirname [info script]]]
set ROOT_DIR [file normalize ${SCRIPT_DIR}/../]

set OUTPUT_DIR "$ROOT_DIR/build/vivado_out"

set SRC_HDL [glob \
  $ROOT_DIR/src/*/hdl/* \
  $ROOT_DIR/build/regs_out/*/hdl/* \
]

set SRC_CNSTR_SCOPED [glob \
  $ROOT_DIR/src/*/cnstr/* \
]

create_project -in_memory -part $FPGA_PART

read_vhdl -vhdl2019 $SRC_HDL

read_xdc "$ROOT_DIR/scripts/clock.xdc"

foreach cnstrfile $SRC_CNSTR_SCOPED {
  set refname [file tail $cnstrfile]
  set refname [file rootname $refname]
  read_xdc -unmanaged -ref $refname $cnstrfile
}

file mkdir $OUTPUT_DIR

set configs [list \
  [dict create top "axis_arb"       generics [list "G_NUM_S=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_broadcast" generics [list "G_NUM_M=16" "G_DW=64" "G_UW=8"]] \
]

foreach config $configs {
  set top [dict get $config top]
  set generics [dict get $config generics]

  # puts "INFO: Elaborating ${top} with generics: ${generics}"
  # synth_design -part $FPGA_PART -top $top -generic $generics -rtl -mode out_of_context
  # write_checkpoint -force "$OUTPUT_DIR/${top}_elab.dcp"

  puts "INFO: Synthesizing ${top} with generics: ${generics}"
  synth_design -part $FPGA_PART -top $top -generic $generics -mode out_of_context

  report_utilization -file "$OUTPUT_DIR/${top}_util.rpt"
  report_timing_summary -delay_type min_max -max_paths 10 -report_unconstrained -file "$OUTPUT_DIR/${top}_timing.rpt"
  report_design_analysis -logic_level_distribution -file "$OUTPUT_DIR/${top}_levels.rpt"
  write_checkpoint -force "$OUTPUT_DIR/${top}_synth.dcp"

  set should_exit 0

  # Check for negative slack
  set slack [get_property SLACK [get_timing_paths -delay_type "min_max"]]
  if {${slack} != "" && [expr {${slack} < 0}]} {
    puts "ERROR: Setup/hold timing negative slack after synthesis run. See $OUTPUT_DIR/${top}_timing.rpt"
    tail ${release_dir}/${build_name}_timing.rpt 80
    set should_exit 1
  }

  # Check for pulse width violations
  if {[report_pulse_width -return_string -all_violators -no_header] != ""} {
    puts "ERROR: Pulse width timing violation after implementation run. See ${release_dir}/${build_name}_pulse.rpt"
    report_pulse_width -all_violators -file "${release_dir}/${build_name}_pulse.rpt"
    tail ${release_dir}/${build_name}_pulse_width.rpt 80
    set should_exit 1
  }

  if {${should_exit} eq 1} {
    exit 1
  }
}

puts "All done. Great success!"
exit 0
