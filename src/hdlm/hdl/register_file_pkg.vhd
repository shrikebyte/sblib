-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with constants/types/functions for generic register file ecosystem.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package register_file_pkg is

  constant REGISTER_WIDTH : positive   := 32;
  subtype  register_t is std_ulogic_vector(register_width - 1 downto 0);
  constant REGISTER_INIT  : register_t := (others => '0');
  type     register_vec_t is array (integer range <>) of register_t;

  type register_mode_t is (
    -- Software can read a value that hardware provides.
    R,
    -- Software can write a value that is available for usage in hardware.
    W,
    -- Software can write a value and read it back. The written value is available for usage
    -- in hardware.
    R_W,
    -- Software can write a value that is asserted for one cycle in hardware.
    WPULSE,
    -- Software can read a value that hardware provides.
    -- Software can write a value that is asserted for one cycle in hardware.
    R_WPULSE
  );

  -- If it is a mode where software can read the register.
  function is_read_mode (
    mode : register_mode_t
  ) return boolean;

  -- If it is a mode where software can write the register.
  function is_write_mode (
    mode : register_mode_t
  ) return boolean;

  -- If it is a mode where software can write the register and the value shall be asserted for
  -- one clock cycle in hardware.
  function is_write_pulse_mode (
    mode : register_mode_t
  ) return boolean;

  -- If it is a mode where the value that software can read is provided by the 'regs_up' port
  -- from the users' application.
  -- As opposed to for example Read-Write, where the read value is a loopback of the written value.
  function is_application_gives_value_mode (
    mode : register_mode_t
  ) return boolean;

  type register_definition_t is record
    -- The index of this register, within the list of registers.
    index : natural;
    -- The mode of this register.
    mode : register_mode_t;
    -- The number of data bits that are utilized in this register.
    -- Implementations can ignore other bits.
    utilized_width : natural range 0 to register_width;
  end record;
  type register_definition_vec_t is array (natural range <>) of register_definition_t;

  -- Get the highest register index that is used in the list of registers.
  function get_highest_index (
    registers : register_definition_vec_t
  ) return natural;

  -- Get the number of bits needed to represent the register indices.
  -- Note that this does not include the lowest two aligned bits.
  function num_address_bits_needed (
    registers : register_definition_vec_t
  ) return positive;

end package;

package body register_file_pkg is

  function is_read_mode (
    mode : register_mode_t
  ) return boolean is
  begin
    return mode = r or mode = r_w or mode = r_wpulse;
  end function;

  function is_write_mode (
    mode : register_mode_t
  ) return boolean is
  begin
    return mode = w or mode = r_w or mode = wpulse or mode = r_wpulse;
  end function;

  function is_write_pulse_mode (
    mode : register_mode_t
  ) return boolean is
  begin
    return mode = wpulse or mode = r_wpulse;
  end function;

  function is_application_gives_value_mode (
    mode : register_mode_t
  ) return boolean is
  begin
    return mode = r or mode = r_wpulse;
  end function;

  function get_highest_index (
    registers : register_definition_vec_t
  ) return natural is
  begin
    assert registers(0).index = 0
      severity failure;
    assert registers(registers'high).index = registers'length - 1
      severity failure;
    return registers(registers'high).index;
  end function;

  function num_address_bits_needed (
    registers : register_definition_vec_t
  ) return positive is
    constant MAX_INDEX : natural := get_highest_index(registers);
  begin
    if MAX_INDEX = 0 then
      return 1;
    end if;

    return integer(ceil(log2(real(MAX_INDEX + 1))));
  end function;

end package body;
