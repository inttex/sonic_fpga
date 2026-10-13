-- =============================================================================
-- UARTReader.vhd  —  8N1 UART receiver
-- Sourced from nandland.com; adapted for DualBuffer (10.24 MHz clock).
--
-- Generic:
--   g_CLKS_PER_BIT = round(F_clk / F_baud) = round(10_240_000 / 115_200) = 89
--
-- Protocol: 1 start bit (low), 8 data bits LSB first, 1 stop bit (high).
-- o_RX_DV is high for exactly one clock cycle when a byte has been received.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTReader is
  generic (
    g_CLKS_PER_BIT : integer := 89   -- 10.24 MHz / 115200 baud ≈ 89
  );
  port (
    i_Clk       : in  std_logic;
    i_RX_Serial : in  std_logic;
    o_RX_DV     : out std_logic;                    -- data valid, 1-cycle pulse
    o_RX_Byte   : out std_logic_vector(7 downto 0)  -- received byte (LSB first)
  );
end UARTReader;

architecture rtl of UARTReader is

  type t_SM is (s_Idle, s_RX_Start_Bit, s_RX_Data_Bits, s_RX_Stop_Bit);
  signal r_SM       : t_SM := s_Idle;

  -- Double-register for metastability hardening
  signal r_RX_R     : std_logic := '1';
  signal r_RX       : std_logic := '1';

  signal r_ClkCnt   : integer range 0 to g_CLKS_PER_BIT-1 := 0;
  signal r_BitIdx   : integer range 0 to 7               := 0;
  signal r_RX_Byte  : std_logic_vector(7 downto 0)       := (others => '0');
  signal r_RX_DV    : std_logic := '0';

begin

  -- Two flip-flop synchroniser on the async RX input
  p_SYNC : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
      r_RX_R <= i_RX_Serial;
      r_RX   <= r_RX_R;
    end if;
  end process p_SYNC;

  p_FSM : process (i_Clk)
  begin
    if rising_edge(i_Clk) then
      r_RX_DV <= '0';           -- default: no data

      case r_SM is

        when s_Idle =>
          r_ClkCnt <= 0;
          r_BitIdx <= 0;
          if r_RX = '0' then   -- falling edge = start bit detected
            r_SM <= s_RX_Start_Bit;
          end if;

        -- Sample in the middle of the start bit to confirm it is still low
        when s_RX_Start_Bit =>
          if r_ClkCnt = (g_CLKS_PER_BIT - 1) / 2 then
            if r_RX = '0' then
              r_ClkCnt <= 0;
              r_SM     <= s_RX_Data_Bits;
            else
              r_SM <= s_Idle;  -- glitch, abort
            end if;
          else
            r_ClkCnt <= r_ClkCnt + 1;
          end if;

        -- Sample each data bit at bit-centre (every g_CLKS_PER_BIT clocks)
        when s_RX_Data_Bits =>
          if r_ClkCnt < g_CLKS_PER_BIT - 1 then
            r_ClkCnt <= r_ClkCnt + 1;
          else
            r_ClkCnt             <= 0;
            r_RX_Byte(r_BitIdx)  <= r_RX;
            if r_BitIdx < 7 then
              r_BitIdx <= r_BitIdx + 1;
            else
              r_BitIdx <= 0;
              r_SM     <= s_RX_Stop_Bit;
            end if;
          end if;

        -- Wait for stop bit (high) to complete, then signal data valid
        when s_RX_Stop_Bit =>
          if r_ClkCnt < g_CLKS_PER_BIT - 1 then
            r_ClkCnt <= r_ClkCnt + 1;
          else
            r_RX_DV  <= '1';
            r_ClkCnt <= 0;
            r_SM     <= s_Idle;
          end if;

        when others =>
          r_SM <= s_Idle;

      end case;
    end if;
  end process p_FSM;

  o_RX_DV   <= r_RX_DV;
  o_RX_Byte <= r_RX_Byte;

end rtl;
