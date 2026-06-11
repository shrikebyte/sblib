--##############################################################################
--# File     : block_avg.vhd
--# Author   : David Gussler
--# Language : VHDL '08
--# ============================================================================
--# Block average & decimator (not a moving average filter)
--#
--# --------+-------------------------------------------------------------------
--# Signal  | Description
--# --------+-------------------------------------------------------------------
--# s_axis
--# --------+-------------------------------------------------------------------
--# tdata   | Input data. Signed or unsigned format is specified by G_SIGNED.
--# tkeep   | Unused.
--# tlast   | Unused.
--# tuser   | Unused.
--# --------+-------------------------------------------------------------------
--# m_axis
--# --------+-------------------------------------------------------------------
--# tdata   | Averaged output data.
--# tkeep   | Unused. Output tied high.
--# tlast   | Unused. Output tied high.
--# tuser   | Unused. Output tied low.
--# --------+-------------------------------------------------------------------
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity block_avg is
  generic (
    G_DW : positive;
    -- True = signed format; False = unsigned format
    G_SIGNED : boolean := false;
    -- The default value of 15 for G_MAX_AVGSEL allows for up to 32k samples
    -- to be averaged.
    G_MAX_AVGSEL : positive := 15
  );
  port (
    clk  : in    std_ulogic;
    srst : in    std_ulogic;
    --
    --
    s_axis : view s_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(0 downto 0),
      tuser(0 downto 0)
    );
    --
    m_axis : view m_axis_view of axis_t(
      tdata(G_DW - 1 downto 0),
      tkeep(0 downto 0),
      tuser(0 downto 0)
    );
    --
    -- Defines the number of samples to average together. Can be updated at
    -- run-time, but new values will not become effective until the current
    -- block is completed (ie: until after m_axis_tvalid and m_axis_tready).
    -- Number of samples to average = 2 ^ ctl_avgsel. For example when:
    --   avgsel=0 -> averaging is disabled
    --   avgsel=1 -> 2 samples are averaged
    --   avgsel=2 -> 4 samples are averaged
    --   avgsel=3 -> 8 samples are averaged
    --   avgsel=6 -> 64 samples are averaged
    ctl_avgsel : in    natural range 0 to G_MAX_AVGSEL
  );
end entity;

architecture rtl of block_avg is

  type   state_t is (ST_IDLE, ST_ACTIVE);
  signal state : state_t;

  -- When adding a large number of values together, all having the same bit
  -- width, the number of bits required to hold the result is given by the
  -- original number of bits plus the log, base two, of the number of elements
  -- added together.
  signal accum : signed(G_DW + G_MAX_AVGSEL - 1 downto 0);
  signal cnt   : unsigned(G_MAX_AVGSEL downto 0);
  signal sel   : natural range 0 to G_MAX_AVGSEL;

  impure function to_accum (
    val : std_ulogic_vector
  ) return signed is begin
    if G_SIGNED then
      return resize(signed(val), accum'length);
    else
      return signed(resize(unsigned(val), accum'length));
    end if;
  end function;

begin

  m_axis.tlast <= '1';
  m_axis.tkeep <= (others => '1');
  m_axis.tuser <= (others => '0');
  --
  s_axis.tready <= m_axis.tready or not m_axis.tvalid;
  m_axis.tdata  <= std_ulogic_vector(resize(shift_right(unsigned(accum), sel), G_DW));

  prc_avg : process (clk) is begin
    if rising_edge(clk) then
      if m_axis.tready then
        m_axis.tvalid <= '0';
      end if;

      if s_axis.tvalid and s_axis.tready then
        case state is
          when ST_IDLE =>
            accum <= to_accum(s_axis.tdata);
            cnt   <= to_unsigned(2, cnt'length);
            sel   <= ctl_avgsel;

            if ctl_avgsel = 0 then
              m_axis.tvalid <= '1';
            else
              state <= ST_ACTIVE;
            end if;

          when ST_ACTIVE =>
            accum <= accum + to_accum(s_axis.tdata);

            if cnt(sel) = '1' then
              m_axis.tvalid <= '1';
              state         <= ST_IDLE;
            else
              cnt <= cnt + 1;
            end if;
        end case;

      end if;

      if srst then
        m_axis.tvalid <= '0';
        state         <= ST_IDLE;
      end if;
    end if;
  end process;

end architecture;
