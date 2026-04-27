################################################################################
# File : spi_mgr.xdc
# Auth : David Gussler
# ==============================================================================
# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
# Copyright (C) Shrikebyte, LLC
# Licensed under the Apache 2.0 license, see LICENSE for details.
# ==============================================================================
# Scoped constraint. Use: "read_xdc -ref cdc_bit spi_mgr.xdc"
################################################################################

set clk [get_clocks -of_objects [get_ports {clk}]]

set in_ports [get_ports -scoped_to_current_instance -prop_thru_buffers {spi_miso}]
set out_ports [get_ports -scoped_to_current_instance -prop_thru_buffers -filter {NAME == "spi_sck" || NAME == "spi_mosi" || NAME =~ "spi_csn[*]"}]

set_property IOB TRUE $in_ports
set_property IOB TRUE $out_ports

set_max_delay -datapath_only [get_property PERIOD $clk] -from $in_ports -to $clk
set_max_delay -datapath_only [get_property PERIOD $clk] -from $clk -to $out_ports
