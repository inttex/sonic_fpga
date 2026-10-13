-- =============================================================================
-- PatternMem.vhd  —  Pattern storage for k-blend dual-buffer system
--
-- Stores 5 tables of 256 × 8-bit data, one entry per emitter:
--
--   Table 0: phase_A      uint8  (0–255 = 0–360°)   pattern-A phase
--   Table 1: delta_phase  int8   (−128..+127, two's complement)
--              = shortest arc from phase_A to phase_B, pre-computed in Python
--   Table 2: amp_A        uint8  (0–16)  pattern-A amplitude
--   Table 3: amp_B        uint8  (0–16)  pattern-B amplitude
--   Table 4: cal_offset   int8   (−128..+127, two's complement)
--              per-emitter phase calibration, loaded via SET_CAL command
--
-- Write port (from CommandDecoder, slow UART-rate):
--   wr_en   — write enable, '1' for one clock cycle
--   wr_tbl  — table select 0–4
--   wr_addr — emitter index 0–255
--   wr_data — 8-bit value
--
-- Read port (from KBlend, sweeps sequentially at ~40 kHz):
--   rd_addr — emitter index 0–255
--   All five table outputs are registered (1-cycle read latency).
--
-- Simultaneous read and write to the same address is benign: KBlend will
-- read either the old or the new value.  Since k changes at ≤1 kHz and the
-- sweep runs at ~40 kHz, stale reads affect at most one emitter for one
-- 25 µs sweep window — inaudible and physically imperceptible.
--
-- Memory inference: Quartus infers M9K block RAM for each table array.
-- Total: 5 × 256 × 8 = 10 240 bits → fits in 2 × M9K (9 216 bits each with
-- extra parity bits).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PatternMem is
  port (
    clk     : in  std_logic;
    -- ---- Write port (CommandDecoder) ----------------------------------------
    wr_en   : in  std_logic;
    wr_tbl  : in  std_logic_vector(2 downto 0);  -- 000..100
    wr_addr : in  std_logic_vector(7 downto 0);
    wr_data : in  std_logic_vector(7 downto 0);
    -- ---- Read port (KBlend, 1-cycle latency) --------------------------------
    rd_addr     : in  std_logic_vector(7 downto 0);
    rd_phase_a  : out std_logic_vector(7 downto 0);  -- table 0
    rd_dp       : out std_logic_vector(7 downto 0);  -- table 1 (signed)
    rd_amp_a    : out std_logic_vector(4 downto 0);  -- table 2 [4:0]
    rd_amp_b    : out std_logic_vector(4 downto 0);  -- table 3 [4:0]
    rd_cal      : out std_logic_vector(7 downto 0)   -- table 4 (signed)
  );
end PatternMem;

architecture rtl of PatternMem is

  type mem256x8_t is array(0 to 255) of std_logic_vector(7 downto 0);

  signal mem_phase_a : mem256x8_t := (others => (others => '0'));
  signal mem_dp      : mem256x8_t := (others => (others => '0'));
  signal mem_amp_a   : mem256x8_t := (others => (others => '0'));
  signal mem_amp_b   : mem256x8_t := (others => (others => '0'));
  signal mem_cal     : mem256x8_t := (others => (others => '0'));

begin

  -- Write process: single port write, table selected by wr_tbl
  p_WRITE : process (clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        case wr_tbl is
          when "000"  => mem_phase_a(to_integer(unsigned(wr_addr))) <= wr_data;
          when "001"  => mem_dp     (to_integer(unsigned(wr_addr))) <= wr_data;
          when "010"  => mem_amp_a  (to_integer(unsigned(wr_addr))) <= wr_data;
          when "011"  => mem_amp_b  (to_integer(unsigned(wr_addr))) <= wr_data;
          when "100"  => mem_cal    (to_integer(unsigned(wr_addr))) <= wr_data;
          when others => null;
        end case;
      end if;
    end if;
  end process p_WRITE;

  -- Read process: synchronous (registered), 1-cycle latency — Quartus infers M9K
  p_READ : process (clk)
  begin
    if rising_edge(clk) then
      rd_phase_a <= mem_phase_a(to_integer(unsigned(rd_addr)));
      rd_dp      <= mem_dp     (to_integer(unsigned(rd_addr)));
      rd_amp_a   <= mem_amp_a  (to_integer(unsigned(rd_addr)))(4 downto 0);
      rd_amp_b   <= mem_amp_b  (to_integer(unsigned(rd_addr)))(4 downto 0);
      rd_cal     <= mem_cal    (to_integer(unsigned(rd_addr)));
    end if;
  end process p_READ;

end rtl;
