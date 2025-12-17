-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- BFM for sending data on an AXI-Stream interface.
--
-- Data is pushed to the ``data_queue`` :doc:`VUnit queue <vunit:data_types/queue>` as a
-- :doc:`VUnit integer_array <vunit:data_types/integer_array>`.
-- Each element in the integer array should be an unsigned byte.
-- Little endian byte order is assumed.
--
--
-- Randomization
-- _____________
--
-- This BFM can inject random handshake stall/jitter, for good verification coverage.
-- Modify the ``stall_config`` generic to get your desired behavior.
-- The random seed is provided by a VUnit mechanism
-- (see the "seed" portion of `this document <https://vunit.github.io/run/user_guide.html>`__).
-- Use the ``--seed`` command line argument if you need to set a static seed.
--
--
-- Unaligned packet length
-- _______________________
--
-- The byte length of the packets (as indicated by the length of the ``data_queue`` arrays)
-- does not need to be aligned with the ``data_width`` of the bus.
-- If unaligned, the last data beat will not have all byte lanes set to valid
-- ``data`` and ``strobe``.
--
--
-- User signalling
-- _______________
--
-- This BFM optionally supports sending auxiliary data on the ``user`` port also.
-- Enable by setting a non-zero ``user_width`` and a valid ``user_queue``.
-- User data is pushed as a :doc:`VUnit integer_array <vunit:data_types/integer_array>`
-- just as for the regular data.
-- The length of packets must be the same as what is pushed to the ``data_queue``.
--
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.run_types_pkg.all;

use work.util_pkg.all;
use work.axis_pkg.all;
use work.bfm_pkg.all;

entity bfm_axis_man is
  generic (
    -- Push data (integer_array_t with push_ref()) to this queue.
    -- The integer arrays will be deallocated after this BFM is done with them.
    -- Each entry to this array is one "byte" of data in a packet.
    G_DATA_QUEUE : queue_t;
    -- Push auxiliary user data (integer_array_t with push_ref()) to this queue.
    -- Must be the same length as data queue.
    -- The integer arrays will be deallocated after this BFM is done with them.
    G_USER_QUEUE : queue_t := null_queue;
    -- If true - Generate a continuous packet stream, where every beat has all
    -- tkeep bits asserted, expect for tlast, which will pack tkeep bits from
    -- low to high.
    -- If false - Generate random values for tkeep bits for each beat.
    G_PACKED_STREAM : boolean := true;
    -- If true - Occasionally generate a tlast beat where all tkeep bits are
    -- zero. While there aren't too many practical uses for this, it is still
    -- allowed by the axi stream standard, so it's good to be able to generate
    -- packets that do this for good test coverage.
    G_NULL_TLAST : boolean := false;
    -- Assign non-zero to randomly insert jitter/stalling in the data stream.
    G_STALL_CONFIG : stall_configuration_t := zero_stall_configuration;
    -- Suffix for error log messages. Can be used to differentiate between
    -- multiple instances.
    G_LOGGER_NAME_SUFFIX : string := ""
  );
  port (
    clk : in std_ulogic;
    --
    m_axis : view m_axis_v;
    --
    num_packets_sent : out natural := 0
  );
end entity;

architecture sim of bfm_axis_man is

  -- When 'valid' is zero, the associated output ports will be driven with this value.
  -- This is to avoid a DUT sampling the values in the wrong clock cycle.
  constant DRIVE_INVALID_VALUE : std_ulogic := 'X';

  constant BASE_ERROR_MESSAGE : string := "bfm_axis_man - " & 
    G_LOGGER_NAME_SUFFIX & ": ";

  -- ---------------------------------------------------------------------------
  -- Data width, keep width, user width, data byte width, and user byte width
  constant DW  : integer := m_axis.tdata'length;
  constant KW  : integer := m_axis.tkeep'length;
  constant UW  : integer := m_axis.tuser'length;
  constant DBW : integer := DW / KW;
  constant UBW : integer := UW / KW;

  signal int_axis_tdata : std_ulogic_vector(DW-1 downto 0) := 
    (others => DRIVE_INVALID_VALUE);
  signal int_axis_tkeep : std_ulogic_vector(KW-1 downto 0) := 
    (others => '0');
  signal int_axis_tlast : std_ulogic := DRIVE_INVALID_VALUE;
  signal int_axis_tuser : std_ulogic_vector(UW-1 downto 0) := 
        (others => DRIVE_INVALID_VALUE);
  signal data_is_valid : std_ulogic := '0';

begin

  assert DW mod KW = 0 report (
    BASE_ERROR_MESSAGE &
    "Data width must be an integer multiple of keep width."
  );

  assert UW mod KW = 0 report (
    BASE_ERROR_MESSAGE &
    "User width must be an integer multiple of keep width."
  );

  -- ---------------------------------------------------------------------------
  prc_tdata_main : process
    variable data_packet : integer_array_t := null_integer_array;
    variable user_packet : integer_array_t := null_integer_array;
    variable packet_length_bytes : positive := 1;
    variable user_packet_length_bytes : positive := 1;
    variable data_value : natural := 0;
    variable user_value : natural := 0;
    variable i : natural := 0;
    variable k : natural range 0 to KW - 1 := 0;
    variable is_last_byte : boolean := false;
    variable byte_is_valid : boolean;
    variable seed : string_seed_t;
    variable rnd : RandomPType;
    variable send_null_tlast : boolean := false;
  begin

    -- Use salt so that parallel instances of this entity get unique random
    -- sequences.
    get_seed(seed, salt=>bfm_axis_man'path_name);
    rnd.InitSeed(seed);

    loop

      while is_empty(G_DATA_QUEUE) loop
        wait until rising_edge(clk);
      end loop;

      i := 0;
      k := 0;
      data_packet := pop_ref(G_DATA_QUEUE);
      user_packet := pop_ref(G_USER_QUEUE);
      packet_length_bytes := length(data_packet);
      user_packet_length_bytes := length(user_packet);

      assert packet_length_bytes = user_packet_length_bytes 
        report BASE_ERROR_MESSAGE &
        "Length mismatch between data packet and user packet.";

      data_is_valid <= '1';

      while i < packet_length_bytes loop

        if G_PACKED_STREAM then
          byte_is_valid := true;
        else
          byte_is_valid := true when rnd.RandInt(0, 1) = 1 else false;
        end if;

        if byte_is_valid then
          int_axis_tkeep(k) <= '1';

          data_value := get(data_packet, i);
          int_axis_tdata((k + 1) * DBW - 1 downto k * DBW) <=
            std_ulogic_vector(to_unsigned(data_value, DBW));

          user_value := get(user_packet, i);
          int_axis_tuser((k + 1) * UBW - 1 downto k * UBW) <=
            std_ulogic_vector(to_unsigned(user_value, UBW));
        end if;

        is_last_byte := (i = (packet_length_bytes - 1)) and byte_is_valid;

        if (k = (KW - 1)) or is_last_byte then

          if G_NULL_TLAST and is_last_byte then
            send_null_tlast := true when rnd.RandInt(0, 1) = 1 else false;
          else 
            send_null_tlast := false; 
          end if;

          int_axis_tlast <= to_sl(is_last_byte and not send_null_tlast);

          wait until m_axis.tready and m_axis.tvalid and rising_edge(clk);

          -- Default for next beat. We will fill in the byte lanes that are used.
          int_axis_tkeep <= (others => '0');
          int_axis_tdata <= (others => DRIVE_INVALID_VALUE);
          int_axis_tuser <= (others => DRIVE_INVALID_VALUE);
        end if;

        k := (k + 1) mod KW;
        i := i + to_int(byte_is_valid);
      end loop;

      if send_null_tlast then
        int_axis_tlast <= '1';
        wait until m_axis.tready and m_axis.tvalid and rising_edge(clk);
      end if;

      -- Deallocate after we are done with the data.
      deallocate(data_packet);
      deallocate(user_packet);

      -- Default: Signal "not valid" to handshake BFM before next packet.
      -- If queue is not empty, it will instantly be raised again (no bubble cycle).
      data_is_valid <= '0';

      num_packets_sent <= num_packets_sent + 1;

    end loop;
  end process;


  -- ---------------------------------------------------------------------------
  u_bfm_handshake_man : entity work.bfm_handshake_man
  generic map(
    G_STALL_CONFIG => G_STALL_CONFIG
  )
  port map(
    clk => clk,
    --
    data_is_valid => data_is_valid,
    --
    ready => m_axis.tready,
    valid => m_axis.tvalid
  );

  -- ---------------------------------------------------------------------------
  prc_assign_tdata_invalid : process(all) begin
    if m_axis.tvalid then
      m_axis.tlast <= int_axis_tlast;
      m_axis.tdata <= int_axis_tdata;
      m_axis.tuser <= int_axis_tuser;
      m_axis.tkeep <= int_axis_tkeep;
    else
      m_axis.tlast <= DRIVE_INVALID_VALUE;
      m_axis.tdata <= (others => DRIVE_INVALID_VALUE);
      m_axis.tuser <= (others => DRIVE_INVALID_VALUE);
      m_axis.tkeep <= (others => DRIVE_INVALID_VALUE);
    end if;
  end process;

end architecture;
