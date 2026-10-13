-- =============================================================================
-- DualBuffer_pkg.vhd  —  Shared type definitions for the DualBuffer project
--
-- All other VHDL files that reference per-emitter arrays use the types
-- defined here.  Include this package before all other DualBuffer entities.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

package DualBuffer_pkg is

  -- -------------------------------------------------------------------------
  -- Number of emitters (must match the physical array and DATA bus width)
  -- 256 emitters, 32 DATA pins, 8 emitters per pin (time-multiplexed via Mux8)
  -- -------------------------------------------------------------------------
  constant C_NUM_EMITTERS : integer := 256;
  constant C_NUM_DATA_PINS : integer := 32;   -- C_NUM_EMITTERS / 8

  -- -------------------------------------------------------------------------
  -- Per-emitter phase register
  --   Bit 5 (MSB of 6-bit value) = '1'  → emitter OFF  (value 32..63)
  --   Bits 4:0                           → phase step 0..31
  -- The KBlend result phase_eff is uint8 (0–255 representing 0–360°).
  -- TopLevel maps it: phase_in = "0" & phase_eff(7 downto 3)  when amp>0
  --                   phase_in = "100000"                       when amp=0 (off)
  -- -------------------------------------------------------------------------
  type phase_arr_t is array(0 to C_NUM_EMITTERS-1) of std_logic_vector(5 downto 0);

  -- -------------------------------------------------------------------------
  -- Per-emitter amplitude register (uint5, 0–16)
  --   0  = emitter disabled (phase_in set to OFF)
  --   1-16 = on (amplitude control reserved for future PWM duty-cycle use)
  -- -------------------------------------------------------------------------
  type amp_arr_t is array(0 to C_NUM_EMITTERS-1) of std_logic_vector(4 downto 0);

  -- -------------------------------------------------------------------------
  -- Per-emitter pulse bus (one std_logic per emitter, from PhaseLine outputs)
  -- -------------------------------------------------------------------------
  type pulse_arr_t is array(0 to C_NUM_EMITTERS-1) of std_logic;

end package DualBuffer_pkg;
