-- =============================================================================
-- SpiAdc.vhd  —  MCP3208 SPI master (single-ended, channel 0)
--
-- Drives the MCP3208 12-bit SPI ADC and returns an 8-bit k value.
-- Only channel 0 is used (single-ended, START=1 SGL=1 D2=0 D1=0 D0=0).
--
-- SPI protocol (MCP3208 datasheet, mode 0,0):
--   CS goes low, then:
--   Host sends: 1 (start) | 1 (SGL) | 0 (D2) | 0 (D1) | 0 (D0) | 0 (MSBF)
--   Total 24 clock edges: 6 config bits + null bit + 12 result bits
--   Result is 12-bit unsigned, MSB first.
--   We shift out 24 SCK cycles total.
--   After the 6 config bits the MCP3208 sends a null bit then 12 data bits.
--   We capture bits 17 downto 6 (12 data bits, MSB first).
--
-- Timing:
--   SCK divider = C_SCK_DIV (default 10) → SCK = 10.24 MHz / 20 ≈ 512 kHz
--   (MCP3208 max SPI clock at 3.3 V = 2 MHz, we are well within spec)
--
-- Conversion rate:
--   One conversion = 24 SCK cycles + idle gap ≈ 24/512kHz ≈ 47 µs → ~21 kHz
--   k is updated every conversion; KSource samples on o_valid pulse.
--
-- Outputs:
--   o_k     — 8-bit k value (ADC bits [11:4], i.e. top 8 of 12)
--   o_valid — 1-cycle pulse when o_k is updated
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SpiAdc is
  generic (
    C_SCK_DIV : integer := 10   -- SCK half-period in system clocks (512 kHz SCK)
  );
  port (
    clk     : in  std_logic;
    -- SPI pins (to MCP3208)
    mcp_cs  : out std_logic := '1';
    mcp_sck : out std_logic := '0';
    mcp_miso: in  std_logic;
    -- Result
    o_k     : out std_logic_vector(7 downto 0);
    o_valid : out std_logic
  );
end SpiAdc;

architecture rtl of SpiAdc is

  -- Config word to send: START SGL D2 D1 D0 MSBF = 1 1 0 0 0 0
  constant C_CFG : std_logic_vector(5 downto 0) := "110000";

  -- Total SPI bits: 6 config + 1 null + 12 data + 5 padding = 24
  constant C_BITS : integer := 24;

  type t_SM is (s_Idle, s_CS_Low, s_Shift, s_CS_High);
  signal r_SM     : t_SM    := s_Idle;

  signal r_Div    : integer range 0 to C_SCK_DIV-1 := 0;
  signal r_BitCnt : integer range 0 to C_BITS-1    := 0;
  signal r_SCK    : std_logic := '0';
  signal r_CS     : std_logic := '1';

  -- Shift register: 24 bits, we shift in MISO from right
  signal r_ShiftReg : std_logic_vector(C_BITS-1 downto 0) := (others => '0');

  -- Transmit data: 6 config bits left-aligned in shift register
  signal r_TxReg    : std_logic_vector(C_BITS-1 downto 0) :=
      C_CFG & "000000000000000000";   -- 6 cfg + 18 don't-care

  signal r_Valid  : std_logic := '0';
  signal r_K      : std_logic_vector(7 downto 0) := (others => '0');

begin

  mcp_cs  <= r_CS;
  mcp_sck <= r_SCK;
  o_k     <= r_K;
  o_valid <= r_Valid;

  p_SPI : process (clk)
  begin
    if rising_edge(clk) then
      r_Valid <= '0';

      case r_SM is

        -- Wait a few cycles between conversions (~idle gap)
        when s_Idle =>
          r_SCK    <= '0';
          r_BitCnt <= 0;
          r_Div    <= 0;
          r_SM     <= s_CS_Low;

        -- Assert CS
        when s_CS_Low =>
          r_CS     <= '0';
          r_TxReg  <= C_CFG & "000000000000000000";
          r_ShiftReg <= (others => '0');
          r_SM     <= s_Shift;

        -- Clock 24 bits
        when s_Shift =>
          if r_Div < C_SCK_DIV - 1 then
            r_Div <= r_Div + 1;
          else
            r_Div <= 0;
            r_SCK <= not r_SCK;

            if r_SCK = '0' then
              -- Rising edge: shift in MISO
              r_ShiftReg <= r_ShiftReg(C_BITS-2 downto 0) & mcp_miso;
            else
              -- Falling edge: advance bit count
              if r_BitCnt < C_BITS - 1 then
                r_BitCnt <= r_BitCnt + 1;
                r_TxReg  <= r_TxReg(C_BITS-2 downto 0) & '0';
              else
                -- Done: deassert CS
                r_CS <= '1';
                r_SM <= s_CS_High;
              end if;
            end if;
          end if;

        -- CS high gap: publish result
        when s_CS_High =>
          -- MCP3208: null bit at position 11, data bits [10:0] at [11:1]
          -- In our 24-bit shift register the 12 data bits landed at [11:0]
          r_K     <= r_ShiftReg(11 downto 4);  -- top 8 of 12 bits
          r_Valid <= '1';
          r_SM    <= s_Idle;

      end case;
    end if;
  end process p_SPI;

end rtl;
