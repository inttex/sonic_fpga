-- =============================================================================
-- PhaseLine.vhd  —  Per-emitter phase comparator / pulse generator
--
-- Generates a 1-cycle pulse on the DATA bus whenever the global 5-bit phase
-- counter (counter[4:0]) equals this emitter's assigned phase step.
-- The pulse is held for 16 system clocks to guarantee it is captured by the
-- 74HC595 shift chain regardless of the Mux8 select position.
--
-- Port descriptions:
--   clk      — 10.24 MHz system clock
--   phase    — 6-bit phase assignment from KBlend:
--                bits[5]   = '1' → emitter OFF  (values 32–63)
--                bits[4:0] = phase step 0–31 when active
--   counter  — 5-bit global phase index (counter[7:3] from the 8-bit main counter)
--              cycles 0→31 at 40 kHz; this is the "which slot of the 40kHz wave"
--   pulse    — output: '1' for 16 clock cycles starting at counter == phase
--
-- Timing (10.24 MHz clock):
--   One 40 kHz period  = 256 clock cycles
--   One phase slot     = 256/32 = 8 clock cycles
--   Pulse width        = 16 clock cycles = 2 phase slots (ensures Mux8 captures it)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PhaseLine is
  port (
    clk     : in  std_logic;
    phase   : in  std_logic_vector(5 downto 0);  -- 6-bit: OFF flag + 5-bit step
    counter : in  std_logic_vector(4 downto 0);  -- 5-bit phase index (0–31)
    pulse   : out std_logic
  );
end PhaseLine;

architecture rtl of PhaseLine is

  -- Countdown timer: starts at 16 when phase matches, counts to 0
  -- pulse = '1' while counter > 0
  signal r_Count : integer range 0 to 16 := 0;

begin

  p_PHASE : process (clk)
  begin
    if rising_edge(clk) then

      -- Decrement countdown (always, takes effect below)
      if r_Count > 0 then
        r_Count <= r_Count - 1;
      end if;

      -- If phase is valid (bit5='0') and counter matches → start 16-cycle pulse
      -- This can re-trigger every 8 clocks (once per phase slot), holding the
      -- pulse high for two consecutive slot windows.
      if phase(5) = '0' then
        if unsigned(counter) = unsigned(phase(4 downto 0)) then
          r_Count <= 16;
        end if;
      end if;

    end if;
  end process p_PHASE;

  -- Output is '1' while countdown is running
  pulse <= '1' when r_Count > 0 else '0';

end rtl;
