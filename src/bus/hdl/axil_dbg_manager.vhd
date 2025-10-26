--##############################################################################
--# File : axil_dbg_manager.vhd
--# Auth : David Gussler
--# Lang : VHDL '08
--# ============================================================================
--! AXI Lite debug bus manager. This is a state machine with a user-friendly
--! ASCII character based interface on one end and an AXI Lite manager interface
--! on the other end. This module is primarily intended to be connected to a
--! UART to enable a straightforward terminal-based register access interface,
--! but since this uses a set of generic axi streams,
--! any other stream-based interface could be used to manage the bus.
--! For example, a UDP-based ethernet interface would be a faster alternative
--! to UART.
--!
--! The simple user protocol supports two commands: read and write.
--!
--! | Command | Command Format      | Success Resp | Fail Resp |
--! |---------|---------------------|--------------|-----------|
--! | Write   | w aaaaaaaa dddddddd | +            | ! or ?    |
--! | Read    | r aaaaaaaa          | dddddddd     | ! or ?    |
--!
--! The protocol was designed to work equally well with an interactive terminal
--! or a scripted software parser. An interactive terminal could be used
--! for short-term experiments and edits, while a software parser could be used
--! to programmatically interface with the device, for example, as a layer
--! between the hardware and a GUI.
--!
--! * 'w' or 'W' is a write command.
--! * 'r' or 'R' is a read command.
--! * 'aaaaaaaa' is a 32-bit hex formatted address. It can be anywhere
--!    from 1 to 8 characters.
--! * 'dddddddd' is a 32-bit hex formatted data value. It can be anywhere
--!    from 1 to 8 characters.
--! * '+' is a write success response, returned by the FPGA.
--! * '!' is a bus error response, returned by the FPGA.
--! * '?' is a unknown command or badly formatted command response, returned
--!    by the FPGA.
--! * '<LF>' is a line feed character
--!   (the enter key). This marks the end of every command or response (not
--!   shown in the command table).
--! * Some terminal emulators use <CR><LF> for enter (carriage return followed
--!   by line feed). This protocol is only sensitive to <LF>. <CR> will be
--!   ignored.
--! * Only supports 32-bit aligned access.
--! * Backspaces are supported.
--! * Protocol is case insensitive.
--! * Leading zeros are optional in addresses and data.
--! * Only hex format is supported for address and data.
--! * No leading `0x` for the address and data.
--! * Extraneous spaces are trimmed.
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.util_pkg.all;

entity axil_dbg_manager is
  port (
    -- System
    clk  : in    std_logic;
    srst : in    std_logic;

    -- Command
    s_cmd_valid : in    std_logic;
    s_cmd_ready : out   std_logic;
    s_cmd_data  : in    std_logic_vector(7 downto 0);

    -- Response
    m_rsp_valid : out   std_logic;
    m_rsp_ready : in    std_logic;
    m_rsp_data  : out   std_logic_vector(7 downto 0);

    -- AXI Lite manager
    m_axil_req : out   axil_req_t;
    m_axil_rsp : in    axil_rsp_t
  );
end entity;

architecture rtl of axil_dbg_manager is

  type state_t is (
    ST_RESET, ST_START, ST_DONE, ST_WRITE_WAIT, ST_WRITE_RSP_WAIT,
    ST_READ_WAIT, ST_READ_RSP_WAIT
  );

  signal state : state_t;

  signal reset_cnt : integer range 0 to G_RESET_DELAY_CLKS - 1;
  signal idx       : integer range 0 to NUM_XACTIONS;

begin

  -- ---------------------------------------------------------------------------
  m_axil_req.awprot <= b"000";
  m_axil_req.arprot <= b"000";

  -- ---------------------------------------------------------------------------
  prc_fsm : process (clk) is begin
    if rising_edge(clk) then
      -- Pulse
      m_sts_valid <= '0';

      case state is
        -- ---------------------------------------------------------------------
        when ST_RESET =>
          if reset_cnt = G_RESET_DELAY_CLKS - 1 then
            state <= ST_START;
          else
            reset_cnt <= reset_cnt + 1;
          end if;

        -- ---------------------------------------------------------------------
        when ST_START =>
          if idx = NUM_XACTIONS then
            state <= ST_DONE;
          elsif G_XACTIONS(idx).cmd = BUS_WRITE then
            m_axil_req.awvalid <= '1';
            m_axil_req.awaddr  <= G_XACTIONS(idx).addr;
            m_axil_req.wvalid  <= '1';
            m_axil_req.wdata   <= G_XACTIONS(idx).data;
            m_axil_req.wstrb   <= G_XACTIONS(idx).wstrb;
            m_axil_req.bready  <= '0';
            --
            state <= ST_WRITE_WAIT;
          elsif G_XACTIONS(idx).cmd = BUS_CHECK then
            m_axil_req.arvalid <= '1';
            m_axil_req.araddr  <= G_XACTIONS(idx).addr;
            m_axil_req.rready  <= '0';
            --
            state <= ST_READ_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_WAIT =>
          if m_axil_rsp.awready and m_axil_rsp.wready then
            m_axil_req.awvalid <= '0';
            m_axil_req.wvalid  <= '0';
            m_axil_req.bready  <= '1';
            --
            state <= ST_WRITE_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_WRITE_RSP_WAIT =>
          if m_axil_rsp.bvalid then
            m_axil_req.bready <= '0';
            --
            m_sts_valid    <= '1';
            m_sts_xact_idx <= to_unsigned(idx, m_sts_xact_idx'length);
            m_sts_chk_err  <= '0';
            if m_axil_rsp.bresp = AXI_RSP_SLVERR or m_axil_rsp.bresp = AXI_RSP_DECERR then
              m_sts_bus_err <= '1';
            else
              m_sts_bus_err <= '0';
            end if;
            --
            idx   <= idx + 1;
            state <= ST_START;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_WAIT =>
          if m_axil_rsp.arready then
            m_axil_req.arvalid <= '0';
            m_axil_req.rready  <= '1';
            --
            state <= ST_READ_RSP_WAIT;
          end if;

        -- ---------------------------------------------------------------------
        when ST_READ_RSP_WAIT =>
          if m_axil_rsp.rvalid then
            m_axil_req.rready <= '0';
            --
            m_sts_valid     <= '1';
            m_sts_xact_idx  <= to_unsigned(idx, m_sts_xact_idx'length);
            m_sts_chk_rdata <= m_axil_rsp.rdata;
            if m_axil_rsp.rresp = AXI_RSP_SLVERR or m_axil_rsp.rresp = AXI_RSP_DECERR then
              m_sts_bus_err <= '1';
              m_sts_chk_err <= '0';
            elsif (m_axil_rsp.rdata and G_XACTIONS(idx).mask) /= (G_XACTIONS(idx).data and G_XACTIONS(idx).mask) then
              m_sts_bus_err <= '0';
              m_sts_chk_err <= '1';
            else
              m_sts_bus_err <= '0';
              m_sts_chk_err <= '0';
            end if;
            --
            idx   <= idx + 1;
            state <= ST_START;
          end if;

        when others =>
          null;
      end case;

      if srst then
        m_sts_valid <= '0';
        --
        m_axil_req.awvalid <= '0';
        m_axil_req.wvalid  <= '0';
        m_axil_req.bready  <= '0';
        m_axil_req.arvalid <= '0';
        m_axil_req.rready  <= '0';
        --
        reset_cnt <= 0;
        idx       <= 0;
        state     <= ST_RESET;
      end if;

    end if;
  end process;

end architecture;
