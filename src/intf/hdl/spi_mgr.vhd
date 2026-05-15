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
--# AXI4-Stream Table
--# ----------------------------------------------------------------------------
--# Signal        | Description
--# --------------|-------------------------------------------------------------
--# s_axis.tready | High when module is IDLE and ready for data.
--# s_axis.tvalid | Starts a new SPI transaction.
--# s_axis.tdata  | MOSI data. Format: [Data (2^G_WIDTH_BITS)]
--# s_axis.tlast  | TODO: End of transaction. CS is held low for the duration of a
--#               | transaction and toggled back high after tlast. This
--#               | mechanism allows for multi-word transactions.
--# s_axis.tkeep  | Ignore.
--# s_axis.tuser  | Transaction config settings. Format is dependent on generics. Format (MSB to LSB):
--#               | [ CS Index (G_CS_BITS) | CPHA (1) | CPOL (1) ]
--# m_axis.tready | Backpressure.
--# m_axis.tvalid | New MISO data is available.
--# m_axis.tdata  | MISO data. Format: [Data (2^G_WIDTH_BITS)]
--# m_axis.tlast  | TODO: End of transaction.
--# m_axis.tkeep  | Ignore.
--# m_axis.tuser  | Transaction config settings passed through from the input.
--#               | Same format as input. Can be optionally be ignored.
--##############################################################################

-- TODO: Update to support multi-beat transfers.
-- As of now, only single-beat transfers are accepted and tlast passed through.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity spi_mgr is
  generic (
    -- Defines the SPI SCK clock as a ratio of the FPGA clock. For example,
    -- if the FPGA clock is 100 MHz, then G_SCK_DIV=4 results in a SPI SCK
    -- of 25 MHz.
    G_SCK_DIV : positive := 4;
    -- Number of bits used to describe the number of chip-select signals
    G_CS_BITS : natural := 0;
    -- Number of 1/2 SCK periods from CSN falling edge to first SCK active edge
    G_CS_LEAD : positive := 1;
    -- Number of 1/2 SCK periods from last SCK inactive edge to CSN rising edge
    G_CS_LAG : positive := 1;
    -- Number of 1/2 SCK periods for minimum CSN pulse width between transactions
    G_CS_IDLE : positive := 32
  );
  port (
    clk      : in    std_ulogic;
    srst     : in    std_ulogic;
    s_axis   : view  s_axis_v;
    m_axis   : view  m_axis_v;
    spi_sck  : out   std_ulogic;
    spi_csn  : out   std_ulogic_vector((2 ** G_CS_BITS) - 1 downto 0);
    spi_mosi : out   std_ulogic;
    spi_miso : in    std_ulogic
  );
end entity;

architecture rtl of spi_mgr is

  constant DW   : positive := s_axis.tdata'length;
  constant UW   : positive := s_axis.tuser'length;
  constant ULSB : integer  := s_axis.tuser'low;

  constant TUSER_REQUIRED_WIDTH : positive          := 2 + G_CS_BITS;
  constant FSM_CNT_INT_ARR      : int_arr_t(0 to 3) := (
    G_CS_LEAD,
    G_CS_LAG,
    G_CS_IDLE,
    (2 ** DW) - 1
  );

  type   state_t is (
    ST_IDLE, ST_INACTIVE, ST_CS_LEAD, ST_SCK_ON, ST_SCK_OFF, ST_CS_LAG,
    ST_CS_IDLE
  );
  signal state : state_t;

  signal sck_cnt   : natural range 0 to G_SCK_DIV - 1;
  signal fsm_cnt   : natural range 0 to find_max(FSM_CNT_INT_ARR) - 1;
  signal fsm_en    : std_ulogic;
  signal miso_reg  : std_ulogic;
  signal sr        : std_ulogic_vector(DW - 1 downto 0);    -- Shift register
  signal cpol      : std_ulogic;                            -- Clock polarity
  signal cpha      : std_ulogic;                            -- Clock phase
  signal csdec     : natural range 0 to 2 ** G_CS_BITS - 1; -- CS Decode
  signal tuser_reg : std_ulogic_vector(UW - 1 downto 0);
  signal tlast_reg : std_ulogic;

begin

  assert (G_SCK_DIV mod 2) = 0
    report "ERROR: spi_man: G_SCK_DIV must be divisible by 2"
    severity error;

  assert s_axis.tuser'length >= TUSER_REQUIRED_WIDTH
    report "ERROR: spi_mgr: s_axis.tuser is too small. " &
           "Required width: " & integer'image(TUSER_REQUIRED_WIDTH) &
           " Provided width: " & integer'image(s_axis.tuser'length)
    severity failure;

  assert s_axis.tdata'length = m_axis.tdata'length
    report "ERROR: spi_mgr: s_axis.tdata width does not match m_axis.tdata width " &
           "s_axis.tdata width: " & integer'image(m_axis.tdata'length) &
           " m_axis.tdata width: " & integer'image(s_axis.tdata'length)
    severity warning;

  spi_mosi     <= sr(DW - 1);
  cpol         <= tuser_reg(0);
  cpha         <= tuser_reg(1);
  m_axis.tkeep <= (others => '1');

  gen_csdec : if G_CS_BITS = 0 generate
    csdec <= 0;
  else generate
    csdec <= to_integer(unsigned(tuser_reg(G_CS_BITS + ULSB + 2 - 1 downto ULSB + 2)));
  end generate;

  prc_fsm : process (clk) is begin
    if rising_edge(clk) then
      s_axis.tready <= '0';

      if m_axis.tready then
        m_axis.tvalid <= '0';
      end if;

      if fsm_en then
        case state is
          when ST_IDLE =>
            if s_axis.tvalid and not m_axis.tvalid then
              s_axis.tready <= '1';
              --
              sr        <= s_axis.tdata;
              spi_sck   <= s_axis.tuser(0); -- Inactive
              tlast_reg <= s_axis.tlast;
              tuser_reg <= s_axis.tuser;
              --
              fsm_cnt <= 0;
              state   <= ST_INACTIVE;
            end if;

          when ST_INACTIVE =>
            -- This state ensures that SCK is held inactive for
            -- at least half of an sck cycle before CS. This is only needed
            -- because this module allows for run-time setting of cpol.
            spi_csn(csdec) <= '0';
            state          <= ST_CS_LEAD;

          when ST_CS_LEAD =>
            if fsm_cnt = (G_CS_LEAD - 1) then
              if not cpha then
                miso_reg <= spi_miso;
              end if;

              fsm_cnt <= 0;
              spi_sck <= not cpol; -- Active
              state   <= ST_SCK_ON;
            else
              fsm_cnt <= fsm_cnt + 1;
            end if;

          when ST_SCK_ON =>
            if cpha then
              miso_reg <= spi_miso;
            else
              sr(sr'high downto 0) <= sr(sr'high - 1 downto 0) & miso_reg;
            end if;

            if fsm_cnt = (DW - 1) then
              fsm_cnt <= 0;
              state   <= ST_CS_LAG;
            else
              fsm_cnt <= fsm_cnt + 1;
              state   <= ST_SCK_OFF;
            end if;

            spi_sck <= cpol; -- Inactive

          when ST_SCK_OFF =>
            if cpha then
              sr(sr'high downto 0) <= sr(sr'high - 1 downto 0) & miso_reg;
            else
              miso_reg <= spi_miso;
            end if;

            spi_sck <= not cpol; -- Active
            state   <= ST_SCK_ON;

          when ST_CS_LAG =>
            if fsm_cnt = (G_CS_LAG - 1) then
              if cpha then
                sr(sr'high downto 0) <= sr(sr'high - 1 downto 0) & miso_reg;
              end if;

              fsm_cnt <= 0;
              spi_csn <= (others => '1');
              state   <= ST_CS_IDLE;
            else
              fsm_cnt <= fsm_cnt + 1;
            end if;

          when ST_CS_IDLE =>
            if fsm_cnt = (G_CS_IDLE - 1) then
              m_axis.tvalid <= '1';
              m_axis.tdata  <= sr;
              m_axis.tuser  <= tuser_reg;
              m_axis.tlast  <= tlast_reg;
              fsm_cnt       <= 0;
              state         <= ST_IDLE;
            else
              fsm_cnt <= fsm_cnt + 1;
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

  prc_fsm_en : process (clk) is begin
    if rising_edge(clk) then
      if sck_cnt = ((G_SCK_DIV / 2) - 1) then
        sck_cnt <= 0;
        fsm_en  <= '1';
      else
        sck_cnt <= sck_cnt + 1;
        fsm_en  <= '0';
      end if;

      if srst then
        sck_cnt <= 0;
        fsm_en  <= '0';
      end if;
    end if;
  end process;

end architecture;
