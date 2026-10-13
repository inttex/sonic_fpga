-- =============================================================================
-- KBlend.vhd  —  k-Blend interpolation engine
--
-- Sweeps all 256 emitters sequentially, computing effective phase and amplitude
-- for each from the pattern memory and the current k value.
--
-- Formulas (per emitter i, every sweep):
--   phase_eff[i] = phase_A[i] + (k × delta_phase[i]) >> 8 + cal_offset[i]
--   amp_eff[i]   = ( (256-k)×amp_A[i] + k×amp_B[i] ) >> 8
--
-- Both results wrap / are clamped naturally by their bit widths:
--   phase_eff : uint8, wraps mod 256 (= mod 360°) via truncation
--   amp_eff   : uint5 (0–16), effectively clamped by the 5-bit slice
--
-- Pipeline (2-stage):
--   Stage 1 — issue rd_addr = i to PatternMem (synchronous read, 1-cycle latency)
--   Stage 2 — PatternMem data for (i-1) is valid; compute and write to output regs
--
--   Full sweep: 256 + 1 = 257 cycles ≈ 25.1 µs → ~39.8 kHz update rate.
--   k changes at ≤1 kHz, so the output is always nearly current.
--
-- Output arrays (from DualBuffer_pkg):
--   o_phase_arr : phase_arr_t  — 6-bit per emitter: {OFF_flag, phase_step[4:0]}
--   o_amp_arr   : amp_arr_t    — 5-bit per emitter: 0=off, 1-16=on
--
-- The OFF flag in phase_arr is set when amp_eff=0, signalling PhaseLine to
-- hold its output silent.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.DualBuffer_pkg.all;

entity KBlend is
  port (
    clk         : in  std_logic;
    -- k register (from KSource mux): 0=Pattern A, 255≈Pattern B
    k           : in  std_logic_vector(7 downto 0);
    -- PatternMem read interface (1-cycle synchronous read)
    rd_addr     : out std_logic_vector(7 downto 0);
    rd_phase_a  : in  std_logic_vector(7 downto 0);
    rd_dp       : in  std_logic_vector(7 downto 0);  -- signed int8
    rd_amp_a    : in  std_logic_vector(4 downto 0);
    rd_amp_b    : in  std_logic_vector(4 downto 0);
    rd_cal      : in  std_logic_vector(7 downto 0);  -- signed int8
    -- Results: updated every ~25 µs sweep
    o_phase_arr : out phase_arr_t;
    o_amp_arr   : out amp_arr_t
  );
end KBlend;

architecture rtl of KBlend is

  signal r_SweepIdx  : unsigned(7 downto 0) := (others => '0');
  signal r_PrevIdx   : unsigned(7 downto 0) := (others => '0');

begin

  -- Stage 1: issue read address to PatternMem
  rd_addr <= std_logic_vector(r_SweepIdx);

  p_SWEEP : process (clk)
    -- Intermediate computation variables
    variable v_k        : unsigned(8 downto 0);   -- 9-bit: "0" & k
    variable v_k_inv    : unsigned(8 downto 0);   -- 256 - k
    variable v_dp       : signed(8 downto 0);     -- sign-extended delta_phase
    variable v_cal      : signed(8 downto 0);     -- sign-extended cal_offset
    variable v_prod_ph  : signed(17 downto 0);    -- k × dp (9×9=18-bit signed)
    variable v_corr     : signed(8 downto 0);     -- product >> 8 (signed)
    variable v_phase_s  : unsigned(8 downto 0);   -- 9-bit accumulator (wraps)
    variable v_amp_tmp  : unsigned(14 downto 0);  -- (256-k)*ampA + k*ampB
    variable v_amp5     : unsigned(4 downto 0);   -- 5-bit amplitude result
    variable v_phase6   : std_logic_vector(5 downto 0);
  begin
    if rising_edge(clk) then
      -- Advance sweep index (wraps 0→255→0 continuously)
      r_SweepIdx <= r_SweepIdx + 1;
      r_PrevIdx  <= r_SweepIdx;   -- lags by 1 cycle (= index whose data is now valid)

      -- -----------------------------------------------------------------------
      -- Stage 2: PatternMem data for r_PrevIdx is now on the rd_* ports.
      -- Compute phase_eff and amp_eff and write to output arrays.
      -- -----------------------------------------------------------------------

      -- Extend k to 9-bit unsigned (prevents signed overflow in multiply)
      v_k     := "0" & unsigned(k);
      v_k_inv := to_unsigned(256, 9) - v_k;  -- (256-k), range 1–256

      -- Sign-extend delta_phase and cal_offset to 9-bit signed
      v_dp  := signed(rd_dp(7) & rd_dp);
      v_cal := signed(rd_cal(7) & rd_cal);

      -- Phase correction: (k × dp) as 9×9 signed multiply → 18-bit
      -- Upper byte (bits 15:8) is the integer part of (k × dp) / 256
      v_prod_ph := signed("0" & v_k) * v_dp;
      v_corr    := v_prod_ph(15 downto 8) & '0';  -- sign-preserve, shift right 1 extra
      -- Simpler: take bits [15:8] directly as the correction
      v_corr    := v_prod_ph(15) & v_prod_ph(15 downto 8);  -- 9-bit sign-extended

      -- Accumulate: phase_eff = phase_A + corr + cal  (all in uint8 ring)
      v_phase_s := ("0" & unsigned(rd_phase_a))
                 + unsigned(resize(v_corr, 9))
                 + unsigned(resize(v_cal,  9));
      -- Take lower 8 bits (natural mod-256 wrap = mod-360° wrap)

      -- Amplitude interpolation (unsigned, no signed needed):
      -- amp_eff = ((256-k)*amp_A + k*amp_B) >> 8
      v_amp_tmp := (v_k_inv * ("0000" & unsigned(rd_amp_a)))
                 + (v_k     * ("0000" & unsigned(rd_amp_b)));
      -- bits[12:8] of the 15-bit product give the 5-bit result
      v_amp5 := v_amp_tmp(12 downto 8);

      -- Build 6-bit phase_arr entry: {OFF, phase_step[4:0]}
      --   OFF='1' when amp=0; phase_step = phase_eff[7:3] (top 5 bits)
      if v_amp5 = "00000" then
        v_phase6 := "100000";   -- OFF
      else
        v_phase6 := '0' & std_logic_vector(v_phase_s(7 downto 3));
      end if;

      -- Write results to output register arrays
      o_phase_arr(to_integer(r_PrevIdx)) <= v_phase6;
      o_amp_arr  (to_integer(r_PrevIdx)) <= std_logic_vector(v_amp5);

    end if;
  end process p_SWEEP;

end rtl;
