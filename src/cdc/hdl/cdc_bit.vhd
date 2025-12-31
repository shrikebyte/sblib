--##############################################################################
--# File : cdc_bit.vhd
--# Auth : David Gussler
--# Lang : VHDL'08
--# ============================================================================
--! Simple bit synchronizer. This can be used to sync one bit or several
--! unrelated bits to a common clock. Includes the option to register the
--! input signal before syncing. If the input signal comes from off-chip, then
--! there is likely no src_clk, but if there is a src_clk for src_bit
--! and the application can handle the extra cycle of latency, then is
--! recommended to enable the 'G_USE_SRC_CLK' generic.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;

entity cdc_bit is
  generic (
    --! True: Register the input; False: Don't register the input; If set to
    --! false then src_clk is unused
    G_USE_SRC_REG : boolean := false;
    --! Number of synchronizer flip-flops
    G_SYNC_LEN : positive := 2;
    --! Number of unrelated bits to synchronize; Ie: the length of 'src_bits'
    --! and 'dst_bits'
    G_WIDTH : positive := 1
  );
  port (
    --! Source clock; Only needed if 'G_USE_SRC_CLK' is true
    src_clk : in    std_logic := 'U';
    --! Source bits
    src_bit : in    std_logic_vector(G_WIDTH - 1 downto 0);
    --! Destination clock
    dst_clk : in    std_logic;
    --! Destination bits
    dst_bit : out   std_logic_vector(G_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of cdc_bit is

  -- ---------------------------------------------------------------------------
  type cdc_regs_t is array(natural range 0 to G_SYNC_LEN - 1) of
    std_logic_vector(G_WIDTH - 1 downto 0);

  -- ---------------------------------------------------------------------------
  signal src_reg  : std_logic_vector(G_WIDTH - 1 downto 0);
  signal cdc_regs : cdc_regs_t;

  -- ---------------------------------------------------------------------------
  attribute async_reg                 : string;
  attribute async_reg of cdc_regs     : signal is "TRUE";
  attribute shreg_extract             : string;
  attribute shreg_extract of cdc_regs : signal is "NO";
  attribute dont_touch                : string;
  attribute dont_touch of src_reg     : signal is "TRUE";

begin

  -- ---------------------------------------------------------------------------
  gen_src_clk : if G_USE_SRC_REG generate

    prc_src_clk : process (src_clk) is begin
      if rising_edge(src_clk) then
        src_reg <= src_bit;
      end if;
    end process;

  else generate

    src_reg <= src_bit;

  end generate;

  -- ---------------------------------------------------------------------------
  prc_bit_sync : process (dst_clk) is begin
    if rising_edge(dst_clk) then
      cdc_regs(0) <= src_reg;

      for i in 1 to cdc_regs'high loop
        cdc_regs(i) <= cdc_regs(i - 1);
      end loop;

    end if;
  end process;

  dst_bit <= cdc_regs(cdc_regs'high);

end architecture;
