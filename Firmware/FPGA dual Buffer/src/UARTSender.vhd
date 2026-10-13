-- =============================================================================
-- UARTSender.vhd  —  8N1 UART transmitter
-- Used by CommandDecoder to send ACK (0x06) / NACK (0x15) responses.
--
-- Generic:
--   g_CLKS_PER_BIT = round(F_clk / F_baud) = round(10_240_000 / 115_200) = 89
--
-- Usage:
--   Assert send='1' for one clock with data_in set.
--   Wait until ready='1' before sending the next byte.
--   tx idles high (mark state = '1').
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity UARTSender is
  generic (
    g_CLKS_PER_BIT : integer := 89   -- 10.24 MHz / 115200 baud ≈ 89
  );
  port (
    clk     : in  std_logic;
    send    : in  std_logic;                      -- pulse '1' for 1 cycle to begin send
    data_in : in  std_logic_vector(7 downto 0);   -- byte to transmit (LSB first)
    tx      : out std_logic := '1';               -- serial output, idles high
    ready   : out std_logic                       -- '1' when idle and ready for next byte
  );
end UARTSender;

architecture rtl of UARTSender is

  type t_SM is (s_Idle, s_Start, s_Data, s_Stop);
  signal r_SM     : t_SM := s_Idle;

  signal r_ClkCnt : integer range 0 to g_CLKS_PER_BIT - 1 := 0;
  signal r_BitIdx : integer range 0 to 7 := 0;
  signal r_Data   : std_logic_vector(7 downto 0) := (others => '0');
  signal r_TX     : std_logic := '1';
  signal r_Ready  : std_logic := '1';

begin

  p_TX : process (clk)
  begin
    if rising_edge(clk) then
      case r_SM is

        when s_Idle =>
          r_TX     <= '1';
          r_Ready  <= '1';
          r_ClkCnt <= 0;
          r_BitIdx <= 0;
          if send = '1' then
            r_Data  <= data_in;
            r_Ready <= '0';
            r_SM    <= s_Start;
          end if;

        -- Drive start bit (low) for g_CLKS_PER_BIT cycles
        when s_Start =>
          r_TX <= '0';
          if r_ClkCnt < g_CLKS_PER_BIT - 1 then
            r_ClkCnt <= r_ClkCnt + 1;
          else
            r_ClkCnt <= 0;
            r_SM     <= s_Data;
          end if;

        -- Transmit 8 data bits, LSB first
        when s_Data =>
          r_TX <= r_Data(r_BitIdx);
          if r_ClkCnt < g_CLKS_PER_BIT - 1 then
            r_ClkCnt <= r_ClkCnt + 1;
          else
            r_ClkCnt <= 0;
            if r_BitIdx < 7 then
              r_BitIdx <= r_BitIdx + 1;
            else
              r_BitIdx <= 0;
              r_SM     <= s_Stop;
            end if;
          end if;

        -- Drive stop bit (high) for g_CLKS_PER_BIT cycles, then return to idle
        when s_Stop =>
          r_TX <= '1';
          if r_ClkCnt < g_CLKS_PER_BIT - 1 then
            r_ClkCnt <= r_ClkCnt + 1;
          else
            r_ClkCnt <= 0;
            r_SM     <= s_Idle;
          end if;

        when others =>
          r_SM <= s_Idle;

      end case;
    end if;
  end process p_TX;

  tx    <= r_TX;
  ready <= r_Ready;

end rtl;
