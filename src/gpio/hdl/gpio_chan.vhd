--##############################################################################
--# File : gpio_chan.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! Single GPIO Channel
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.axil_data_width;
use work.gpio_pkg.gpio_mode_t;

entity gpio_chan is
  generic (
    G_CH_WIDTH  : positive range 1 to AXIL_DATA_WIDTH       := 32;
    G_CH_MODE   : gpio_mode_t                               := GPIO_MODE_INOUT;
    G_CH_SYNC   : boolean                                   := true;
    G_CH_DFLT_O : std_logic_vector(G_CH_WIDTH - 1 downto 0) := (others => '0');
    G_CH_DFLT_T : std_logic_vector(G_CH_WIDTH - 1 downto 0) := (others => '1')
  );
  port (
    clk  : in    std_logic;
    srst : in    std_logic;
    irq  : out   std_logic;
    --
    regi_din    : out   std_logic_vector(G_CH_WIDTH - 1 downto 0);
    regi_dout   : out   std_logic_vector(G_CH_WIDTH - 1 downto 0);
    rego_dout   : in    std_logic_vector(G_CH_WIDTH - 1 downto 0);
    regw_dout   : in    std_logic;
    regi_tri    : out   std_logic_vector(G_CH_WIDTH - 1 downto 0);
    rego_tri    : in    std_logic_vector(G_CH_WIDTH - 1 downto 0);
    regw_tri    : in    std_logic;
    rego_inten  : in    std_logic_vector(G_CH_WIDTH - 1 downto 0);
    regi_intsts : out   std_logic_vector(G_CH_WIDTH - 1 downto 0);
    rego_intsts : in    std_logic_vector(G_CH_WIDTH - 1 downto 0);
    --
    gpio_i : in    std_logic_vector(G_CH_WIDTH - 1 downto 0);
    gpio_o : out   std_logic_vector(G_CH_WIDTH - 1 downto 0);
    gpio_t : out   std_logic_vector(G_CH_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of gpio_chan is

  signal gpio_in    : std_logic_vector(G_CH_WIDTH - 1 downto 0);
  signal gpio_out   : std_logic_vector(G_CH_WIDTH - 1 downto 0);
  signal gpio_tri   : std_logic_vector(G_CH_WIDTH - 1 downto 0);
  signal gpio_in_ff : std_logic_vector(G_CH_WIDTH - 1 downto 0);
  signal edge       : std_logic_vector(G_CH_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  gen_sync : if G_CH_SYNC generate

    u_cdc_bit : entity work.cdc_bit
    generic map (
      G_USE_SRC_CLK => FALSE,
      G_SYNC_LEN    => 2,
      G_WIDTH       => G_CH_WIDTH
    )
    port map (
      src_bit => gpio_i,
      dst_clk => clk,
      dst_bit => gpio_in
    );

  else generate

    gpio_in <= gpio_i;

  end generate;

  gpio_o <= regi_dout;
  gpio_t <= regi_tri;

  -- ---------------------------------------------------------------------------
  gen_mode : if G_CH_MODE = GPIO_MODE_IN generate

    regi_din  <= gpio_in;
    regi_dout <= (others => '0');
    regi_tri  <= (others => '1');

  elsif G_CH_MODE = GPIO_MODE_OUT generate

    regi_din  <= (others => '0');
    regi_dout <= gpio_out;
    regi_tri  <= (others => '0');

  elsif G_CH_MODE = GPIO_MODE_INOUT generate

    regi_din  <= gpio_in;
    regi_dout <= gpio_out;
    regi_tri  <= gpio_tri;

  elsif G_CH_MODE = GPIO_MODE_DISABLE generate

    regi_din  <= (others => '0');
    regi_dout <= (others => '0');
    regi_tri  <= (others => '1');

  else generate

    assert false
      report "ERROR: gpio_chan G_CH_MODE = [ GPIO_MODE_IN | GPIO_MODE_OUT | GPIO_MODE_INOUT | GPIO_MODE_DISABLE ]"
      severity error;

    regi_din  <= (others => '0');
    regi_dout <= (others => '0');
    regi_tri  <= (others => '1');

  end generate;

  -- ---------------------------------------------------------------------------
  prc_sticky_ctrl_regs : process (clk) is begin
    if rising_edge(clk) then
      if regw_dout then
        gpio_out <= rego_dout;
      end if;

      if regw_tri then
        gpio_tri <= rego_tri;
      end if;

      if srst then
        gpio_out <= G_CH_DFLT_O;
        gpio_tri <= G_CH_DFLT_T;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  u_irq_reg : entity work.irq_reg
  generic map (
    G_WIDTH => G_CH_WIDTH
  )
  port map (
    clk  => clk,
    srst => srst,
    clr  => rego_intsts,
    en   => rego_inten,
    src  => edge,
    sts  => regi_intsts,
    irq  => irq
  );

  prc_edge : process (clk) is begin
    if rising_edge(clk) then
      gpio_in_ff <= gpio_in;
    end if;
  end process;

  edge <= gpio_in_ff xor gpio_in;

end architecture;
