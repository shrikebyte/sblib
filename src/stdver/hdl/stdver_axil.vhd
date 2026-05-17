--##############################################################################
--# File : stdver_axil.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# Standard Version module. These Registers
--# should be instantiated at the base address of every FPGA design.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.bus_pkg.all;
use work.stdver_regs_pkg.all;
use work.stdver_register_record_pkg.all;

entity stdver_axil is
  generic (
    G_DEVICE_ID  : std_logic_vector(31 downto 0) := x"DEAD_BEEF";
    G_VER_MAJOR  : natural range 0 to 255        := 0;
    G_VER_MINOR  : natural range 0 to 255        := 1;
    G_VER_PATCH  : natural range 0 to 255        := 0;
    G_ENGR_BUILD : boolean                       := true;
    G_BUILD_DATE : std_logic_vector(31 downto 0) := x"DEAD_BEEF";
    G_BUILD_TIME : std_logic_vector(23 downto 0) := x"DE_BEEF";
    G_GIT_HASH   : std_logic_vector(31 downto 0) := x"DEAD_BEEF";
    G_GIT_DIRTY  : boolean                       := true
  );
  port (
    clk    : in    std_logic;
    srst   : in    std_logic;
    s_axil : view  s_axil_view
  );
end entity;

architecture rtl of stdver_axil is

  signal u : stdver_regs_up_t         := stdver_regs_up_init;
  signal d : stdver_regs_down_t       := stdver_regs_down_init;
  signal r : stdver_reg_was_read_t    := stdver_reg_was_read_init;
  signal w : stdver_reg_was_written_t := stdver_reg_was_written_init;

begin

  u_stdver_reg_file : entity work.stdver_register_file_axi_lite
  port map (
    clk             => clk,
    reset           => srst,
    s_axil          => s_axil,
    regs_up         => u,
    regs_down       => d,
    reg_was_read    => r,
    reg_was_written => w
  );

  u.id.id           <= unsigned(G_DEVICE_ID);
  u.version.dirty   <= x"D" when G_GIT_DIRTY else x"0";
  u.version.engr    <= x"E" when G_ENGR_BUILD else x"0";
  u.version.major   <= G_VER_MAJOR;
  u.version.minor   <= G_VER_MINOR;
  u.version.patch   <= G_VER_PATCH;
  u.date.year       <= unsigned(G_BUILD_DATE(31 downto 16));
  u.date.month      <= unsigned(G_BUILD_DATE(15 downto 8));
  u.date.day        <= unsigned(G_BUILD_DATE(7 downto 0));
  u.time.hour       <= unsigned(G_BUILD_TIME(23 downto 16));
  u.time.minute     <= unsigned(G_BUILD_TIME(15 downto 8));
  u.time.second     <= unsigned(G_BUILD_TIME(7 downto 0));
  u.githash.githash <= unsigned(G_GIT_HASH);

end architecture;
