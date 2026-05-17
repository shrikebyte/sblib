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
--# -------+--------------------------------------------------------------------
--# Signal | Description
--# -------+--------------------------------------------------------------------
--# s_axis
--# -------+--------------------------------------------------------------------
--# tdata  | SPI MOSI data.
--# tkeep  | Unused by this module. Passed through to the output.
--# tlast  | End of transaction. CS is held low for the duration of a
--#        | transaction and toggled back high after tlast.
--# tuser  | Transaction config settings. Format (MSB to LSB):
--#        | [ CS Index (G_CS_BITS) | CPHA (1) | CPOL (1) ]
--#        | tuser from the first beat of a packet is used for the entire
--#        | packet's transaction. Therefore, tuser for subsequent beats
--#        | in a packet are not .
--# -------+--------------------------------------------------------------------
--# m_axis
--# -------+--------------------------------------------------------------------
--# tdata  | SPI MISO data.
--# tkeep  | Passed through from input.
--# tlast  | End of transaction. Passed through from input.
--# tuser  | Transaction config settings. Passed through from the input.
--# -------+--------------------------------------------------------------------
--#
--# For multi-beat transactions to use a continuous spi_sck, s_axis.tvalid
--# and m_axis.tready must be high for the duration of the packet. Otherwise,
--# spi_sck may have to stretch while waiting for the FPGA to produce the next
--# spi_mosi and or accept the last spi_miso.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity spi_mgr is
  generic (
    -- Defines the spi_sck clock as a ratio of the FPGA clock. For example,
    -- if the FPGA clock is 100 MHz, then G_SCK_DIV=4 results in a spi_sck
    -- of 25 MHz.
    G_SCK_DIV : positive := 4;
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
    clk      : in    std_ulogic;
    srst     : in    std_ulogic;
    s_axis   : view  s_axis_view;
    m_axis   : view  m_axis_view;
    spi_sck  : out   std_ulogic;
    spi_csn  : out   std_ulogic_vector((2 ** G_CS_BITS) - 1 downto 0);
    spi_mosi : out   std_ulogic;
    spi_miso : in    std_ulogic
  );
end entity;

architecture rtl of spi_mgr is

  constant DW   : positive := s_axis.tdata'length;
  constant UW   : positive := s_axis.tuser'length;
  constant KW   : positive := s_axis.tkeep'length;
  constant ULSB : integer  := s_axis.tuser'low;

  constant TUSER_REQUIRED_WIDTH : positive          := 2 + G_CS_BITS;
  constant FSM_CNT_INT_ARR      : int_arr_t(0 to 3) := (
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

  signal sck_cnt   : natural range 0 to G_SCK_DIV - 1;
  signal fsm_cnt   : natural range 0 to find_max(FSM_CNT_INT_ARR) - 1;
  signal fsm_en    : std_ulogic;
  signal miso_reg  : std_ulogic;
  signal sr        : std_ulogic_vector(DW - 1 downto 0);    -- Shift register
  signal sr_nxt    : std_ulogic_vector(DW - 1 downto 0);
  signal sck_idle  : std_ulogic;                            -- Clock polarity
  signal cpha      : std_ulogic;                            -- Clock phase
  signal csdec     : natural range 0 to 2 ** G_CS_BITS - 1; -- CS Decode
  signal tuser_reg : std_ulogic_vector(UW - 1 downto 0);
  signal tkeep_reg : std_ulogic_vector(KW - 1 downto 0);
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

  spi_mosi <= sr(DW - 1);
  sck_idle <= tuser_reg(0); -- CPOL
  cpha     <= tuser_reg(1);
  sr_nxt   <= sr(sr'high - 1 downto 0) & miso_reg;

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
              --
              s_axis.tready <= '1';
              sr            <= s_axis.tdata;
              tkeep_reg     <= s_axis.tkeep;
              tlast_reg     <= s_axis.tlast;
              tuser_reg     <= s_axis.tuser;
              spi_sck       <= s_axis.tuser(0); -- Inactive
              --
              fsm_cnt <= 0;
              state   <= ST_CS_IDLE;
            end if;

          when ST_CS_IDLE =>
            -- Ensures that the subordinate's csn min pulse width time is met
            if fsm_cnt = (G_CS_IDLE - 1) then
              spi_csn(csdec) <= '0';
              fsm_cnt        <= 0;
              state          <= ST_CS_LEAD;
            else
              fsm_cnt <= fsm_cnt + 1;
            end if;

          when ST_CS_LEAD =>
            -- Ensures that the subordinate's csn to sck setup time is met
            if fsm_cnt = (G_CS_LEAD - 1) then
              if not cpha then
                miso_reg <= spi_miso;
              end if;

              fsm_cnt <= 0;
              spi_sck <= not sck_idle;
              state   <= ST_SCK_ON;
            else
              fsm_cnt <= fsm_cnt + 1;
            end if;

          when ST_SCK_ON =>
            if fsm_cnt = (DW - 1) then
              if cpha then
                miso_reg <= spi_miso;
                spi_sck  <= sck_idle;
                fsm_cnt  <= 0;
                state    <= ST_CS_LAG;
              elsif not m_axis.tvalid then
                -- spi_sck might be need to be stretched here
                if tlast_reg then
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= sr_nxt;
                  m_axis.tkeep  <= tkeep_reg;
                  m_axis.tlast  <= tlast_reg;
                  m_axis.tuser  <= tuser_reg;
                  --
                  spi_sck <= sck_idle;
                  fsm_cnt <= 0;
                  state   <= ST_CS_LAG;
                elsif s_axis.tvalid then
                  m_axis.tvalid <= '1';
                  m_axis.tdata  <= sr_nxt;
                  m_axis.tkeep  <= tkeep_reg;
                  m_axis.tlast  <= tlast_reg;
                  m_axis.tuser  <= tuser_reg;
                  --
                  s_axis.tready <= '1';
                  sr            <= s_axis.tdata;
                  tkeep_reg     <= s_axis.tkeep;
                  tlast_reg     <= s_axis.tlast;
                  --
                  spi_sck <= sck_idle;
                  fsm_cnt <= 0;
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
              fsm_cnt <= fsm_cnt + 1;
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
                m_axis.tkeep  <= tkeep_reg;
                m_axis.tlast  <= tlast_reg;
                m_axis.tuser  <= tuser_reg;
                --
                s_axis.tready <= '1';
                sr            <= s_axis.tdata;
                tkeep_reg     <= s_axis.tkeep;
                tlast_reg     <= s_axis.tlast;
                --
                spi_sck <= not sck_idle;
                fsm_cnt <= 0;
                state   <= ST_SCK_ON;
              end if;
            else
              -- Ensures that the subordinate's sck to csn hold time is met
              if fsm_cnt = (G_CS_LAG - 1) then
                if cpha then
                  if not m_axis.tvalid then
                    m_axis.tvalid <= '1';
                    m_axis.tdata  <= sr_nxt;
                    m_axis.tkeep  <= tkeep_reg;
                    m_axis.tlast  <= tlast_reg;
                    m_axis.tuser  <= tuser_reg;
                    --
                    fsm_cnt <= 0;
                    spi_csn <= (others => '1');
                    state   <= ST_IDLE;
                  end if;
                else
                  fsm_cnt <= 0;
                  spi_csn <= (others => '1');
                  state   <= ST_IDLE;
                end if;
              else
                fsm_cnt <= fsm_cnt + 1;
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
