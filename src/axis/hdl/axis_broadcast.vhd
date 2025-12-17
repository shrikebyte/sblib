--##############################################################################
--# File : axis_broadcast.vhd
--# Auth : David Gussler
--# Lang : VHDL'19
--# ============================================================================
--! AXI-Stream Broadcast. Duplicate one input stream to several output streams.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;
use work.axis_pkg.all;

entity axis_broadcast is
  generic (
    --! Add an extra pipeline register to the internal datapath.
    G_DATA_PIPE  : boolean  := false;
    --! Add an extra pipeline register to the internal backpressure path.
    G_READY_PIPE : boolean  := false
  );
  port (
    clk    : in    std_ulogic;
    srst   : in    std_ulogic;
    --
    s_axis : view s_axis_v;
    --
    m_axis : view (m_axis_v) of axis_arr_t;
  );
end entity;

architecture rtl of axis_broadcast is

  signal int_axis_tready : std_ulogic_vector(m_axis'range);

  signal int_axis : axis_arr_t(m_axis'range) (
    tdata(s_axis.tdata'range),
    tkeep(s_axis.tkeep'range),
    tuser(s_axis.tuser'range)
  );
begin

  s_axis.tready <= and int_axis_tready;

  gen_broadcast : for i in m_axis'range generate

    int_axis_tready(i) <= int_axis(i).tready;

    int_axis(i).tvalid <= s_axis.tvalid and s_axis.tready;
    int_axis(i).tlast  <= s_axis.tlast;
    int_axis(i).tdata  <= s_axis.tdata;
    int_axis(i).tkeep  <= s_axis.tkeep;
    int_axis(i).tuser  <= s_axis.tuser;

    u_axis_pipe : entity work.axis_pipe
    generic map(
      G_DATA_PIPE  => G_DATA_PIPE,
      G_READY_PIPE => G_READY_PIPE
    )
    port map(
      clk    => clk,
      srst   => srst,
      s_axis => int_axis(i),
      m_axis => m_axis(i)
    );

  end generate;

end architecture;
