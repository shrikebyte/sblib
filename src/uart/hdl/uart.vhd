--##############################################################################
--# File : uart.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! UART
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
  generic (
    G_CLKS_PER_BIT : positive := 128;
    G_SYNC_RXD : boolean := true;
    G_GLITCH_FILTER_RXD : boolean := true
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;

    s_tx_valid : in    std_logic;
    s_tx_ready : out   std_logic;
    s_tx_data  : in    std_logic_vector(7 downto 0);

    m_rx_valid : out   std_logic;
    m_rx_data  : out   std_logic_vector(7 downto 0);

    txd : out std_logic;
    rxd : in  std_logic
  );
end entity;

architecture rtl of uart is

begin

end architecture;
