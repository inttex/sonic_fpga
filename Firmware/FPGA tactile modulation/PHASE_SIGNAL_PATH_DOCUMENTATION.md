# Phase Signal Path Documentation: Java to FPGA to Emitters

This document explains the complete signal path from Java software to ultrasonic emitters, including phase delays, timing, and modulation.

**Last Updated**: 2026-01-19
**Branch**: phase_fix_16bit
**Status**: ✅ Reviewed and corrected with actual VHDL code

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Clock Generation](#clock-generation)
3. [Phase Data Flow](#phase-data-flow)
4. [Temporal Signal Generation](#temporal-signal-generation)
5. [Amplitude Modulation](#amplitude-modulation)
6. [Complete Signal Path Example](#complete-signal-path-example)

---

## 1. System Overview

### Signal Path Summary
```
Java Application (SimpleFPGA_Tactile.java)
    ↓ (UART @ 115200 baud)
UARTReader.vhd (FPGA)
    ↓ (8-bit bytes: q_in)
Distribute.vhd
    ↓ (Phase + PHASE_CORRECTION calibration)
AllChannels.vhd
    ↓ (Distributes to 256 PhaseLine instances)
PhaseLine.vhd (×256 instances)
    ↓ (Generates phase-shifted pulses)
Mux8.vhd (×32 instances)
    ↓ (8:1 time-division multiplexing)
32 Output Pins → 256 Ultrasonic Emitters (40 kHz)
```

### Key Parameters
- **Ultrasonic Frequency**: 40 kHz (25 µs period)
- **Phase Divisions**: 16 (0-15)
- **Phase Resolution**: 25 µs / 16 = **1.5625 µs per division**
- **Number of Emitters**: 256
- **Output Channels**: 32 (8:1 multiplexing)
- **Pulse Width**: 7 clock cycles = **1.367 µs** (5.47% duty cycle)
- **Modulation Frequency**: Configurable via `steps` parameter (1-31)

---

## 2. Clock Generation

### Master Clock (Masterclock.vhd)
```
Input Clock:  50 MHz (from crystal oscillator)
PLL Configuration:
  - Divide by: 625
  - Multiply by: 64
  - Output: 50 MHz × (64/625) = 5.12 MHz

Main Clock (clk): 5.12 MHz
  - Period: 195.3125 ns (1/5.12 MHz)
  - Used for: Counter, phase logic, all synchronous operations
```

### Counter Generation (Counter.vhd)
```vhdl
-- 7-bit counter: 0 to 127
signal sCounter : STD_LOGIC_VECTOR (6 downto 0);

-- Increments on every clk rising edge
-- Wraps around: 0 → 1 → 2 → ... → 127 → 0
```

**Counter Timing**:
- Increment rate: 5.12 MHz (every 195.3125 ns)
- Full cycle (0-127): 128 × 195.3125 ns = **25 µs** (40 kHz period) ✓
- Counter bits used for phase comparison: `counter(6:3)` = 4 bits (0-15)
- Counter bits used for mux selection: `counter(2:0)` = 3 bits (0-7)

**Phase Division Timing**:
- Each phase division: 25 µs / 16 = **1.5625 µs**
- Each phase division: 8 clock cycles (8 × 195.3125 ns = 1.5625 µs)

---

## 3. Phase Data Flow

### Step 1: Java Calculates Phase (SimpleFPGA_Tactile.java)
```java
// For each transducer
int phase = t.getDiscPhase(16);  // 16 divisions: 0-15
int PHASE_OFF = 16;              // Value 16 means "OFF"

// If amplitude is 0, send OFF command
if (t.getpAmplitude() == 0) {
    phase = PHASE_OFF;  // Send 16 (0x10)
}

// Send via UART
phaseDataPlusHeader[0] = 254;    // Start command (0xFE)
phaseDataPlusHeader[1..256] = phase values for each emitter (0-15 or 16 for OFF)
serial.write(phaseDataPlusHeader);
```

### Step 2: FPGA Receives Data (UARTReader.vhd)
```
UART Settings:
  - Baud rate: 115200
  - Data bits: 8
  - Stop bits: 1
  - Parity: None

Receives byte stream:
  [254] [phase0] [phase1] [phase2] ... [phase255]

Special commands:
  254 (0xFE) - Start phases command
  253 (0xFD) - Swap buffers command
  160-191 (0b101XXXXX) - Set modulation steps (bits 4:0)
```

### Step 3: Distribute Module Applies Calibration (Distribute.vhd)

**CRITICAL CORRECTION**: The actual code uses `to_unsigned(..., 4)` not `to_unsigned(..., 8)`!

```vhdl
-- Receive phase value from Java (0-15 for ON, 16 for OFF)
if (q_in = "00010000") then  -- 16 = OFF
    s_data_out <= q_in;      -- Pass through unchanged
else
    -- Add phase calibration, convert to 4 bits (auto wrap at 16), mask to 4 bits
    s_data_out <= std_logic_vector(
        to_unsigned(
            to_integer(unsigned(q_in)) + PHASE_CORRECTION(s_ByteCounter),
            4  -- ← 4 bits! Not 8!
        )
    ) and "00001111";
end if;
```

**Phase Calibration Array** (divided by 2 for 16-division system):
```vhdl
type T_PHASE_CORRECTION is array (0 to 255) of integer range 0 to 16;
constant PHASE_CORRECTION : T_PHASE_CORRECTION :=
  (11,5,6,5,13,14,13,13,5,6,6,13,14,5,6,6,...)
```

**Example Calculation**:
```
Java sends:     phase = 8 (for emitter #0)
Calibration:    PHASE_CORRECTION(0) = 11
Sum:            8 + 11 = 19
to_unsigned(19, 4): Wraps at 16 → 19 mod 16 = 3
Mask:           3 and 0x0F = 3
Final phase:    3 (4-bit value, 0-15)

This is CORRECT behavior for 16-division system!
```

### Step 4: AllChannels Distributes to PhaseLine (AllChannels.vhd)
```vhdl
-- AllChannels extracts bits from phase and counter
PhaseLine_inst : PhaseLine PORT MAP (
    phase => phase(5 downto 1),      -- Extract bits 5:1 → 5 bits (but only 0-16 used)
    counter => counter(6 downto 3),  -- Extract bits 6:3 → 4 bits (0-15)
    ...
);
```

**Bit Extraction Explained**:
```
phase input (from Distribute):  [7][6][5][4][3][2][1][0]
                                        └─────┬─────┘
                                    Extracted: bits 5:1

Why bits 5:1? Because phase can be 0-16 (needs 5 bits)
  - phase = 0  → bits 5:1 = 00000 → 0
  - phase = 15 → bits 5:1 = 01111 → 15
  - phase = 16 → bits 5:1 = 10000 → 16 (OFF state)

counter input:  [6][5][4][3][2][1][0]
                   └───┬───┘  └──┬──┘
                   Phase(4b)  Mux(3b)

counter(6:3) = 4 bits for phase comparison (0-15)
counter(2:0) = 3 bits for mux selection (0-7)
```
---

## 4. Timing Diagrams

### Diagram 1: Counter and 40 kHz Generation

```wavedrom
{
  signal: [
    {name: 'clk (5.12MHz)', wave: 'p...............', period: 0.5},
    {},
    {name: 'counter[6:0]', wave: '22222222........', data: ['0','1','2','3','4','5','6','7','...','127','0'], period: 0.5},
    {},
    {name: 'counter[6:3]', wave: '2.......3.......', data: ['0','1'], period: 4},
    {name: '(phase bits)', wave: 'x', period: 0.5},
    {},
    {name: 'counter[2:0]', wave: '22222222........', data: ['0','1','2','3','4','5','6','7','0'], period: 0.5},
    {name: '(mux bits)', wave: 'x', period: 0.5}
  ],
  config: { hscale: 2 },
  head: {
    text: 'Counter Generation: 7-bit counter creates 40kHz (25µs period)',
    tick: 0
  },
  foot: {
    text: 'counter[6:3] increments every 8 clocks (1.5625µs), counter[2:0] selects mux channel',
    tock: 0
  }
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-1.svg)



![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-1.svg)

---

### Diagram 2: Phase-Shifted Pulse Generation

```wavedrom
{
  signal: [
    {name: 'counter[6:3]', wave: '2222222222222222', data: ['0','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15'], period: 1},
    {},
    {name: 'Emitter #0 (phase=0)', wave: '01......0.......', period: 1, node: '.a......b'},
    {name: 'Emitter #1 (phase=5)', wave: '0.....1......0..', period: 1, node: '.....c......d'},
    {name: 'Emitter #2 (phase=10)', wave: '0..........1....', period: 1, node: '..........e.....'},
    {},
    {name: 'Phase Offset', wave: 'x', data: ['0°', '112.5°', '225°']}
  ],
  edge: ['a~>b 1.367µs (7 clocks)', 'c~>d 1.367µs', 'e-~>a 5 divisions'],
  config: { hscale: 2 },
  head: {
    text: 'Phase-Shifted Pulses: Different start times create interference pattern',
    tick: 0
  },
  foot: {
    text: 'Pulse width = 7 clocks = 1.367µs. Phase shift creates focal point via constructive interference.',
    tock: 0
  }
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-2.svg)



![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-2.svg)

**Key Points**:
- Each emitter fires a 1.367 µs pulse (7 clock cycles)
- Phase determines WHEN the pulse starts within the 25 µs period
- Phase 0 = 0°, Phase 5 = 112.5°, Phase 10 = 225°
- Different phases create constructive/destructive interference → focal point!

---

### Diagram 3: PhaseLine Pulse Generation Logic

```wavedrom
{
  signal: [
    {name: 'clk (5.12MHz)', wave: 'p...............', period: 0.5},
    {},
    {name: 'counter[6:3]', wave: '2.......3.......', data: ['2','3'], period: 4},
    {},
    {name: 's_phaseCurrent', wave: '3...............', data: ['3'], period: 0.5},
    {name: 'match?', wave: '0.......10......', period: 0.5, node: '........a'},
    {},
    {name: 's_counter', wave: '2.......3456789x', data: ['0','7','6','5','4','3','2','1','0'], period: 0.5},
    {},
    {name: 'pulse', wave: '0........1......0', period: 0.5, node: '.........b......c'},
    {name: 'enabled', wave: '1...............', period: 0.5}
  ],
  edge: ['a-~>b Load s_counter=7', 'b~>c 7 clocks = 1.367µs'],
  config: { hscale: 2 },
  head: {
    text: 'PhaseLine Logic: When counter[6:3] matches phase, start 7-clock pulse',
    tick: 0
  },
  foot: {
    text: 'pulse = (s_counter > 0) AND enabled. Pulse width = 7 × 195.3ns = 1.367µs',
    tock: 0
  }
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-3.svg)



![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-3.svg)

**PhaseLine.vhd Logic**:
```vhdl
-- When counter matches phase, load s_counter with 7
if (s_phaseCurrent = to_integer(unsigned(counter))) then
    s_counter <= 7;
end if;

-- Count down and generate pulse
if (s_counter = 0) then
    pulse <= '0';
else
    s_counter <= s_counter - 1;
    pulse <= '1' and enabled;  -- Pulse only if enabled
end if;
```

---

## 5. Amplitude Modulation

### AmpModulator.vhd - Generates chgClock

```vhdl
-- AmpModulator generates a pulse every 'steps' clock cycles
if (s_stepCounter = to_integer(unsigned(steps))) then
    s_stepCounter <= 0;
    chgClock <= '1';  -- Pulse for one clock cycle
    s_amp <= s_amp + 1;  -- Increment counter (0-255)
else
    s_stepCounter <= s_stepCounter + 1;
    chgClock <= '0';
end if;
```

**Modulation Frequency**:
```
chgClock period = steps × 195.3125 ns

steps = 10:  period = 1.953 µs  →  512 kHz
steps = 20:  period = 3.906 µs  →  256 kHz
steps = 31:  period = 6.055 µs  →  165 kHz
```

### Diagram 4: AmpModulator Clock Generation

```wavedrom
{
  signal: [
    {name: 'clk (5.12MHz)', wave: 'p..........', period: 0.5},
    {},
    {name: 's_stepCounter', wave: '2222222222x', data: ['0','1','2','...','8','9','10','0'], period: 0.5},
    {},
    {name: 'chgClock', wave: '0..........10', period: 0.5, node: '...........a'},
    {},
    {name: 's_amp', wave: '2..........3.', data: ['N','N+1'], period: 0.5}
  ],
  edge: ['a-~>a 10 clocks = 1.953µs (steps=10)'],
  config: { hscale: 2 },
  head: {
    text: 'AmpModulator: Generates chgClock pulse every "steps" clock cycles',
    tick: 0
  },
  foot: {
    text: 'chgClock triggers emitter enable/disable toggling. s_amp increments 0→255.',
    tock: 0
  }
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-4.svg)



![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-4.svg)

---

### AllChannels.vhd - Toggles Emitter Enable

**CRITICAL ISSUE IDENTIFIED**: The current code toggles ONE emitter at a time, not all!

```vhdl
-- Current implementation (PROBLEMATIC):
AllChannels: process (chgClock) begin
    if (rising_edge(chgClock)) then
        -- Toggles ONLY the emitter indexed by pulse_length
        s_enabled(to_integer(unsigned(pulse_length))) <=
            NOT s_enabled(to_integer(unsigned(pulse_length)));
    end if;
end process;
```

**What this does**:
- `pulse_length` comes from `amp` output of AmpModulator (0-255)
- Each `chgClock` pulse toggles emitter #`pulse_length`
- Since `amp` increments 0→1→2→...→255, emitters toggle sequentially
- **This causes the 10ms phase shift problem!**

**Expected behavior** (for synchronous modulation):
```vhdl
-- All emitters should toggle together:
AllChannels: process (chgClock) begin
    if (rising_edge(chgClock)) then
        s_enabled <= NOT s_enabled;  -- Toggle ALL emitters
    end if;
end process;
```

---

## 6. Complete Signal Path Example

### Scenario: Two Emitters Creating Focal Point

**Java Side**:
```java
Emitter #0: phase = 8,  amplitude = 1.0
Emitter #1: phase = 12, amplitude = 1.0

Serial TX: [254][8][12][...] → UART @ 115200 baud
```

**FPGA Processing**:

1. **Distribute.vhd** - Apply calibration:
```
Emitter #0:
  Input: 8
  Calibration: PHASE_CORRECTION[0] = 11
  Sum: 8 + 11 = 19
  to_unsigned(19, 4): 19 mod 16 = 3
  Mask: 3 and 0x0F = 3
  Output: 3

Emitter #1:
  Input: 12
  Calibration: PHASE_CORRECTION[1] = 5
  Sum: 12 + 5 = 17
  to_unsigned(17, 4): 17 mod 16 = 1
  Mask: 1 and 0x0F = 1
  Output: 1
```

2. **AllChannels.vhd** - Extract phase bits:
```
Emitter #0: phase(5:1) = 3(5:1) = 00011 → 00001 = 1
Emitter #1: phase(5:1) = 1(5:1) = 00001 → 00000 = 0
```

3. **PhaseLine.vhd** - Generate pulses:
```
Counter[6:3]: 0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
              ├───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┤

Emitter #0 (phase=1):
Pulse:        ░░░░░░░░█████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

Emitter #1 (phase=0):
Pulse:        ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### Diagram 5: Complete Example

```wavedrom
{
  signal: [
    {name: 'counter[6:3]', wave: '2222222222222222', data: ['0','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15'], period: 1},
    {},
    {name: 'Emitter #0 (phase=1)', wave: '0.1......0......', period: 1, node: '..a......b'},
    {name: 'Emitter #1 (phase=0)', wave: '01......0.......', period: 1, node: '.c......d'},
    {},
    {name: 'Interference', wave: 'x23.....x.......', data: ['Peak','Peak'], period: 1}
  ],
  edge: ['a-c 1 division offset', 'b-d Creates focal point'],
  config: { hscale: 2 },
  head: {
    text: 'Complete Signal Path: Phase calibration + extraction creates precise timing',
    tick: 0
  },
  foot: {
    text: 'Phase offset creates constructive interference → focal point in 3D space',
    tock: 0
  }
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-5.svg)



![WaveDrom Diagram](./wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-5.svg)



---

## 7. Summary

### Key Frequencies and Timing

| Signal | Frequency | Period | Purpose |
|--------|-----------|--------|---------|
| Master Clock | 5.12 MHz | 195.3125 ns | FPGA synchronous logic |
| Counter Full Cycle | 40 kHz | 25 µs | Ultrasonic carrier frequency |
| Phase Division | - | 1.5625 µs | Phase resolution (16 divisions) |
| Pulse Width | - | 1.367 µs | Emitter ON time (7 clocks, 5.47% duty cycle) |
| chgClock (steps=10) | 512 kHz | 1.953 µs | Modulation trigger |

### Phase Calibration Impact

The PHASE_CORRECTION array compensates for physical variations in each transducer:

```
Without Calibration:
  Java sends phase=8 → FPGA uses phase=8 → Emitter fires at wrong time
  → Focal point is distorted or shifted

With Calibration:
  Java sends phase=8 → FPGA adds correction (+11) → sum=19
  → to_unsigned(19, 4) wraps to 3 → Emitter fires at correct time
  → Perfect focal point!
```

**Why divide by 2?**
- Original calibration was for 32 divisions (0-31)
- Current system uses 16 divisions (0-15)
- Calibration values must be scaled: `new_cal = old_cal / 2`

### Critical Findings

1. **Phase Correction Uses 4-bit Conversion**:
   - `to_unsigned(..., 4)` automatically wraps at 16
   - This is correct for 16-division system
   - The `and "00001111"` mask is redundant but harmless

2. **Modulation Synchronization Issue**:
   - Current code toggles ONE emitter per chgClock pulse
   - Emitters toggle sequentially, not synchronously
   - This causes ~10ms phase shifts between emitters
   - **Fix**: Toggle all emitters together with `s_enabled <= NOT s_enabled`

3. **Pulse Width is Fixed**:
   - Always 7 clock cycles = 1.367 µs
   - Duty cycle = 1.367 µs / 25 µs = 5.47%
   - This is correct for the current design

---

## Document Version
- **Created**: 2026-01-16
- **Last Updated**: 2026-01-19
- **System**: FPGA Tactile Modulation Firmware
- **Branch**: phase_fix_16bit
- **Status**: ✅ Reviewed and corrected with actual VHDL code

