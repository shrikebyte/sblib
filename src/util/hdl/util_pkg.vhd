--##############################################################################
--# File : util_pkg.vhd
--# Auth : David Gussler
--# ============================================================================
--# Shrikebyte VHDL Library - https://github.com/shrikebyte/sblib
--# Copyright (C) Shrikebyte, LLC
--# Licensed under the Apache 2.0 license, see LICENSE for details.
--# ============================================================================
--# General utilities package
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package util_pkg is

  -- ---------------------------------------------------------------------------
  -- Array types
  type slv_arr_t is array(natural range <>) of std_ulogic_vector;
  type unsigned_arr_t is array(natural range <>) of u_unsigned;
  type signed_arr_t is array(natural range <>) of u_signed;
  type int_arr_t is array(natural range <>) of integer;
  type pos_arr_t is array(natural range <>) of positive;
  type nat_arr_t is array(natural range <>) of natural;
  type bool_arr_t is array(natural range <>) of boolean;
  type string_arr_t is array(natural range <>) of string;

  -- ---------------------------------------------------------------------------
  -- Functions
  function cnt_ones (
    vec : std_ulogic_vector
  ) return natural;

  function cnt_ones (
    vec : u_unsigned
  ) return natural;

  function cnt_ones_contig (
    vec : std_ulogic_vector
  ) return natural;

  function is_contig (
    vec : std_ulogic_vector
  ) return boolean;

  function is_onehot (
    vec : std_ulogic_vector
  ) return boolean;

  function is_onehot (
    vec : std_ulogic_vector
  ) return std_ulogic;

  function bin_to_gray (
    bin : u_unsigned
  ) return std_ulogic_vector;

  function gray_to_bin (
    gray : std_ulogic_vector
  ) return u_unsigned;

  function clog2 (
    value : positive
  ) return natural;

  function is_pwr2 (
    value : positive
  ) return boolean;

  function round_up_pwr2 (
    value : positive
  ) return natural;

  function find_hi_idx (
    vec : std_ulogic_vector
  ) return natural;

  function find_lo_idx (
    vec : std_ulogic_vector
  ) return natural;

  function to_sl (
    val : boolean
  ) return std_ulogic;

  function to_sl (
    val : natural range 0 to 1
  ) return std_ulogic;

  function to_int (
    val : std_ulogic
  ) return integer;

  function to_int (
    val : boolean
  ) return integer;

  function to_bool (
    val : std_ulogic
  ) return boolean;

  function to_bool (
    val : natural range 0 to 1
  ) return boolean;

  function find_max (
    arr : int_arr_t
  ) return integer;

  function find_min (
    arr : int_arr_t
  ) return integer;

  function find_max (
    arr : nat_arr_t
  ) return integer;

  function find_min (
    arr : nat_arr_t
  ) return integer;

  function find_max (
    arr : pos_arr_t
  ) return integer;

  function find_min (
    arr : pos_arr_t
  ) return integer;

  function expand_bits (
    vec : std_ulogic_vector;
    n : positive
  ) return std_ulogic_vector;

  function contract_bits (
    vec : std_ulogic_vector;
    n : positive
  ) return std_ulogic_vector;

  function if_then_else (
    cond : boolean;
    if_true : integer;
    if_false : integer
  ) return integer;

  function to_ascii (
    c : character
  ) return unsigned;

  function to_ascii (
    c : character
  ) return std_logic_vector;

end package;

package body util_pkg is

  -- ---------------------------------------------------------------------------
  -- Count the number of ones in a vector.
  function cnt_ones (
    vec : std_ulogic_vector
  ) return natural is
    variable tmp : natural := 0;
  begin
    for i in vec'range loop
      if vec(i) = '1' then
        tmp := tmp + 1;
      end if;
    end loop;
    return tmp;
  end function;

  function cnt_ones (
    vec : u_unsigned
  ) return natural is
    variable tmp : natural := 0;
  begin
    for i in vec'range loop
      if vec(i) = '1' then
        tmp := tmp + 1;
      end if;
    end loop;
    return tmp;
  end function;

  -- ---------------------------------------------------------------------------
  -- Optimized version of cnt_ones that assumes input bits are
  -- contiguous from low to high.
  function cnt_ones_contig (
    vec : std_ulogic_vector
  ) return natural is
    constant VEC_LEN  : natural := vec'length;
    variable vec_norm : std_ulogic_vector(VEC_LEN - 1 downto 0);
    variable result   : natural := 0;
  begin
    vec_norm := vec;
    for i in 0 to VEC_LEN - 1 loop
      if vec_norm(i) then
        result := i + 1;
      end if;
    end loop;
    return result;
  end function;

  -- Return true if a vector has contiguous ones from low to high.
  function is_contig (
    vec : std_ulogic_vector
  ) return boolean is
    variable saw_zero : boolean := false;
  begin
    for i in vec'low to vec'high loop
      if vec(i) = '0' then
        saw_zero := true;
      elsif saw_zero then
        return false;
      end if;
    end loop;
    return true;
  end function;

  -- ---------------------------------------------------------------------------
  -- Return true if the vector has only one bit set to 1, otherwise false
  function is_onehot (
    vec : std_ulogic_vector
  ) return boolean is
    variable tmp : boolean := false;
  begin
    for i in vec'range loop
      if vec(i) = '1' and tmp = false then
        tmp := true;
      elsif vec(i) = '1' and tmp = true then
        return false;
      end if;
    end loop;
    return tmp;
  end function;

  -- ---------------------------------------------------------------------------
  -- Return 1 if the vector has only one bit set to 1, otherwise 0
  function is_onehot (
    vec : std_ulogic_vector
  ) return std_ulogic is
    variable tmp : std_ulogic := '0';
  begin
    for i in vec'range loop
      if vec(i) = '1' and tmp = '0' then
        tmp := '1';
      elsif vec(i) = '1' and tmp = '1' then
        return '0';
      end if;
    end loop;
    return tmp;
  end function;

  -- ---------------------------------------------------------------------------
  -- Convert a binary coded number to a gray coded number
  function bin_to_gray (
    bin : u_unsigned
  ) return std_ulogic_vector is
    variable gray : std_ulogic_vector(bin'length - 1 downto 0);
  begin
    gray(gray'high) := bin(gray'high);
    for i in gray'high - 1 downto 0 loop
      gray(i) := bin(i + 1) xor bin(i);
    end loop;
    return gray;
  end function;

  -- ---------------------------------------------------------------------------
  -- Convert a gray coded number to a binary coded number
  function gray_to_bin (
    gray : std_ulogic_vector
  ) return u_unsigned is
    variable bin : u_unsigned(gray'length - 1 downto 0);
  begin
    bin(gray'high) := gray(gray'high);
    for i in gray'high - 1 downto 0 loop
      bin(i) := bin(i + 1) xor gray(i);
    end loop;
    return bin;
  end function;

  -- ---------------------------------------------------------------------------
  -- 2-base logarithm rounded up. This should only be used in testbenches or to
  -- calculate compile-time values.
  function clog2 (
    value : positive
  ) return natural is
  begin
    return natural(ceil(log2(real(value))));
  end function;

  -- ---------------------------------------------------------------------------
  -- Return true if input is a power of two. Otherwise false.
  function is_pwr2 (
    value : positive
  ) return boolean is
  begin
    return is_onehot(std_ulogic_vector(to_unsigned(value, 32)));
  end function;

  -- ---------------------------------------------------------------------------
  -- Round up to the next highest power of two value. For example:
  --   4 -> 4
  --   5 -> 8
  --   6 -> 8
  --   7 -> 8
  --   8 -> 8
  --   9 -> 16
  function round_up_pwr2 (
    value : positive
  ) return natural is
  begin
    return 2 ** clog2(value);
  end function;

  -- ---------------------------------------------------------------------------
  -- Find the left-most index of an slv that is '1'. If no match, return
  -- left-most idx.
  function find_hi_idx (
    vec : std_ulogic_vector
  ) return natural is
  begin
    for i in vec'high downto vec'low loop
      if vec(i) then
        return i;
      end if;
    end loop;
    return vec'high;
  end function;

  -- ---------------------------------------------------------------------------
  -- Find the right-most index of an slv that is '1'. If no match, return
  -- left-most idx.
  function find_lo_idx (
    vec : std_ulogic_vector
  ) return natural is
  begin
    for i in vec'low to vec'high loop
      if vec(i) then
        return i;
      end if;
    end loop;
    return vec'high;
  end function;

  -- ---------------------------------------------------------------------------
  -- Convert a boolean to standard logic
  function to_sl (
    val : boolean
  ) return std_ulogic is
  begin
    if val then
      return '1';
    end if;
    return '0';
  end function;

  function to_sl (
    val : natural range 0 to 1
  ) return std_ulogic is
  begin
    if val = 1 then
      return '1';
    end if;
    return '0';
  end function;

  function to_int (
    val : std_ulogic
  ) return integer is
  begin
    if val = '1' then
      return 1;
    else
      return 0;
    end if;
  end function;

  function to_int (
    val : boolean
  ) return integer is
  begin
    if val = true then
      return 1;
    else
      return 0;
    end if;
  end function;

  function to_bool (
    val : std_ulogic
  ) return boolean is
  begin
    if val = '1' then
      return true;
    end if;
    return false;
  end function;

  function to_bool (
    val : natural range 0 to 1
  ) return boolean is
  begin
    return val = 1;
  end function;

  -- ---------------------------------------------------------------------------
  -- Find the max value of an integer array
  function find_max (
    arr : int_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) > rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  -- ---------------------------------------------------------------------------
  -- Find the min value of an integer array
  function find_min (
    arr : int_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) < rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  function find_max (
    arr : nat_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) > rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  function find_min (
    arr : nat_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) < rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  function find_max (
    arr : pos_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) > rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  function find_min (
    arr : pos_arr_t
  ) return integer is
    variable rtn : integer := arr(arr'low);
  begin
    for i in arr'range loop
      if arr(i) < rtn then
        rtn := arr(i);
      end if;
    end loop;
    return rtn;
  end function;

  function expand_bits (
    vec : std_ulogic_vector;
    n : positive
  ) return std_ulogic_vector is
    constant VEC_LEN  : natural := vec'length;
    constant OUT_LEN  : natural := VEC_LEN * n;
    variable result   : std_ulogic_vector(OUT_LEN - 1 downto 0);
    variable vec_norm : std_ulogic_vector(VEC_LEN - 1 downto 0);
  begin
    vec_norm := vec;

    for i in 0 to VEC_LEN - 1 loop
      for j in 0 to n - 1 loop
        result((i * N) + j) := vec_norm(i);
      end loop;
    end loop;

    return result;
  end function;

  function contract_bits (
    vec : std_ulogic_vector;
    n : positive
  ) return std_ulogic_vector is
    constant VEC_LEN  : natural := vec'length;
    constant OUT_LEN  : natural := VEC_LEN / n;
    variable result   : std_ulogic_vector(OUT_LEN - 1 downto 0);
    variable vec_norm : std_ulogic_vector(VEC_LEN - 1 downto 0);
  begin
    assert (VEC_LEN mod n) = 0
      report "contract_bits: Vector length must be divisible by N."
      severity failure;

    vec_norm := vec;

    for i in 0 to OUT_LEN - 1 loop
      result(i) := vec_norm(i * n);
    end loop;

    return result;
  end function;

  function if_then_else (
    cond : boolean;
    if_true : integer;
    if_false : integer
  ) return integer is
  begin
    if cond then
      return if_true;
    else
      return if_false;
    end if;
  end function;

  function to_ascii (
    c : character
  ) return unsigned is
  begin
    return to_unsigned(character'pos(c), 8);
  end function;

  function to_ascii (
    c : character
  ) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(character'pos(c), 8));
  end function;

end package body;
