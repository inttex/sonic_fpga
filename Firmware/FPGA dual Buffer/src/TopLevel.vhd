-- =============================================================================
-- TopLevel.vhd  —  SonicSurface Dual-Buffer FPGA Top-Level
--
-- Wires together all submodules:
--   Masterclock    50 MHz oscillator → 10.24 MHz system clock
--   Counter        8-bit phase counter (40 kHz / 256 = 10.24 MHz ticks)
--   PhaseLine[256] per-emitter pulse generators (generate from Mux8 inputs)
--   Mux8[32]       8:1 output mux driving DATA[31:0] into 74HC595 chain
--   PatternMem     5-table RAM (phase_A, delta_phase, amp_A, amp_B, cal_offset)
--   KBlend         interpolation engine → phase_arr, amp_arr
--   SpiAdc         MCP3208 SPI master → raw k sample
--   KSource        source mux → k register used by KBlend
--   UARTReader     8N1 RX (115200 baud)
--   UARTSender     8N1 TX (115200 baud)
--   CommandDecoder UART command FSM
--
-- Signal chain:
--   UART RX → CommandDecoder → PatternMem (write)
--   SpiAdc → KSource → KBlend ← PatternMem (read)
--   KBlend → phase_arr / amp_arr → PhaseLine[256]
--   Counter[7:3] → PhaseLine.counter (5-bit phase slot)
--   PhaseLine.pulse → Mux8.data_in → DATA[31:0] → 74HC595 chains
--   Counter[7] → SHIFT_CLOCK_1/2 (one shift per 40 kHz half-period)
--   Counter = 0 → LATCH_CLOCK pulse (once per 40 kHz cycle)
--   Counter[7] (falling) → TRIGGER output
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.DualBuffer_pkg.all;

entity TopLevel is
  port (
    -- Board oscillator (50 MHz on CoreEP4CE6)
    CLK          : in  std_logic;
    -- 74HC595 output chains (emitters)
    DATA         : out std_logic_vector(31 downto 0);
    SHIFT_CLOCK_1: out std_logic;
    LATCH_CLOCK_1: out std_logic;
    SHIFT_CLOCK_2: out std_logic;
    LATCH_CLOCK_2: out std_logic;
    -- Status LEDs (active high)
    LED          : out std_logic_vector(3 downto 0);
    -- UART (CP2102 / CH340 USB-serial adapter)
    UART_RX      : in  std_logic;
    UART_TX      : out std_logic;
    -- MCP3208 SPI ADC
    MCP_CS       : out std_logic;
    MCP_SCK      : out std_logic;
    MCP_MISO     : in  std_logic;
    -- Trigger outputs
    TRIGGER      : out std_logic;
    TRIGGER_K    : out std_logic;
    -- EPCS config flash (reserved, must be declared to avoid pin conflicts)
    EPCS_SDO     : in  std_logic;
    EPCS_SCE     : out std_logic;
    EPCS_CLK     : out std_logic;
    EPCS_DATA0   : in  std_logic
  );
end TopLevel;

architecture rtl of TopLevel is

  -- System clock (10.24 MHz from PLL)
  signal clk_sys : std_logic;

  -- 8-bit phase counter output
  signal cnt_out : std_logic_vector(7 downto 0);

  -- Phase and amplitude arrays (from KBlend → PhaseLine / Mux8)
  signal phase_arr : phase_arr_t;
  signal amp_arr   : amp_arr_t;

  -- PhaseLine pulse outputs: indexed [emitter]
  -- 256 emitters; each 8 consecutive pulses feed one Mux8 → one DATA bit
  signal pulse : pulse_arr_t;

  -- Mux8 sel = counter[2:0] (3-bit, cycles 0-7 within each phase slot)
  signal mux_sel : std_logic_vector(2 downto 0);

  -- PatternMem read/write wiring
  signal mem_rd_addr  : std_logic_vector(7 downto 0);
  signal mem_rd_phA   : std_logic_vector(7 downto 0);
  signal mem_rd_dp    : std_logic_vector(7 downto 0);
  signal mem_rd_ampA  : std_logic_vector(4 downto 0);
  signal mem_rd_ampB  : std_logic_vector(4 downto 0);
  signal mem_rd_cal   : std_logic_vector(7 downto 0);
  signal mem_wr_en    : std_logic;
  signal mem_wr_tbl   : std_logic_vector(2 downto 0);
  signal mem_wr_addr  : std_logic_vector(7 downto 0);
  signal mem_wr_data  : std_logic_vector(7 downto 0);

  -- k and KSource
  signal k_val     : std_logic_vector(7 downto 0);
  signal k_manual  : std_logic_vector(7 downto 0);
  signal k_mode    : std_logic_vector(1 downto 0);
  signal k_rate    : std_logic_vector(15 downto 0);
  signal adc_k     : std_logic_vector(7 downto 0);
  signal adc_valid : std_logic;

  -- UART
  signal rx_dv     : std_logic;
  signal rx_byte   : std_logic_vector(7 downto 0);
  signal tx_send   : std_logic;
  signal tx_data   : std_logic_vector(7 downto 0);
  signal tx_ready  : std_logic;

  -- Shift/latch clock generation
  signal prev_cnt7  : std_logic := '0';
  signal latch_pulse : std_logic := '0';

begin

  -- ===========================================================================
  -- PLL: 50 MHz → 10.24 MHz
  -- ===========================================================================
  u_PLL : entity work.Masterclock
    port map (inclk0 => CLK, c0 => clk_sys);

  -- ===========================================================================
  -- 8-bit phase counter (free-running, no reset)
  -- Rolls over every 256 clocks → 10.24 MHz / 256 = 40 kHz
  -- ===========================================================================
  u_CNT : entity work.Counter
    generic map (COUNTER_BITS => 8)
    port map (clk_in => clk_sys, sync_reset => '0', clk_out => cnt_out);

  mux_sel <= cnt_out(2 downto 0);

  -- ===========================================================================
  -- 256 × PhaseLine + 32 × Mux8
  -- Emitter N is on DATA pin (N/8), within that pin on slot (N mod 8).
  -- So PhaseLine[N].pulse → Mux8[N/8].data_in(N mod 8)
  -- ===========================================================================
  gen_emitters : for i in 0 to C_NUM_EMITTERS - 1 generate
    u_PL : entity work.PhaseLine
      port map (
        clk     => clk_sys,
        phase   => phase_arr(i),
        counter => cnt_out(7 downto 3),
        pulse   => pulse(i)
      );
  end generate;

  gen_mux : for d in 0 to C_NUM_DATA_PINS - 1 generate
    u_MX : entity work.Mux8
      port map (
        clk      => clk_sys,
        data_in  => pulse(d*8+7) & pulse(d*8+6) & pulse(d*8+5) & pulse(d*8+4) &
                    pulse(d*8+3) & pulse(d*8+2) & pulse(d*8+1) & pulse(d*8+0),
        sel      => mux_sel,
        data_out => DATA(d)
      );
  end generate;

  -- ===========================================================================
  -- Shift / Latch clock generation from counter
  --   SHIFT_CLOCK = cnt_out[3] (half-period of the phase-slot clock ≈ 1.28 MHz)
  --   LATCH pulse  = one cycle when cnt_out transitions from 255→0
  -- ===========================================================================
  p_CLOCKS : process (clk_sys)
  begin
    if rising_edge(clk_sys) then
      prev_cnt7   <= cnt_out(7);
      latch_pulse <= '0';
      -- Latch on rollover (cnt_out goes from 11111111 → 00000000)
      if cnt_out = x"00" and prev_cnt7 = '1' then
        latch_pulse <= '1';
      end if;
    end if;
  end process;

  SHIFT_CLOCK_1 <= cnt_out(3);
  SHIFT_CLOCK_2 <= cnt_out(3);
  LATCH_CLOCK_1 <= latch_pulse;
  LATCH_CLOCK_2 <= latch_pulse;

  -- TRIGGER: one pulse per 40 kHz cycle (= latch pulse)
  TRIGGER   <= latch_pulse;
  -- TRIGGER_K: mirrors TRIGGER (routed to PIN_34, not PCB-connected by default)
  TRIGGER_K <= latch_pulse;

  -- ===========================================================================
  -- PatternMem
  -- ===========================================================================
  u_MEM : entity work.PatternMem
    port map (
      clk        => clk_sys,
      wr_en      => mem_wr_en,
      wr_tbl     => mem_wr_tbl,
      wr_addr    => mem_wr_addr,
      wr_data    => mem_wr_data,
      rd_addr    => mem_rd_addr,
      rd_phase_a => mem_rd_phA,
      rd_dp      => mem_rd_dp,
      rd_amp_a   => mem_rd_ampA,
      rd_amp_b   => mem_rd_ampB,
      rd_cal     => mem_rd_cal
    );

  -- ===========================================================================
  -- KBlend
  -- ===========================================================================
  u_KB : entity work.KBlend
    port map (
      clk        => clk_sys,
      k          => k_val,
      rd_addr    => mem_rd_addr,
      rd_phase_a => mem_rd_phA,
      rd_dp      => mem_rd_dp,
      rd_amp_a   => mem_rd_ampA,
      rd_amp_b   => mem_rd_ampB,
      rd_cal     => mem_rd_cal,
      o_phase_arr=> phase_arr,
      o_amp_arr  => amp_arr
    );

  -- ===========================================================================
  -- SpiAdc (MCP3208 channel 0)
  -- ===========================================================================
  u_ADC : entity work.SpiAdc
    port map (
      clk      => clk_sys,
      mcp_cs   => MCP_CS,
      mcp_sck  => MCP_SCK,
      mcp_miso => MCP_MISO,
      o_k      => adc_k,
      o_valid  => adc_valid
    );

  -- ===========================================================================
  -- KSource (k mux: manual / ADC / internal ramp)
  -- ===========================================================================
  u_KSR : entity work.KSource
    port map (
      clk         => clk_sys,
      i_mode      => k_mode,
      i_manual_k  => k_manual,
      i_adc_k     => adc_k,
      i_adc_valid => adc_valid,
      i_rate      => k_rate,
      o_k         => k_val
    );

  -- ===========================================================================
  -- UARTReader (115200 8N1, 10.24 MHz → 89 clocks/bit)
  -- ===========================================================================
  u_RXD : entity work.UARTReader
    generic map (g_CLKS_PER_BIT => 89)
    port map (
      i_Clk       => clk_sys,
      i_RX_Serial => UART_RX,
      o_RX_DV     => rx_dv,
      o_RX_Byte   => rx_byte
    );

  -- ===========================================================================
  -- UARTSender (115200 8N1)
  -- ===========================================================================
  u_TXD : entity work.UARTSender
    generic map (g_CLKS_PER_BIT => 89)
    port map (
      clk     => clk_sys,
      send    => tx_send,
      data_in => tx_data,
      tx      => UART_TX,
      ready   => tx_ready
    );

  -- ===========================================================================
  -- CommandDecoder
  -- ===========================================================================
  u_CMD : entity work.CommandDecoder
    port map (
      clk         => clk_sys,
      rx_dv       => rx_dv,
      rx_byte     => rx_byte,
      tx_send     => tx_send,
      tx_data     => tx_data,
      tx_ready    => tx_ready,
      mem_wr_en   => mem_wr_en,
      mem_wr_tbl  => mem_wr_tbl,
      mem_wr_addr => mem_wr_addr,
      mem_wr_data => mem_wr_data,
      k_manual    => k_manual,
      k_mode      => k_mode,
      k_rate      => k_rate,
      led         => LED
    );

  -- EPCS config flash: held in passive state (FPGA configured via JTAG in dev)
  EPCS_SCE  <= '1';
  EPCS_CLK  <= '0';

end rtl;
