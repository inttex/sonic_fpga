-- =============================================================================
-- CommandDecoder.vhd  —  UART command protocol FSM
--
-- Receives bytes from UARTReader and drives PatternMem, KSource, and status
-- LEDs according to the SonicSurface dual-buffer command protocol.
--
-- Command format (all multi-byte commands are sent LSB/low-index first):
--
--   0x10  SET_PHASE_A   [addr:1B] [data:1B]  — write phase_A[addr]
--   0x11  SET_DP        [addr:1B] [data:1B]  — write delta_phase[addr] (signed)
--   0x12  SET_AMP_A     [addr:1B] [data:1B]  — write amp_A[addr]
--   0x13  SET_AMP_B     [addr:1B] [data:1B]  — write amp_B[addr]
--   0x20  SET_CAL       [addr:1B] [data:1B]  — write cal_offset[addr] (signed)
--   0x30  SET_K         [data:1B]            — manual k value
--   0x31  SET_KMODE     [mode:1B]            — 0=manual 1=ADC 2=internal
--   0x32  SET_RATE      [lo:1B] [hi:1B]      — internal ramp period (16-bit)
--   0x40  RESET_K                            — set k=0, mode=manual
--   0xF0  NOP / PING                         — responds ACK only
--
-- After each complete command the FPGA sends:
--   ACK  (0x06) on success
--   NACK (0x15) on unknown command byte
--
-- State machine:
--   s_CMD   — waiting for command byte
--   s_B1..s_B3 — waiting for payload bytes (depending on command)
--   s_ACK   — one-cycle strobe to UARTSender
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CommandDecoder is
  port (
    clk        : in  std_logic;
    -- UART RX interface (from UARTReader)
    rx_dv      : in  std_logic;
    rx_byte    : in  std_logic_vector(7 downto 0);
    -- UART TX interface (to UARTSender)
    tx_send    : out std_logic;
    tx_data    : out std_logic_vector(7 downto 0);
    tx_ready   : in  std_logic;
    -- PatternMem write port
    mem_wr_en  : out std_logic;
    mem_wr_tbl : out std_logic_vector(2 downto 0);
    mem_wr_addr: out std_logic_vector(7 downto 0);
    mem_wr_data: out std_logic_vector(7 downto 0);
    -- KSource control
    k_manual   : out std_logic_vector(7 downto 0);
    k_mode     : out std_logic_vector(1 downto 0);
    k_rate     : out std_logic_vector(15 downto 0);
    -- Status LEDs (active high)
    led        : out std_logic_vector(3 downto 0)
  );
end CommandDecoder;

architecture rtl of CommandDecoder is

  type t_SM is (s_CMD, s_B1, s_B2, s_B3, s_ACK, s_NACK);
  signal r_SM      : t_SM := s_CMD;

  signal r_Cmd     : std_logic_vector(7 downto 0) := (others => '0');
  signal r_Addr    : std_logic_vector(7 downto 0) := (others => '0');
  signal r_Data    : std_logic_vector(7 downto 0) := (others => '0');

  -- KSource registers
  signal r_ManualK : std_logic_vector(7 downto 0) := (others => '0');
  signal r_KMode   : std_logic_vector(1 downto 0) := "00";
  signal r_KRate   : std_logic_vector(15 downto 0) := x"0028";  -- 40 clocks default

  -- Memory write strobe
  signal r_MemWrEn : std_logic := '0';
  signal r_MemTbl  : std_logic_vector(2 downto 0) := (others => '0');

  -- LED: bit0=RX activity, bit1=pattern update, bit2=k mode, bit3=error
  signal r_LED     : std_logic_vector(3 downto 0) := "0001";  -- bit0 on at start

  -- ACK / NACK constants
  constant ACK  : std_logic_vector(7 downto 0) := x"06";
  constant NACK : std_logic_vector(7 downto 0) := x"15";

begin

  k_manual   <= r_ManualK;
  k_mode     <= r_KMode;
  k_rate     <= r_KRate;
  mem_wr_en  <= r_MemWrEn;
  mem_wr_tbl <= r_MemTbl;
  mem_wr_addr<= r_Addr;
  mem_wr_data<= r_Data;
  led        <= r_LED;

  p_FSM : process (clk)
  begin
    if rising_edge(clk) then
      r_MemWrEn <= '0';    -- default: no write
      tx_send   <= '0';    -- default: no TX

      case r_SM is

        -- ---------------------------------------------------------------
        -- Wait for command byte
        -- ---------------------------------------------------------------
        when s_CMD =>
          r_LED(0) <= '0';
          if rx_dv = '1' then
            r_LED(0) <= '1';
            r_Cmd    <= rx_byte;
            case rx_byte is
              -- 2-byte payload commands: [addr] [data]
              when x"10" | x"11" | x"12" | x"13" | x"20" => r_SM <= s_B1;
              -- 1-byte payload commands: [data]
              when x"30" | x"31" => r_SM <= s_B1;
              -- 2-byte payload (lo/hi): SET_RATE
              when x"32"         => r_SM <= s_B1;
              -- Zero-payload commands
              when x"40"         =>           -- RESET_K
                r_ManualK <= (others => '0');
                r_KMode   <= "00";
                r_SM      <= s_ACK;
              when x"F0"         => r_SM <= s_ACK;  -- NOP/PING
              when others        => r_SM <= s_NACK;
            end case;
          end if;

        -- ---------------------------------------------------------------
        -- First payload byte
        -- ---------------------------------------------------------------
        when s_B1 =>
          if rx_dv = '1' then
            case r_Cmd is
              when x"10"|x"11"|x"12"|x"13"|x"20" =>
                r_Addr <= rx_byte;    -- address byte
                r_SM   <= s_B2;
              when x"30" =>            -- SET_K
                r_ManualK <= rx_byte;
                r_KMode   <= "00";
                r_SM      <= s_ACK;
              when x"31" =>            -- SET_KMODE
                r_KMode <= rx_byte(1 downto 0);
                r_SM    <= s_ACK;
              when x"32" =>            -- SET_RATE lo byte
                r_KRate(7 downto 0) <= rx_byte;
                r_SM <= s_B2;
              when others => r_SM <= s_NACK;
            end case;
          end if;

        -- ---------------------------------------------------------------
        -- Second payload byte (data or rate-hi)
        -- ---------------------------------------------------------------
        when s_B2 =>
          if rx_dv = '1' then
            case r_Cmd is
              when x"10" =>     -- SET_PHASE_A → table 0
                r_Data   <= rx_byte;
                r_MemTbl <= "000";
                r_MemWrEn <= '1';
                r_LED(1)  <= '1';
                r_SM      <= s_ACK;
              when x"11" =>     -- SET_DP → table 1
                r_Data   <= rx_byte;
                r_MemTbl <= "001";
                r_MemWrEn <= '1';
                r_SM      <= s_ACK;
              when x"12" =>     -- SET_AMP_A → table 2
                r_Data   <= rx_byte;
                r_MemTbl <= "010";
                r_MemWrEn <= '1';
                r_SM      <= s_ACK;
              when x"13" =>     -- SET_AMP_B → table 3
                r_Data   <= rx_byte;
                r_MemTbl <= "011";
                r_MemWrEn <= '1';
                r_SM      <= s_ACK;
              when x"20" =>     -- SET_CAL → table 4
                r_Data   <= rx_byte;
                r_MemTbl <= "100";
                r_MemWrEn <= '1';
                r_SM      <= s_ACK;
              when x"32" =>     -- SET_RATE hi byte
                r_KRate(15 downto 8) <= rx_byte;
                r_SM <= s_ACK;
              when others => r_SM <= s_NACK;
            end case;
          end if;

        -- ---------------------------------------------------------------
        -- Send ACK when UARTSender is ready
        -- ---------------------------------------------------------------
        when s_ACK =>
          if tx_ready = '1' then
            tx_send <= '1';
            tx_data <= ACK;
            r_LED(3) <= '0';
            r_SM     <= s_CMD;
          end if;

        -- ---------------------------------------------------------------
        -- Send NACK on unknown command
        -- ---------------------------------------------------------------
        when s_NACK =>
          if tx_ready = '1' then
            tx_send  <= '1';
            tx_data  <= NACK;
            r_LED(3) <= '1';   -- error LED
            r_SM     <= s_CMD;
          end if;

        -- ---------------------------------------------------------------
        -- Unused B3 state (placeholder for future 3-byte commands)
        -- ---------------------------------------------------------------
        when s_B3 =>
          r_SM <= s_CMD;

      end case;
    end if;
  end process p_FSM;

end rtl;
