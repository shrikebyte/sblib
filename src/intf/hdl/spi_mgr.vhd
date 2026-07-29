--##############################################################################
--# File : spi_mgr.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# SPI manager
--#
--# For multi-beat transactions to use a continuous spi_sck, s_axis.tvalid
--# and m_axis.tready must be high for the duration of the packet. Otherwise,
--# spi_sck may have to stretch while waiting for the FPGA to produce the next
--# spi_mosi and or accept the last spi_miso.
--#
--# --------+-------------------------------------------------------------------
--# Signal  | Description
--# --------+-------------------------------------------------------------------
--# s_axis
--# --------+-------------------------------------------------------------------
--# tdata   | SPI MOSI data.
--# tkeep   | Unused.
--# tlast   | End of transaction. CS is held low for the duration of a
--#         | transaction and toggled back high after tlast.
--# tuser   | Transaction config settings.
--#         | tuser from the first beat of a packet is used for the entire
--#         | packet's transaction. Therefore, tuser for subsequent beats
--#         | in a packet are not used.
--# tuser(0)| CPOL
--# tuser(1)| CPHA
--# tuser(G_CS_BITS + 2 - 1 downto 2)| Chip-select
--# --------+-------------------------------------------------------------------
--# m_axis
--# --------+-------------------------------------------------------------------
--# tdata   | SPI MISO data.
--# tkeep   | Unused. Output tied high.
--# tlast   | End of transaction.
--# tuser   | Transaction config settings. Passed through from the input.
--# --------+-------------------------------------------------------------------
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity spi_mgr is
  generic (
    -- Data width
    G_DW : positive;
    -- Actual internal system clock
    G_SYS_CLK_HZ : positive := 100_000_000;
    -- Requested external SPI clock
    G_SPI_CLK_HZ : positive := 5_000_000;
    -- Percent error allowed in requested vs actual spi clk rate
    G_CLK_TOLERANCE : real := 2.5;
    -- Number of bits used to describe the number of spi_csn signals
    G_CS_BITS : natural := 0;
    -- Number of 1/2 spi_sck periods from spi_csn falling edge to first spi_sck active edge
    G_CS_LEAD : positive := 1;
    -- Number of 1/2 spi_sck periods from last spi_sck inactive edge to spi_csn rising edge
    G_CS_LAG : positive := 1;
    -- Number of 1/2 spi_sck periods for minimum spi_csn pulse width between transactions
    G_CS_IDLE : positive := 32
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    s_axis : view s_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(0 downto 0),
      tuser(G_CS_BITS + 2 - 1 downto 0)
    );
    --
    m_axis : view m_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(0 downto 0),
      tuser(G_CS_BITS + 2 - 1 downto 0)
    );
    --
    spi_sck  : out   std_ulogic;
    spi_csn  : out   std_ulogic_vector((2 ** G_CS_BITS) - 1 downto 0);
    spi_mosi : out   std_ulogic;
    spi_miso : in    std_ulogic
  );
end entity;

architecture rtl of spi_mgr is

  constant DW : positive := G_DW;
  constant UW : positive := G_CS_BITS + 2;

  constant CNT_INT_ARR : int_arr_t(0 to 3) := (
    G_CS_LEAD,
    G_CS_LAG,
    G_CS_IDLE,
    (2 ** DW) - 1
  );

  type   state_t is (
    ST_IDLE, ST_CS_LEAD, ST_SCK_ON, ST_SCK_OFF, ST_CS_LAG,
    ST_CS_IDLE
  );
  signal state : state_t;

  signal cnt       : natural range 0 to find_max(CNT_INT_ARR) - 1;
  signal tick      : std_ulogic;
  signal miso_reg  : std_ulogic;
  signal sr        : std_ulogic_vector(DW - 1 downto 0);    -- Shift register
  signal sr_nxt    : std_ulogic_vector(DW - 1 downto 0);
  signal sck_idle  : std_ulogic;                            -- Clock polarity
  signal cpha      : std_ulogic;                            -- Clock phase
  signal csdec     : natural range 0 to 2 ** G_CS_BITS - 1; -- CS Decode
  signal tlast_reg : std_ulogic;
  signal tuser_reg : std_ulogic_vector(UW - 1 downto 0);

begin

  m_axis.tkeep <= (others => '1');
  --
  spi_mosi <= sr(DW - 1);
  sck_idle <= tuser_reg(0); -- CPOL
  cpha     <= tuser_reg(1); -- CPHA
  sr_nxt   <= sr(sr'high - 1 downto 0) & miso_reg;

  gen_csdec : if G_CS_BITS = 0 generate
    csdec <= 0;
  else generate
    csdec <= to_integer(unsigned(tuser_reg(G_CS_BITS + 2 - 1 downto 2)));
  end generate;

  prc_spi : process (clk) is begin
    if rising_edge(clk) then
      s_axis.tready <= '0';
      m_axis.tvalid <= '0' when m_axis.tready;

      if tick then
        case state is
          when ST_IDLE =>
            if s_axis.tvalid and not m_axis.tvalid then
              --
              s_axis.tready <= '1';
              sr            <= s_axis.tdata;
              tlast_reg     <= s_axis.tlast;
              tuser_reg     <= s_axis.tuser;
              spi_sck       <= s_axis.tuser(0); -- Inactive
              --
              cnt   <= 0;
              state <= ST_CS_IDLE;
            end if;

          when ST_CS_IDLE =>
            -- Ensures that the subordinate's csn min pulse width time is met
            if cnt = (G_CS_IDLE - 1) then
              spi_csn(csdec) <= '0';
              cnt            <= 0;
              state          <= ST_CS_LEAD;
            else
              cnt <= cnt + 1;
            end if;

          when ST_CS_LEAD =>
            -- Ensures that the subordinate's csn to sck setup time is met
            if cnt = (G_CS_LEAD - 1) then
              if not cpha then
                miso_reg <= spi_miso;
              end if;

              cnt     <= 0;
              spi_sck <= not sck_idle;
              state   <= ST_SCK_ON;
            else
              cnt <= cnt + 1;
            end if;

          when ST_SCK_ON =>
            if cnt = (DW - 1) then
              if cpha then
                miso_reg <= spi_miso;
                spi_sck  <= sck_idle;
                cnt      <= 0;
                state    <= ST_CS_LAG;
              elsif not m_axis.tvalid then
                -- spi_sck might be need to be stretched here
                if tlast_reg then
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= sr_nxt;
                  m_axis.tlast  <= tlast_reg;
                  m_axis.tuser  <= tuser_reg;
                  --
                  spi_sck <= sck_idle;
                  cnt     <= 0;
                  state   <= ST_CS_LAG;
                elsif s_axis.tvalid then
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= sr_nxt;
                  m_axis.tlast  <= tlast_reg;
                  m_axis.tuser  <= tuser_reg;
                  --
                  s_axis.tready <= '1';
                  sr            <= s_axis.tdata;
                  tlast_reg     <= s_axis.tlast;
                  --
                  spi_sck <= sck_idle;
                  cnt     <= 0;
                  state   <= ST_SCK_OFF;
                end if;
              end if;
            else
              if cpha then
                miso_reg <= spi_miso;
              else
                sr <= sr_nxt;
              end if;

              spi_sck <= sck_idle;
              cnt     <= cnt + 1;
              state   <= ST_SCK_OFF;
            end if;

          when ST_SCK_OFF =>
            if cpha then
              sr <= sr_nxt;
            else
              miso_reg <= spi_miso;
            end if;

            spi_sck <= not sck_idle;
            state   <= ST_SCK_ON;

          when ST_CS_LAG =>
            if cpha and not tlast_reg then
              -- spi_sck might be need to be stretched here
              if s_axis.tvalid and not m_axis.tvalid then
                m_axis.tvalid <= '1';
                m_axis.tdata  <= sr_nxt;
                m_axis.tlast  <= tlast_reg;
                m_axis.tuser  <= tuser_reg;
                --
                s_axis.tready <= '1';
                sr            <= s_axis.tdata;
                tlast_reg     <= s_axis.tlast;
                --
                spi_sck <= not sck_idle;
                cnt     <= 0;
                state   <= ST_SCK_ON;
              end if;
            else
              -- Ensures that the subordinate's sck to csn hold time is met
              if cnt = (G_CS_LAG - 1) then
                if cpha then
                  if not m_axis.tvalid then
                    m_axis.tvalid <= '1';
                    m_axis.tdata  <= sr_nxt;
                    m_axis.tlast  <= tlast_reg;
                    m_axis.tuser  <= tuser_reg;
                    --
                    cnt     <= 0;
                    spi_csn <= (others => '1');
                    state   <= ST_IDLE;
                  end if;
                else
                  cnt     <= 0;
                  spi_csn <= (others => '1');
                  state   <= ST_IDLE;
                end if;
              else
                cnt <= cnt + 1;
              end if;
            end if;

          when others =>
            null;
        end case;

      end if;

      if srst then
        m_axis.tvalid <= '0';
        s_axis.tready <= '0';
        spi_sck       <= '0';
        spi_csn       <= (others => '1');
        sr            <= (others => '0');
        state         <= ST_IDLE;
      end if;
    end if;
  end process;

  u_tick : entity work.tick
  generic map (
    G_CLK_HZ    => G_SYS_CLK_HZ,
    G_TICK_HZ   => G_SPI_CLK_HZ * 2,
    G_TOLERANCE => G_CLK_TOLERANCE
  )
  port map (
    clk  => clk,
    srst => srst,
    tick => tick
  );

end architecture;
