# Phase Communication: Java to FPGA to Temporal Signals

## Complete Data Flow Documentation

This document explains how phase information travels from Java calculations through serial communication to the FPGA, and finally becomes temporal ultrasonic signals.

---

## Overview

The system creates acoustic focal points by controlling the phase of 256 ultrasonic emitters (40 kHz). Each emitter must pulse at a specific phase offset to create constructive interference at the target point.

**Key Concept:** Phase in space (distance) → Phase in time (when to pulse)

---

## Part 1: Java - Phase Calculation

### 1.1 Physical Phase Calculation
**File:** `SimplePhaseAlgorithms.java`

```java
// Calculate distance from emitter to focal point
final float distance = target.distance(transducer.position);

// Calculate wavelength (λ = c/f)
final float waveLength = speedOfSound / frequency;  // ~8.65mm at 40kHz

// Calculate phase in radians (0 to 2π)
final float targetPhase = (1.0f - decPart(distance / waveLength)) * 2.0f * PI;

// Normalize to range 0-2 (divide by π)
transducer.setPhase(targetPhase / PI);
```

**Example:**
- Distance = 100mm
- Wavelength = 8.65mm
- distance/wavelength = 11.56 wavelengths
- Fractional part = 0.56
- targetPhase = (1.0 - 0.56) * 2π = 0.44 * 2π = 2.76 radians
- Normalized phase = 2.76 / π = 0.88 (range 0-2)

### 1.2 Discretization to Integer Values
**File:** `Transducer.java`

```java
// Convert continuous phase (0-2) to discrete steps (0-15)
int discretePhase = Math.round(phase * divs / 2) % divs;
// With divs=16: phase * 16 / 2 = phase * 8
```

**Example:**
- phase = 0.88
- discretePhase = round(0.88 * 8) % 16 = round(7.04) % 16 = 7

**Result:** Phase value 0-15 (4 bits)

### 1.3 Serial Transmission
**File:** `SimpleFPGA_Tactile.java`

```java
// Build packet: [Header][Phase0][Phase1]...[Phase255]
byte[] packet = new byte[257];
packet[0] = 254;  // Start phases command (0xFE)

for (int i = 0; i < 256; i++) {
    int phase = transducer[i].getDiscPhase(16);  // 0-15
    if (amplitude == 0) {
        phase = 16;  // OFF command
    }
    packet[i+1] = (byte)(phase & 0xFF);
}

serial.write(packet);  // Send at 230400 baud
```

**Packet Structure:**
```
[254][7][12][0][15]...[16]
  ^    ^  ^   ^  ^      ^
  |    |  |   |  |      +-- Emitter 255: OFF
  |    |  |   |  +--------- Emitter 3: Phase 15
  |    |  |   +------------ Emitter 2: Phase 0
  |    |  +---------------- Emitter 1: Phase 12
  |    +------------------- Emitter 0: Phase 7
  +------------------------ Command: Start Phases
```

---

## Part 2: FPGA - Serial Reception and Processing

### 2.1 UART Reception
**Component:** UART Receiver (not shown, standard component)

- Receives bytes at 230400 baud
- Outputs: `byte_in` (pulse), `q_in` (8-bit data)

### 2.2 Distribute - Command Decoder and Phase Processing
**File:** `Distribute.vhd`

```vhdl
-- Receives serial bytes and processes them
process (clk)
begin
    if rising_edge(clk) then
        if (byte_in = '1') then  -- New byte received

            if (q_in = "11111110") then  -- 254 = Start Phases
                s_ByteCounter <= 0;

            elsif (q_in = "11111101") then  -- 253 = Swap Buffers
                s_swap_out <= '1';

            else  -- Phase data byte
                -- Apply phase correction and scaling
                if (q_in = "00010000") then  -- 16 = OFF
                    s_data_out <= "00100000";  -- Output 32
                else
                    -- Multiply by 2 and add calibration
                    s_data_out <= ((q_in * 2) + (CORRECTION[ByteCounter] / 2)) mod 64;
                end if;

                s_address <= ByteCounter;  -- Which emitter (0-255)
                s_set_out <= '1';  -- Trigger storage
                s_ByteCounter <= s_ByteCounter + 1;
            end if;
        end if;
    end if;
end process;
```

**Example Processing:**
```
Input:  q_in = 7 (from Java)
Correction: PHASE_CORRECTION[0] = 14
Calculation: (7 * 2) + (14 / 2) = 14 + 7 = 21
Output: s_data_out = 21 mod 64 = 21
```

**Why multiply by 2?**
- AllChannels will take bits(5:1), which divides by 2
- We compensate by multiplying here
- Final result: 21 → bits(5:1) → 10 (correct phase!)




### 2.3 Phase Storage (Double Buffering)
**Component:** RAM blocks (inferred from code)

Each emitter has two phase values stored:
- `s_phasePrev`: Newly received phase (being written)
- `s_phaseCurrent`: Active phase (currently used)

**Swap Operation:**
```vhdl
if (swap = '1') then
    s_phaseCurrent <= s_phasePrev;  -- Activate new phase
    s_phasePrev <= s_phaseCurrent;  -- Save old phase
end if;
```

This allows updating all 256 emitters simultaneously without glitches.

---

## Part 3: FPGA - Timing Generation

### 3.1 Master Clock and Counter
**Files:** `Masterclock.vhd`, `Counter.vhd`

```
Crystal Oscillator (50 MHz)
    ↓
Masterclock PLL
    ↓
System Clock (50 MHz)
    ↓
Counter (7-bit, counts 0-127)
    ↓
Increments every clock cycle
```

**Counter Output:**
- 7 bits: `counter[6:0]`
- Counts: 0 → 1 → 2 → ... → 127 → 0 → 1 → ...
- Period: 128 clock cycles = 2.56 μs at 50 MHz
- Frequency: 390.625 kHz

### 3.2 AllChannels - Bit Extraction
**File:** `AllChannels.vhd`

AllChannels receives two key inputs:
1. **`phase`** - 8-bit value from Distribute (via serial from Java)
2. **`counter`** - 7-bit value from Counter module (FPGA internal, NOT from Java)

```vhdl
-- AllChannels port declaration
port (
    counter : in std_logic_vector(6 downto 0);  -- From Counter.vhd (FPGA internal)
    phase : in std_logic_vector(7 downto 0);    -- From Distribute.vhd (from Java)
    ...
);

-- Extract phase bits for PhaseLine
phase_to_phaseline <= phase(5 downto 1);  -- Divide by 2, gives 5 bits (0-31)

-- Extract counter bits for PhaseLine
counter_to_phaseline <= counter(6 downto 3);  -- Divide by 8, gives 4 bits (0-15)
```

**Why these bit ranges?**

**Phase bits(5:1) - FROM JAVA:**
- Input: 8-bit value (0-63 from Distribute, originally from Java serial)
- Take bits 5,4,3,2,1 (ignore bit 0)
- Result: 5-bit value (0-31)
- This divides by 2: value 21 → bits(5:1) = 10
- **This is the TARGET phase for each emitter**

**Counter bits(6:3) - FPGA INTERNAL:**
- Input: 7-bit counter (0-127 from Counter.vhd, runs continuously on FPGA)
- Take bits 6,5,4,3 (ignore bits 2,1,0)
- Result: 4-bit value (0-15)
- This divides by 8: counter 80 → bits(6:3) = 10
- **This is the CURRENT time reference that all emitters compare against**

**Timing:**
- Counter increments every clock cycle (20 ns at 50 MHz)
- bits(6:3) changes every 8 clock cycles = 160 ns
- bits(6:3) cycles through 0-15 in 16 steps = 2.56 μs
- Frequency: 390.625 kHz (not 40 kHz yet!)

**Key Concept - Phase Matching:**
The counter is like a clock that all emitters watch. Each emitter has been told (by Java) what time to "wake up":
- **Java says:** "Emitter 0, your phase is 10" → stored in PhaseLine
- **Counter says:** "Current time is 0, 1, 2, 3, ... 9, **10**, 11, ..." → broadcast to all PhaseLine instances
- **Emitter 0 thinks:** "Counter is 10, my phase is 10 → MATCH! → Pulse now!"

This is how different emitters pulse at different times, creating the phase relationships needed for focal points.

---

## Part 4: FPGA - Pulse Generation

### 4.1 PhaseLine - Phase Matching and Pulse Creation
**File:** `PhaseLine.vhd`

```vhdl
process (clk)
begin
    if rising_edge(clk) then
        -- Check if current phase matches counter
        if (s_phaseCurrent = to_integer(unsigned(counter))) then
            s_counter <= 7;  -- Start pulse (8 clock cycles)
        end if;

        -- Generate pulse output
        if (s_counter = 0) then
            pulse <= '0';  -- No pulse
        else
            s_counter <= s_counter - 1;  -- Count down
            pulse <= '1' and enabled;  -- Output pulse (if enabled)
        end if;
    end if;
end process;
```

**How it works:**

1. **Phase Matching:**
   - `s_phaseCurrent` = 10 (from our example)
   - `counter` counts 0,1,2,...,9,**10**,11,12,...,15,0,1,...
   - When counter = 10 → **MATCH!** → Set `s_counter = 7`

2. **Pulse Generation:**
   - `s_counter` = 7 → pulse = 1
   - `s_counter` = 6 → pulse = 1
   - `s_counter` = 5 → pulse = 1
   - ...
   - `s_counter` = 1 → pulse = 1
   - `s_counter` = 0 → pulse = 0

   **Result:** Pulse is HIGH for 8 clock cycles (160 ns)

3. **Timing Diagram:**
```
counter:     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15  0  1  2  3  4  5  6  7  8  9 10 11
s_counter:   0  0  0  0  0  0  0  0  0  0  7  6  5  4  3  2  1  0  0  0  0  0  0  0  0  0  7  6
pulse:       0  0  0  0  0  0  0  0  0  0  1  1  1  1  1  1  1  0  0  0  0  0  0  0  0  0  1  1
                                            ↑
                                         Phase 10
```

**Pulse Characteristics:**
- Width: 8 clock cycles = 160 ns
- Period: 16 counter steps = 2.56 μs
- Frequency: 390.625 kHz (still not 40 kHz!)


### 4.2 Mux8 - Time Division Multiplexing to 40 kHz
**File:** `Mux8.vhd` (component in AllChannels)

The secret to getting 40 kHz from 390.625 kHz!

```vhdl
-- 8 emitters share one output pin
Mux8: for i in 0 to 31 generate  -- 32 muxes for 256 emitters
    Mux8_inst : Mux8 PORT MAP (
        clk => clk8,  -- 8x faster clock
        data_in => s_pulseToMux(i*8+7 downto i*8),  -- 8 emitter pulses
        sel => counter(2 downto 0),  -- Select which emitter (0-7)
        data_out => data_out(i)  -- One output pin
    );
end generate;
```

**How it works:**

1. **8 Emitters per Output:**
   - Emitters 0-7 → Output pin 0
   - Emitters 8-15 → Output pin 1
   - ...
   - Emitters 248-255 → Output pin 31

2. **Time Division Multiplexing:**
   - `counter(2:0)` cycles: 0,1,2,3,4,5,6,7,0,1,2,3,4,5,6,7,...
   - Each value selects one of the 8 emitters
   - Each emitter gets 1/8 of the time

3. **Timing:**
   - `counter(2:0)` changes every clock cycle (20 ns)
   - Full cycle through 0-7 = 8 clock cycles = 160 ns
   - But each emitter only pulses once per 16 counter(6:3) steps
   - Effective period = 128 clock cycles = 2.56 μs
   - **Output frequency = 1 / 2.56 μs = 390.625 kHz**

**Wait, still not 40 kHz!**

The pulses repeat at 390.625 kHz, but there are **multiple pulses per 40 kHz cycle**:
- 40 kHz period = 25 μs
- Number of pulses per 40 kHz cycle = 25 μs / 2.56 μs ≈ 9.76 pulses

The ultrasonic transducer acts as a **mechanical resonator** at 40 kHz:
- It receives short pulses at 390.625 kHz
- It resonates and outputs continuous 40 kHz sine wave
- The phase of the pulses controls the phase of the 40 kHz output

---

## Part 5: Complete Example - End to End

### Example: Create focal point 100mm away from Emitter 0

**Step 1: Java calculates phase**
```
Distance = 100mm
Wavelength = 8.65mm (at 40kHz)
Wavelengths = 100 / 8.65 = 11.56
Fractional part = 0.56
Phase (radians) = (1.0 - 0.56) * 2π = 2.76 rad
Phase (normalized) = 2.76 / π = 0.88
```

**Step 2: Java discretizes**
```
Discrete phase = round(0.88 * 8) = round(7.04) = 7
```

**Step 3: Java sends via serial**
```
Packet: [254][7][...other emitters...]
```

**Step 4: FPGA Distribute processes**
```
Input: 7
Correction: 14 (example)
Calculation: (7 * 2) + (14 / 2) = 14 + 7 = 21
Output: 21
```

**Step 5: FPGA AllChannels extracts bits**
```
Phase bits(5:1): 21 >> 1 = 10
Counter bits(6:3): varies 0-15
```

**Step 6: FPGA PhaseLine generates pulse**
```
When counter(6:3) = 10:
  - Trigger pulse
  - Pulse HIGH for 8 clock cycles (160 ns)
  - Pulse repeats every 16 counter steps (2.56 μs)
```

**Step 7: Mux8 outputs to pin**
```
Emitter 0 shares pin with emitters 1-7
Time slot 0: Emitter 0 pulse appears on output
Time slots 1-7: Other emitters' pulses
```

**Step 8: Ultrasonic transducer resonates**
```
Input: Pulses at 390.625 kHz with phase offset
Output: 40 kHz sine wave with controlled phase
```

---

## Part 6: Phase Relationships Between Emitters

### How different emitters create focal point

**Emitter 0:** Phase = 7 → FPGA phase = 10 → Pulses when counter(6:3) = 10
**Emitter 1:** Phase = 12 → FPGA phase = 15 → Pulses when counter(6:3) = 15
**Emitter 2:** Phase = 0 → FPGA phase = 0 → Pulses when counter(6:3) = 0

**Time offset:**
- Emitter 0 pulses at counter = 10
- Emitter 1 pulses at counter = 15 (5 steps later = 800 ns later)
- Emitter 2 pulses at counter = 0 (6 steps earlier = 960 ns earlier)

**At 40 kHz:**
- Period = 25 μs
- Phase step = 25 μs / 16 = 1.5625 μs
- 5 steps = 7.8 μs phase delay
- This creates the interference pattern for the focal point!

---

## Part 7: Amplitude Modulation (Tactile Feedback)

### 7.1 AmpModulator - Low Frequency Modulation
**File:** `AmpModulator.vhd`

```vhdl
-- Generates slow clock for amplitude modulation
process (clk)
begin
    if rising_edge(clk) then
        if (s_stepCounter = steps) then
            s_stepCounter <= 0;
            chgClock <= '1';  -- Pulse
            s_counter <= s_counter + 1;  -- 0-255
        else
            s_stepCounter <= s_stepCounter + 1;
            chgClock <= '0';
        end if;
    end if;
end process;
```

**Timing:**
- `steps` = 10 (example)
- `chgClock` pulses every 10 clock cycles = 200 ns
- `s_counter` increments 0→255 in 256 pulses = 51.2 μs
- Modulation frequency = 1 / 51.2 μs = 19.5 kHz

**For tactile feedback (100 Hz):**
- Need slower modulation
- `steps` = 31 (maximum)
- `chgClock` period = 31 * 256 * 20ns = 158.7 μs
- Frequency = 6.3 kHz (still too fast!)

**Note:** The current implementation may need adjustment for proper tactile frequencies (1-200 Hz).

### 7.2 AllChannels - Synchronous Toggling
**File:** `AllChannels.vhd`

```vhdl
-- Toggle all emitters together
process (chgClock)
begin
    if rising_edge(chgClock) then
        for i in 0 to 255 loop
            s_enabled(i) <= NOT s_enabled(i);  -- Toggle
        end loop;
    end if;
end process;
```

**Effect:**
- All emitters turn ON/OFF together
- Creates pulsating focal point
- Can be felt as vibration/pressure

---

## Summary: Complete Signal Path

### Data Path (From Java - Phase Information)
```
Java: Physical Distance (100mm)
  ↓
Java: Phase Calculation (0.88 normalized)
  ↓
Java: Discretization (7)
  ↓
Serial: UART Transmission (254, 7, ...)
  ↓
FPGA Distribute: Processing (7 → 21)
  ↓
FPGA AllChannels: Bit Extraction (21 → phase=10)
  ↓
FPGA PhaseLine: Store phase=10 (wait for counter to match)
```

### Timing Path (FPGA Internal - Counter)
```
FPGA Masterclock: 50 MHz system clock
  ↓
FPGA Counter: 7-bit counter (0-127)
  ↓
FPGA AllChannels: Extract counter(6:3) → 0-15
  ↓
FPGA PhaseLine: Compare counter with stored phase
```

### Combined (Phase Matching → Output)
```
PhaseLine: When counter(6:3) = phase → Generate pulse
  ↓
PhaseLine: Pulse HIGH for 8 cycles (160 ns)
  ↓
Mux8: Time Multiplexing (8 emitters per pin)
  ↓
Transducer: Mechanical Resonance (40 kHz sine wave)
  ↓
Air: Acoustic Wave Propagation
  ↓
Focal Point: Constructive Interference
```

---

## Key Takeaways

1. **Phase in space → Phase in time:** Distance differences become timing differences
2. **16 discrete phases:** Limited resolution but sufficient for focal points
3. **Double buffering:** Smooth updates without glitches
4. **Bit manipulation:** Efficient hardware implementation using bit slicing
5. **Time multiplexing:** 256 emitters on 32 pins
6. **Mechanical resonance:** Transducer converts pulses to 40 kHz sine wave
7. **Amplitude modulation:** Optional pulsating for tactile feedback

---

## Troubleshooting Guide

### Issue: No output on emitters
- Check: Serial communication working?
- Check: Swap command sent after phase data?
- Check: `enabled` signal = 1?

### Issue: Wrong phase relationships
- Check: Phase correction values in Distribute.vhd
- Check: Bit extraction in AllChannels (5:1 and 6:3)
- Check: Counter running correctly

### Issue: Jitter on signals
- Check: Phase wrapping (mod 64 in Distribute)
- Check: Clock stability
- Check: Timing constraints met in FPGA

### Issue: No amplitude modulation
- Check: `ampModStep` value (0 = too fast, 31 = maximum)
- Check: `chgClock` signal pulsing
- Check: `s_enabled` toggling

---

**Document Version:** 1.0
**Date:** 2026-01-16
**Author:** Generated from code analysis
