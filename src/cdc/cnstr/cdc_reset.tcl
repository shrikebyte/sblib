################################################################################
# File : cdc_reset.tcl
# Auth : David Gussler
# Lang : Xilinx Design Constraints
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_reset cdc_reset.tcl"
################################################################################

puts "INFO: cdc_reset: Applying reset CDC false path."

set cdc_regs [get_cells {cdc_regs_reg[*]}]
set_false_path -to $cdc_regs
