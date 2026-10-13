-- =============================================================================
-- KSource.vhd  —  k-value source multiplexer
--
-- Selects the 8-bit k register value from one of three sources:
--
--   MODE 0 (MANUAL)   — k is set directly by the host via SET_K command
--   MODE 1 (ADC)      — k tracks the MCP3208 ADC output (analog waveform)
--   MODE 2 (INTERNAL) — k is generated internally by a simple counter that
--                        ramps up at a configurable rate (sawtooth LFO)
--
-- The active mode and manual k are set by CommandDecoder.
--
-- Internal sawtooth generator:
--   Increments k by 1 every C_RAMP_PERIOD system clocks.
--   Default: 10_240_000 / 256 / 10 ≈ 4000 Hz ramp → ~15 Hz full sweep
--   (C_RAMP_PERIOD can be changed via the SET_RATE command in CommandDecoder)
--
-- Ports:
--   i_mode     — 2-bit source select: 00=MANUAL, 01=ADC, 10=INTERNAL
--   i_manual_k — 8-bit k from SET_K command
--   i_adc_k    — 8-bit k from SpiAdc
--   i_adc_valid— 1-cycle pulse from SpiAdc (new ADC sample ready)
--   i_rate     — 16-bit period for internal ramp (clocks per k increment)
--   o_k        — 8-bit k output (to KBlend)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity KSource is
  port (
    clk        : in  std_logic;
    -- Source selection (from CommandDecoder)
    i_mode     : in  std_logic_vector(1 downto 0);
    i_manual_k : in  std_logic_vector(7 downto 0);
    -- ADC input (from SpiAdc)
    i_adc_k    : in  std_logic_vector(7 downto 0);
    i_adc_valid: in  std_logic;
    -- Internal ramp rate (clocks per increment step)
    i_rate     : in  std_logic_vector(15 downto 0);
    -- Output
    o_k        : out std_logic_vector(7 downto 0)
  );
end KSource;

architecture rtl of KSource is

  -- Internal sawtooth generator
  signal r_RampCnt : unsigned(15 downto 0) := (others => '0');
  signal r_IntK    : unsigned(7 downto 0)  := (others => '0');

  -- Registered ADC k (captured on valid pulse)
  signal r_AdcK    : std_logic_vector(7 downto 0) := (others => '0');

begin

  -- ADC sample register: captures i_adc_k on each valid pulse
  p_ADC : process (clk)
  begin
    if rising_edge(clk) then
      if i_adc_valid = '1' then
        r_AdcK <= i_adc_k;
      end if;
    end if;
  end process p_ADC;

  -- Internal sawtooth: increments r_IntK every i_rate clock cycles
  p_RAMP : process (clk)
  begin
    if rising_edge(clk) then
      if r_RampCnt >= unsigned(i_rate) - 1 then
        r_RampCnt <= (others => '0');
        r_IntK    <= r_IntK + 1;   -- wraps 255 → 0 naturally
      else
        r_RampCnt <= r_RampCnt + 1;
      end if;
    end if;
  end process p_RAMP;

  -- Output mux
  p_MUX : process (clk)
  begin
    if rising_edge(clk) then
      case i_mode is
        when "00"   => o_k <= i_manual_k;
        when "01"   => o_k <= r_AdcK;
        when "10"   => o_k <= std_logic_vector(r_IntK);
        when others => o_k <= i_manual_k;
      end case;
    end if;
  end process p_MUX;

end rtl;
