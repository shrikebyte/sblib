################################################################################
# File : synth.tcl
# Auth : David Gussler
# ==============================================================================
# Vivado OOC synthesis script
################################################################################
set CHECK_TIMING 0
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

file mkdir ${OUTPUT_DIR}

set configs [list \
  [dict create top "axis_arb"        tag ""   generics [list "G_NUM_S=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_broadcast"  tag ""   generics [list "G_NUM_M=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_cat"        tag ""   generics [list "G_NUM_S=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_demux"      tag ""   generics [list "G_NUM_M=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_fifo"       tag "a_" generics [list "G_DW=64" "G_UW=8" "G_DEPTH=1024" "G_PACKET_MODE=1'b0"]] \
  [dict create top "axis_fifo"       tag "b_" generics [list "G_DW=64" "G_UW=8" "G_DEPTH=1024" "G_PACKET_MODE=1'b1"]] \
  [dict create top "axis_fifo_async" tag "a_" generics [list "G_DW=64" "G_UW=8" "G_DEPTH=1024" "G_PACKET_MODE=1'b0"]] \
  [dict create top "axis_fifo_async" tag "b_" generics [list "G_DW=64" "G_UW=8" "G_DEPTH=1024" "G_PACKET_MODE=1'b1"]] \
  [dict create top "axis_mux"        tag ""   generics [list "G_NUM_S=16" "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_pack"       tag "a_" generics [list "G_DW=64" "G_UW=8" "G_EXTRA_PIPE=1'b0"]] \
  [dict create top "axis_pack"       tag "b_" generics [list "G_DW=64" "G_UW=8" "G_EXTRA_PIPE=1'b1"]] \
  [dict create top "axis_pipes"      tag ""   generics [list "G_DW=64" "G_UW=8"]] \
  [dict create top "axis_resize"     tag "a_" generics [list "G_S_DW=128" "G_S_UW=8" "G_M_DW=16" "G_M_UW=1"]] \
  [dict create top "axis_resize"     tag "b_" generics [list "G_S_DW=16" "G_S_UW=1" "G_M_DW=128" "G_M_UW=8"]] \
  [dict create top "axis_slice"      tag "a_" generics [list "G_DW=64" "G_UW=8" "G_EXTRA_PIPE=1'b0"]] \
  [dict create top "axis_slice"      tag "b_" generics [list "G_DW=64" "G_UW=8" "G_EXTRA_PIPE=1'b1"]] \
  [dict create top "apb_to_axil"     tag ""   generics [list ""]] \
  [dict create top "axil_arb"        tag ""   generics [list "G_NUM_S=16"]] \
  [dict create top "axil_ascii_mgr"  tag ""   generics [list ""]] \
  [dict create top "axil_pipes"      tag ""   generics [list ""]] \
  [dict create top "axil_ram"        tag ""   generics [list "G_RD_LATENCY=2"]] \
  [dict create top "axil_ram_shared" tag ""   generics [list "G_RD_LATENCY=2"]] \
  [dict create top "axil_to_apb"     tag ""   generics [list ""]] \
  [dict create top "axil_to_reg"     tag ""   generics [list ""]] \
  [dict create top "axil_to_wb"      tag ""   generics [list ""]] \
  [dict create top "wb_ascii_mgr"    tag ""   generics [list ""]] \
  [dict create top "wb_ram_shared"   tag ""   generics [list ""]] \
  [dict create top "wb_to_axil"      tag ""   generics [list ""]] \
  [dict create top "cdc_bit"         tag ""   generics [list "G_WIDTH=16" "G_USE_SRC_REG=1'b1"]] \
  [dict create top "cdc_gray"        tag ""   generics [list "G_WIDTH=16" "G_OUT_REG=1'b1"]] \
  [dict create top "cdc_pulse"       tag ""   generics [list ""]] \
  [dict create top "cdc_reset"       tag ""   generics [list ""]] \
  [dict create top "cdc_vector"      tag ""   generics [list "G_WIDTH=16"]] \
  [dict create top "ebtb_dec"        tag ""   generics [list ""]] \
  [dict create top "ebtb_enc"        tag ""   generics [list ""]] \
  [dict create top "gbox_10to4"      tag ""   generics [list ""]] \
  [dict create top "gbox_10to8"      tag ""   generics [list ""]] \
  [dict create top "gpio_axil"       tag ""   generics [list ""]] \
  [dict create top "spi_mgr"         tag ""   generics [list "G_DW=8"]] \
  [dict create top "uart"            tag ""   generics [list ""]] \
  [dict create top "block_avg"       tag ""   generics [list "G_DW=16"]] \
  [dict create top "stdver_axil"     tag ""   generics [list ""]] \
  [dict create top "cnt_reg"         tag ""   generics [list "G_WIDTH=32"]] \
  [dict create top "debounce"        tag ""   generics [list ""]] \
  [dict create top "edge_detect"     tag ""   generics [list "G_WIDTH=32"]] \
  [dict create top "irq_reg"         tag ""   generics [list "G_WIDTH=32"]] \
  [dict create top "pulse_extend"    tag ""   generics [list ""]] \
  [dict create top "ram"             tag ""   generics [list ""]] \
  [dict create top "shift_reg"       tag ""   generics [list "G_WIDTH=16" "G_DEPTH=32" "G_OUT_REG=1'b1"]] \
  [dict create top "tick"            tag ""   generics [list ""]] \
]

foreach config $configs {
  set top [dict get $config top]
  set tag [dict get $config tag]
  set generics [dict get $config generics]
  set path "${OUTPUT_DIR}/${top}_${tag}_"

  puts "INFO: Synthesizing ${top} with generics: ${generics}"
  synth_design -part $FPGA_PART -top $top -generic $generics -mode out_of_context

  report_utilization -file "${path}util.rpt"
  report_timing_summary -delay_type min_max -max_paths 10 -report_unconstrained -file "${path}timing.rpt"
  report_design_analysis -logic_level_distribution -file "${path}levels.rpt"
  write_checkpoint -force "${path}synth.dcp"

  if {${CHECK_TIMING}} {
    set should_exit 0

    # Check for negative slack
    set slack [get_property SLACK [get_timing_paths -delay_type "min_max"]]
    if {${slack} != "" && [expr {${slack} < 0}]} {
      puts "ERROR: Setup/hold timing negative slack after synthesis run. See ${path}timing.rpt"
      tail "${path}timing.rpt" 80
      set should_exit 1
    }

    # Check for pulse width violations
    if {[report_pulse_width -return_string -all_violators -no_header] != ""} {
      puts "ERROR: Pulse width timing violation after implementation run. See ${path}pulse.rpt"
      report_pulse_width -all_violators -file "${path}pulse.rpt"
      tail "${path}pulse.rpt" 80
      set should_exit 1
    }

    if {${should_exit} eq 1} {
      exit 1
    }
  }
}

puts "All done. Great success!"
exit 0
