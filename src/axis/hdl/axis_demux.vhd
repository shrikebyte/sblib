--##############################################################################
--# File : axis_demux.vhd
--# Auth : David Gussler
--# Lang : VHDL'19
--# ============================================================================
--! AXI-Stream de-multiplexer.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_demux is
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    --
    s_axis : view s_axis_v;
    --
    m_axis : view (m_axis_v) of axis_arr_t;
    --! Output select
    sel    : in integer range m_axis'range;
  );
end entity;

architecture rtl of axis_demux is

  type state_t is (ST_UNLOCKED, ST_LOCKED);
  signal state_reg : state_t;
  signal state_nxt : state_t;
  signal sel_reg : integer range m_axis'range;
  signal sel_nxt : integer range m_axis'range;

  signal int_axis : axis_t (
    tdata(s_axis.tdata'range),
    tkeep(s_axis.tkeep'range),
    tuser(s_axis.tuser'range)
  );

begin

  -- ---------------------------------------------------------------------------
  prc_select_comb : process(all) begin
    sel_nxt <= sel_reg;
    state_nxt <= state_reg;

    case state_reg is
      when ST_UNLOCKED =>
        if s_axis.tvalid then
          sel_nxt <= sel;
          state_nxt <= ST_LOCKED;
        end if;
      when ST_LOCKED =>
        if m_axis(sel_reg).tvalid and
            m_axis(sel_reg).tready and
            m_axis(sel_reg).tlast then
          if s_axis.tvalid then
            sel_nxt <= sel;
          else
            state_nxt <= ST_UNLOCKED;
          end if;
        end if;
    end case;
  end process;

  prc_select_ff : process(clk) begin
    if rising_edge(clk) then
      sel_reg <= sel_nxt;
      state_reg <= state_nxt;

      if srst then
        sel_reg    <= m_axis'low;
        state_reg  <= ST_UNLOCKED;
      end if;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  prc_out_reg : process (clk) begin
    if rising_edge(clk) then
      if s_axis.tvalid and s_axis.tready then
        int_axis.tlast <= s_axis.tlast;
        int_axis.tdata <= s_axis.tdata;
        int_axis.tkeep <= s_axis.tkeep;
        int_axis.tuser <= s_axis.tuser;
      end if;
    end if;
  end process;

  gen_assign_m_axis : for i in m_axis'range generate
    prc_out_sel : process (clk) begin
      if rising_edge(clk) then
        if s_axis.tvalid and s_axis.tready and to_sl((sel_nxt = i)) then
          m_axis(i).tvalid <= '1';
        elsif m_axis(i).tready then
          m_axis(i).tvalid <= '0';
        end if;
        if srst then
          m_axis(i).tvalid <= '0';
        end if;
      end if;
    end process;

    m_axis(i).tlast <= int_axis.tlast;
    m_axis(i).tdata <= int_axis.tdata;
    m_axis(i).tkeep <= int_axis.tkeep;
    m_axis(i).tuser <= int_axis.tuser;

  end generate;

  s_axis.tready <= m_axis(sel_reg).tready or not m_axis(sel_reg).tvalid;

end architecture;
