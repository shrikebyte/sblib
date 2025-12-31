--##############################################################################
--# File : fifo_async.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! Asynchronous FIFO.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_async is
  generic (
    G_WIDTH         : positive := 32;
    G_DEPTH_P2      : positive := 10;
    G_SYNC_LEN      : positive := 2;
    G_ALM_EMPTY_LVL : natural  := 4;
    G_ALM_FULL_LVL  : natural  := 1020;
    G_OUT_REG       : boolean  := false
  );
  port (
    -- -------------------------------------------------------------------------
    -- System
    -- -------------------------------------------------------------------------
    --! Async reset. Must be asserted for at least G_SYNC_LEN times the period
    --! of the slower clock. Asserting the reset for less time than this could
    --! result in undefined behavior.
    arst : in    std_logic;

    -- -------------------------------------------------------------------------
    -- Slave
    -- -------------------------------------------------------------------------
    s_clk : in    std_logic;

    -- Source Stream
    s_valid : in    std_logic;
    s_ready : out   std_logic;
    s_data  : in    std_logic_vector(G_WIDTH - 1 downto 0);

    -- Source Status
    s_alm_full : out   std_logic;
    s_fill_lvl : out   std_logic_vector(G_DEPTH_P2 downto 0);

    -- -------------------------------------------------------------------------
    -- Master
    -- -------------------------------------------------------------------------
    m_clk : in    std_logic;

    -- Destination Stream
    m_valid : out   std_logic;
    m_ready : in    std_logic;
    m_data  : out   std_logic_vector(G_WIDTH - 1 downto 0);

    -- Destination Status
    m_alm_empty : out   std_logic;
    m_fill_lvl  : out   std_logic_vector(G_DEPTH_P2 downto 0)
  );
end entity;

architecture rtl of fifo_async is

  constant DEPTH : positive := 2 ** G_DEPTH_P2;

  type ram_t is array(natural range 0 to DEPTH - 1) of
    std_logic_vector(G_WIDTH - 1 downto 0);

  signal ram           : ram_t;
  signal s_srst        : std_logic;
  signal m_srst        : std_logic;
  signal s_wr_en       : std_logic;
  signal m_rd_en       : std_logic;
  signal s_wr_ptr_nxt  : unsigned(G_DEPTH_P2 downto 0);
  signal s_wr_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal s_rd_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal s_wr_ptr_slv  : std_logic_vector(G_DEPTH_P2 downto 0);
  signal s_rd_ptr_slv  : std_logic_vector(G_DEPTH_P2 downto 0);
  signal m_rd_ptr_nxt  : unsigned(G_DEPTH_P2 downto 0);
  signal m_rd_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal m_wr_ptr      : unsigned(G_DEPTH_P2 downto 0);
  signal m_rd_ptr_slv  : std_logic_vector(G_DEPTH_P2 downto 0);
  signal m_wr_ptr_slv  : std_logic_vector(G_DEPTH_P2 downto 0);
  signal s_fill_lvl_us : unsigned(G_DEPTH_P2 downto 0);
  signal m_fill_lvl_us : unsigned(G_DEPTH_P2 downto 0);
  signal ram_valid     : std_logic;
  signal ram_ready     : std_logic;
  signal ram_data      : std_logic_vector(G_WIDTH - 1 downto 0);

begin

  -- ---------------------------------------------------------------------------
  -- Source
  -- ---------------------------------------------------------------------------

  -- ---------------------------------------------------------------------------
  -- Reset CDC
  u_cdc_reset_src : entity work.cdc_reset
  generic map (
    G_SYNC_LEN => G_SYNC_LEN,
    G_NUM_ARST => 1,
    G_ARST_LVL => "1"
  )
  port map (
    arst(0) => arst,
    clk     => s_clk,
    srst    => s_srst
  );

  -- ---------------------------------------------------------------------------
  -- Comb logic
  s_fill_lvl <= std_logic_vector(s_fill_lvl_us);

  gen_almost_full : if G_ALM_FULL_LVL = 2 ** G_DEPTH_P2 generate
    s_alm_full <= not s_ready;
  else generate
    s_alm_full <= '1' when s_fill_lvl_us > G_ALM_FULL_LVL - 1 else '0';
  end generate;

  s_wr_en <= s_valid and s_ready;

  s_wr_ptr_nxt <= s_wr_ptr + 1 when s_wr_en else s_wr_ptr;

  -- ---------------------------------------------------------------------------
  -- Sync logic
  prc_s_sts : process (s_clk) is begin
    if rising_edge(s_clk) then
      -- Accept new writes when not full
      s_ready <= '1' when
        (s_rd_ptr(G_DEPTH_P2 - 1 downto 0) /= s_wr_ptr_nxt(G_DEPTH_P2 - 1 downto 0))
        or (s_rd_ptr(G_DEPTH_P2) = s_wr_ptr_nxt(G_DEPTH_P2)) else '0';

      s_fill_lvl_us <= s_wr_ptr_nxt - s_rd_ptr;
      s_wr_ptr      <= s_wr_ptr_nxt;

      if s_srst then
        s_ready       <= '0';
        s_fill_lvl_us <= (others => '0');
        s_wr_ptr      <= (others => '0');
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- CDC the source write pointer to the destination domain
  u_cdc_gray_wr_ptr : entity work.cdc_gray
  generic map (
    G_SYNC_LEN => G_SYNC_LEN,
    G_WIDTH    => G_DEPTH_P2 + 1,
    G_OUT_REG  => false
  )
  port map (
    src_clk => s_clk,
    src_cnt => s_wr_ptr_slv,
    dst_clk => m_clk,
    dst_cnt => m_wr_ptr_slv
  );

  s_wr_ptr_slv <= std_logic_vector(s_wr_ptr);
  m_wr_ptr     <= unsigned(m_wr_ptr_slv);

  -- ---------------------------------------------------------------------------
  -- Destination
  -- ---------------------------------------------------------------------------

  -- ---------------------------------------------------------------------------
  -- Reset CDC
  u_cdc_reset_rd : entity work.cdc_reset
  generic map (
    G_SYNC_LEN => G_SYNC_LEN,
    G_NUM_ARST => 1,
    G_ARST_LVL => "1"
  )
  port map (
    arst(0) => arst,
    clk     => m_clk,
    srst    => m_srst
  );

  -- ---------------------------------------------------------------------------
  -- Comb assignments
  m_fill_lvl <= std_logic_vector(m_fill_lvl_us);

  gen_almost_empty : if G_ALM_EMPTY_LVL = 0 generate
    m_alm_empty <= not ram_valid;
  else generate
    m_alm_empty <= '1' when m_fill_lvl_us < G_ALM_EMPTY_LVL + 1 else '0';
  end generate;

  m_rd_en <= ram_valid and ram_ready;

  m_rd_ptr_nxt <= m_rd_ptr + 1 when m_rd_en else m_rd_ptr;

  -- ---------------------------------------------------------------------------
  -- Destination registers
  prc_m_sts : process (m_clk) is begin
    if rising_edge(m_clk) then
      -- Destination valid when not empty
      ram_valid <= '1' when m_wr_ptr /= m_rd_ptr_nxt else '0';

      m_fill_lvl_us <= m_wr_ptr - m_rd_ptr_nxt;
      m_rd_ptr      <= m_rd_ptr_nxt;

      if m_srst then
        ram_valid     <= '0';
        m_fill_lvl_us <= (others => '0');
        m_rd_ptr      <= (others => '0');
      end if;

    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- CDC the destination read pointer to the source domain
  u_cdc_gray_rd_ptr : entity work.cdc_gray
  generic map (
    G_SYNC_LEN => G_SYNC_LEN,
    G_WIDTH    => G_DEPTH_P2 + 1,
    G_OUT_REG  => false
  )
  port map (
    src_clk => m_clk,
    src_cnt => m_rd_ptr_slv,
    dst_clk => s_clk,
    dst_cnt => s_rd_ptr_slv
  );

  m_rd_ptr_slv <= std_logic_vector(m_rd_ptr);
  s_rd_ptr     <= unsigned(s_rd_ptr_slv);

  -- ---------------------------------------------------------------------------
  -- RAM
  -- ---------------------------------------------------------------------------

  -- ---------------------------------------------------------------------------
  -- RAM writes
  prc_ram_wr : process (s_clk) is begin
    if rising_edge(s_clk) then
      if s_wr_en then
        ram(to_integer(s_wr_ptr(G_DEPTH_P2 - 1 downto 0))) <= s_data;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- RAM reads
  prc_ram_rd : process (m_clk) is begin
    if rising_edge(m_clk) then
      ram_data <= ram(to_integer(m_rd_ptr_nxt(G_DEPTH_P2 - 1 downto 0)));
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Optional output reg
  -- ---------------------------------------------------------------------------
  u_strm_pipe : entity work.strm_pipe
  generic map (
    G_WIDTH      => G_WIDTH,
    G_READY_PIPE => false,
    G_DATA_PIPE  => G_OUT_REG
  )
  port map (
    clk     => m_clk,
    srst    => m_srst,
    s_valid => ram_valid,
    s_ready => ram_ready,
    s_data  => ram_data,
    m_valid => m_valid,
    m_ready => m_ready,
    m_data  => m_data
  );

end architecture;
