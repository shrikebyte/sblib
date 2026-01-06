--##############################################################################
--# File : ebtb_tb.vhd
--# Auth : Chuck Benz, Frans Schreuder, with modifications by David Gussler
--# ============================================================================
--# Copyright 2002    Chuck Benz, Hollis, NH
--# Copyright 2020    Frans Schreuder
--#
--# Licensed under the Apache License, Version 2.0 (the "License");
--# you may not use this file except in compliance with the License.
--# You may obtain a copy of the License at
--#
--#     http://www.apache.org/licenses/LICENSE-2.0
--#
--# Unless required by applicable law or agreed to in writing, software
--# distributed under the License is distributed on an "AS IS" BASIS,
--# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--# See the License for the specific language governing permissions and
--# limitations under the License.
--#
--# The information and description contained herein is the
--# property of Chuck Benz.
--#
--# Permission is granted for any reuse of this information
--# and description as long as this copyright notice is
--# preserved.  Modifications may be made as long as this
--# notice is preserved.
--# ============================================================================
--# Changelog:
--# 11 October 2002: Chuck Benz:
--#   - updated with clearer messages, and checking decodeout
--#
--# 3  November 2020: Frans Schreuder:
--#   - Translated to VHDL, added UVVM testbench
--#   - Original verilog code:
--#     http://asics.chuckbenz.com/#My_open_source_8b10b_encoderdecoder
--#
--# 1  April 2025: David Gussler
--#   - Updated TB to use VUnit to match the rest of the library
--#
--# per Widmer and Franaszek
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
use osvvm.randompkg.all;
use work.ebtb_lookup_pkg.all;

entity ebtb_tb is
  generic (
    RUNNER_CFG : string
  );
end entity;

architecture tb of ebtb_tb is

  -- ---------------------------------------------------------------------------
  -- Testbench Constants
  constant RESET_TIME : time := 50 ns;
  constant CLK_PERIOD : time := 5 ns;
  constant CLK_TO_Q   : time := 0.1 ns;

  -- ---------------------------------------------------------------------------
  -- Testbench Signals
  signal clk   : std_logic := '1';
  signal arst  : std_logic := '1';
  signal srst  : std_logic := '1';
  signal srstn : std_logic := '0';

  signal encodein                  : std_logic_vector(8 downto 0);
  signal encodein_p1               : std_logic_vector(8 downto 0);
  signal encodein_p2               : std_logic_vector(8 downto 0);
  signal encodein_p3               : std_logic_vector(8 downto 0);
  signal i                         : integer                      := 0;
  signal encodeout                 : std_logic_vector(9 downto 0) := (others => '0');
  signal encodeout_vr              : std_logic_vector(9 downto 0) := (others => '0');
  signal encodeout_vrev            : std_logic_vector(9 downto 0) := (others => '0');
  signal encodeout_v               : std_logic_vector(0 to 9)     := (others => '0');
  signal decodein_v                : std_logic_vector(0 to 9)     := (others => '0');
  signal decodeerr,    disperr     : std_logic                    := '0';
  signal decodeerr_v,  disperr_v   : std_logic                    := '0';
  signal decodeerr_vr, disperr_vr  : std_logic                    := '0';
  signal enc_dispin,   enc_dispout : std_logic                    := '0';
  signal dec_dispin,   dec_dispout : std_logic                    := '0';
  signal decodeout                 : std_logic_vector(8 downto 0) := (others => '0');
  signal decodeout_v               : std_logic_vector(8 downto 0) := (others => '0');
  signal decodeout_vr              : std_logic_vector(8 downto 0) := (others => '0');

  signal code : code_type_t;

  -- mark every used 10b symbol as legal, leave rest marked as not
  signal legal : std_logic_vector(1023 downto 0);

  -- now mark every used combination of symbol and starting disparity
  signal okdisp   : std_logic_vector(2047 downto 0);
  signal mapcode  : slv9_array_t(1023 downto 0);
  signal decodein : std_logic_vector(9 downto 0) := (others => '0');

begin

  -- ---------------------------------------------------------------------------
  prc_main : process is
  begin

    test_runner_setup(runner, RUNNER_CFG);

    while test_suite loop

      arst <= '1';
      wait for RESET_TIME;
      arst <= '0';

      -- -----------------------------------------------------------------------
      if run("test_0") then
        wait until srst = '0';
        wait until rising_edge(clk);
        info(
          "First, test by trying all 268 (256 Dx.y and 12 Kx.y) " &
          "valid inputs, with both + and - starting disparity."
        );
        info("We check that the encoder output and ending disparity is correct.");
        info("We also check that the decoder matches.");

        for il in 0 to 267 loop
          i        <= il;
          wait until rising_edge(clk);
          decodein <= encodeout;
          wait until rising_edge(clk);

          check_equal(
            (((encodeout /= code.val_10b_neg) and (encodeout /= code.val_10b_pos))),
            false,
            "Check encoding",
            error
          );

          decodein <= encodeout;
          wait until rising_edge(clk);
          decodein <= encodeout;

          check_equal(
            encodein_p3(8 downto 0), decodeout(8 downto 0),
            "Encoder input should match decoder output",
            error
          );

          check_equal(decodeerr, '0', "Check decode error", error);
          check_equal(disperr, '0', "Check disparity error", error);
        end loop;

        info("Now, having verified all legal codes, lets run some illegal codes at the decoder.");
        -- 2048 possible cases, lets mark the OK ones...
        legal  <= (others => '0');
        okdisp <= (others => '0');
        for il in 0 to 267 loop
          i <= il;
          wait until rising_edge(clk);

          legal(to_integer(unsigned(code.val_10b_neg)))   <= '1';
          legal(to_integer(unsigned(code.val_10b_pos)))   <= '1';
          mapcode(to_integer(unsigned(code.val_10b_neg))) <= code.k & code.val_8b;
          mapcode(to_integer(unsigned(code.val_10b_pos))) <= code.k & code.val_8b;
        end loop;

        info("Now lets test all (legal and illegal) codes into the decoder.");
        info("Checking all possible decode inputs.");
        for il in 0 to 1023 loop
          i <= il;
          wait until rising_edge(clk);

          decodein <= std_logic_vector(to_unsigned(i, 10));
          wait until rising_edge(clk);
          wait until rising_edge(clk);

          check_equal(
            ((legal(i) = '0') and (decodeerr /= '1')),
            false,
            "Detection of illegal code",
            warning
          );

          check_equal(
            (legal(i) = '1' and (mapcode(i) /= decodeout)),
            false, "Check decoder output",
            error
          );

          wait until rising_edge(clk);
        end loop;
        info("SIMULATION COMPLETE");

      -- -- -----------------------------------------------------------------------
      -- elsif run("test_1") then

      --   info("Not implemented.");

      end if;

      wait for 100 ns;

    end loop;

    test_runner_cleanup(runner);

  end process;

  -- ---------------------------------------------------------------------------
  -- Helper processes
  prc_tb_pipe : process (clk) is begin
    if rising_edge(clk) then
      if srst then
        encodein_p1 <= (others => '0');
        encodein_p2 <= (others => '0');
        encodein_p3 <= (others => '0');
      else
        encodein_p1 <= code.k & code.val_8b;
        encodein_p2 <= encodein_p1;
        encodein_p3 <= encodein_p2;
      end if;
    end if;
  end process;

  prc_tb_select_code : process (i) is begin
    if i < 268 then
      code <= code8b10b(i);
    else
      code <= ('U', "UUUUUUUU", "UUUUUUUUUU", "UUUUUUUUUU", 'U');
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Clocks & Resets
  clk <= not clk after CLK_PERIOD / 2;

  prc_srst : process (clk) is begin
    if rising_edge(clk) then
      srst  <= arst;
      srstn <= not arst;
    end if;
  end process;

  -- ---------------------------------------------------------------------------
  -- Encoder
  u_ebtb_encode : entity work.ebtb_encode
  port map (
    clk  => clk,
    srst => srst,
    ena  => '1',
    ki   => code.k,
    din  => code.val_8b,
    dout => encodeout
  );

  -- ---------------------------------------------------------------------------
  -- Decoder
  u_ebtb_decode : entity work.ebtb_decode
  port map (
    clk      => clk,
    srst     => srst,
    din      => decodein,
    ena      => '1',
    ko       => decodeout(8),
    dout     => decodeout(7 downto 0),
    code_err => decodeerr,
    disp_err => disperr
  );

end architecture;
