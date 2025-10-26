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
use work.util_pkg.all;

entity uart_axil is
  generic (
    G_CLKS_PER_BIT : positive := 128
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;

    m_axil_req : in   axil_req_t;
    m_axil_rsp : out  axil_rsp_t;

    txd : out std_logic;
    rxd : in  std_logic
  );
end entity;

architecture rtl of uart_axil is

begin

end architecture;
