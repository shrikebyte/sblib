--##############################################################################
--# File : cdc_reset.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! Reset synchronizer and extender. If any one of the async reset inputs
--! matches the reset level, then the synchronous resets are asserted. It is
--! common to have several async reset sources, such as an external board reset,
--! an mmcm_locked signal, and a software register reset. This module ORs all of
--! these sources together and asserts the reset outputs when one of
--! the async sources is asserted.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cdc_reset is
  generic (
    --! Number of synchronizer flip-flops
    G_SYNC_LEN : positive := 2;
    --! Number of asynchronous reset inputs
    G_NUM_ARST : positive := 1;
    --! Active logic level of the async inputs
    G_ARST_LVL : std_logic_vector(G_NUM_ARST - 1 downto 0) := (others=> '1')
  );
  port (
    clk   : in    std_logic;
    arst  : in    std_logic_vector(G_NUM_ARST - 1 downto 0);
    srst  : out   std_logic := '1';
    srstn : out   std_logic := '0'
  );
end entity;

architecture rtl of cdc_reset is

  -- ---------------------------------------------------------------------------
  signal cdc_regs : std_logic_vector(G_SYNC_LEN - 1 downto 0) := (others=> '1');
  signal arst_0   : std_logic;

  -- ---------------------------------------------------------------------------
  attribute async_reg                 : string;
  attribute shreg_extract             : string;
  attribute async_reg of cdc_regs     : signal is "TRUE";
  attribute shreg_extract of cdc_regs : signal is "NO";

  -- ---------------------------------------------------------------------------
  -- Returns '1' if any of the async reset bits are asserted, otherwise '0'
  function fn_arst (
    arst_slv : std_logic_vector;
    arst_lvl : std_logic_vector
  )
    return std_logic
  is
    variable tmp : std_logic_vector(arst_slv'length - 1 downto 0) := (others=> '0');
  begin
    for i in 0 to arst_slv'length - 1 loop
      tmp(i) := '1' when arst_slv(i) = arst_lvl(i) else '0';
    end loop;
    return or tmp;
  end function;

begin

  -- Reduce the async reset vector down to a single bit
  arst_0 <= fn_arst(arst, G_ARST_LVL);

  -- ---------------------------------------------------------------------------
  -- CDC for async assertion and sync de-assertion
  prc_arst_0_sync : process (clk, arst_0) is begin
    if arst_0 then
      cdc_regs <= (others => '1');
    elsif rising_edge(clk) then
      cdc_regs <= cdc_regs(G_SYNC_LEN - 2 downto 0) & '0';
    end if;
  end process;

  prc_pipe : process (clk) is begin
    if rising_edge(clk) then
      srst  <= cdc_regs(G_SYNC_LEN - 1);
      srstn <= not cdc_regs(G_SYNC_LEN - 1);
    end if;
  end process;

end architecture;
