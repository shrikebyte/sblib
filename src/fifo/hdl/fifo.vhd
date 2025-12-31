--##############################################################################
--# File : fifo.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! Synchronous fifo.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
  generic (
    G_WIDTH         : positive := 32;
    G_DEPTH_P2      : positive := 10;
    G_ALM_EMPTY_LVL : natural  := 4;
    G_ALM_FULL_LVL  : natural  := 1020;
    G_OUT_REG       : boolean  := false
  );
  port (
    -- System
    clk  : in    std_logic;
    srst : in    std_logic;

    -- Slave Write Port
    s_valid : in    std_logic;
    s_ready : out   std_logic;
    s_data  : in    std_logic_vector(G_WIDTH - 1 downto 0);

    -- Master Read Port
    m_valid : out   std_logic;
    m_ready : in    std_logic;
    m_data  : out   std_logic_vector(G_WIDTH - 1 downto 0);

    -- Status
    alm_full  : out   std_logic;
    alm_empty : out   std_logic;
    fill_lvl  : out   std_logic_vector(G_DEPTH_P2 downto 0)
  );
end entity;

architecture rtl of fifo is

  constant DEPTH : positive := 2 ** G_DEPTH_P2;

  type ram_t is array(natural range 0 to DEPTH - 1) of
    std_logic_vector(G_WIDTH - 1 downto 0);

  signal ram         : ram_t;
  signal wr_en       : std_logic;
  signal rd_en       : std_logic;
  signal wr_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal rd_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal wr_ptr_nxt  : unsigned(G_DEPTH_P2 downto 0);
  signal rd_ptr_nxt  : unsigned(G_DEPTH_P2 downto 0);
  signal fill_lvl_us : unsigned(G_DEPTH_P2 downto 0);
  signal ram_valid   : std_logic;
  signal ram_ready   : std_logic;
  signal ram_data    : std_logic_vector(G_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  -- Comb logic
  fill_lvl <= std_logic_vector(fill_lvl_us);

  gen_almost_full : if G_ALM_FULL_LVL = 2 ** G_DEPTH_P2 generate
    alm_full <= not s_ready;
  else generate
    alm_full <= '1' when fill_lvl_us > G_ALM_FULL_LVL - 1 else '0';
  end generate;

  gen_almost_empty : if G_ALM_EMPTY_LVL = 0 generate
    alm_empty <= not ram_valid;
  else generate
    alm_empty <= '1' when fill_lvl_us < G_ALM_EMPTY_LVL + 1 else '0';
  end generate;

  -- Detect axis transactions
  wr_en <= s_valid and s_ready;
  rd_en <= ram_valid and ram_ready;

  -- Increment pointers on each valid transaction
  wr_ptr_nxt <= wr_ptr + 1 when wr_en else wr_ptr;
  rd_ptr_nxt <= rd_ptr + 1 when rd_en else rd_ptr;

  -- ---------------------------------------------------------------------------
  -- Sync logic
  prc_sts : process (clk) is begin
    if rising_edge(clk) then
      -- Output data valid when not empty
      ram_valid <= '1' when wr_ptr /= rd_ptr_nxt else '0';

      -- Can accept new writes when not full
      s_ready <= '1' when
        (rd_ptr(G_DEPTH_P2 - 1 downto 0) /= wr_ptr_nxt(G_DEPTH_P2 - 1 downto 0))
        or (rd_ptr(G_DEPTH_P2) = wr_ptr_nxt(G_DEPTH_P2)) else '0';

      -- Fifo fill level calculation
      fill_lvl_us <= wr_ptr_nxt - rd_ptr_nxt;

      -- Update pointer registers
      wr_ptr <= wr_ptr_nxt;
      rd_ptr <= rd_ptr_nxt;

      if srst then
        ram_valid   <= '0';
        s_ready     <= '0';
        fill_lvl_us <= (others => '0');
        wr_ptr      <= (others => '0');
        rd_ptr      <= (others => '0');
      end if;

    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- RAM
  prc_ram : process (clk) is begin
    if rising_edge(clk) then
      if wr_en then
        ram(to_integer(wr_ptr(G_DEPTH_P2 - 1 downto 0))) <= s_data;
      end if;

      ram_data <= ram(to_integer(rd_ptr_nxt(G_DEPTH_P2 - 1 downto 0)));

    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Optional output reg
  u_strm_pipe : entity work.strm_pipe
  generic map (
    G_WIDTH      => G_WIDTH,
    G_READY_PIPE => false,
    G_DATA_PIPE  => G_OUT_REG
  )
  port map (
    clk     => clk,
    srst    => srst,
    s_valid => ram_valid,
    s_ready => ram_ready,
    s_data  => ram_data,
    m_valid => m_valid,
    m_ready => m_ready,
    m_data  => m_data
  );

end architecture;
