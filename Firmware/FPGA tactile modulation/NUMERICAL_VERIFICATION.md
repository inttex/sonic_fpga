# Numerical Verification: Phase Shifts and Frequencies

This document provides detailed numerical examples to verify all timing calculations, phase shifts, and frequencies in the FPGA tactile modulation system.

---

## Table of Contents
1. [Clock and Counter Verification](#1-clock-and-counter-verification)
2. [Phase Shift Calculations](#2-phase-shift-calculations)
3. [Pulse Timing Verification](#3-pulse-timing-verification)
4. [Modulation Frequency Verification](#4-modulation-frequency-verification)
5. [Complete System Example](#5-complete-system-example)
6. [Wavelength and Spatial Resolution](#6-wavelength-and-spatial-resolution)

---

## 1. Clock and Counter Verification

### 1.1 PLL Clock Generation

**Input**: 50 MHz crystal oscillator

**PLL Configuration** (from Masterclock.vhd):
```
Divide by:  625
Multiply by: 64
```

**Calculation**:
```
Output Frequency = Input × (Multiply / Divide)
                 = 50 MHz × (64 / 625)
                 = 50,000,000 Hz × 0.1024
                 = 5,120,000 Hz
                 = 5.12 MHz ✓
```

**Clock Period**:
```
Period = 1 / Frequency
       = 1 / 5,120,000 Hz
       = 0.0000001953125 seconds
       = 195.3125 ns
       ≈ 195.3 ns ✓
```

### 1.2 Counter Full Cycle (40 kHz Generation)

**Counter**: 7-bit (0 to 127) = 128 states

**Counter Period**:
```
Period = Counter States × Clock Period
       = 128 × 195.3125 ns
       = 25,000 ns
       = 25 µs ✓
```

**Counter Frequency**:
```
Frequency = 1 / Period
          = 1 / 25 µs
          = 1 / 0.000025 s
          = 40,000 Hz
          = 40 kHz ✓ (Ultrasonic carrier frequency)
```

### 1.3 Phase Division Timing

**Phase Bits**: counter(6:3) = 4 bits = 16 divisions (0-15)

**Time per Division**:
```
Time per Division = Counter Period / Number of Divisions
                  = 25 µs / 16
                  = 1.5625 µs ✓
```

**Phase Division Frequency**:
```
Frequency = 1 / Time per Division
          = 1 / 1.5625 µs
          = 640,000 Hz
          = 640 kHz
```

**Verification - Counter increments per division**:
```
Counter increments per division = 128 / 16 = 8 increments
Time = 8 × 195.3125 ns = 1562.5 ns = 1.5625 µs ✓
```

---

## 2. Phase Shift Calculations

### 2.1 Phase to Time Conversion

For a 40 kHz signal (25 µs period), each phase division represents:

| Phase Value | Time Delay (µs) | Time Delay (ns) | Phase Angle (degrees) | Phase Angle (radians) |
|-------------|-----------------|-----------------|----------------------|----------------------|
| 0 | 0.0000 | 0 | 0° | 0.000 |
| 1 | 1.5625 | 1562.5 | 22.5° | 0.393 |
| 2 | 3.1250 | 3125.0 | 45.0° | 0.785 |
| 3 | 4.6875 | 4687.5 | 67.5° | 1.178 |
| 4 | 6.2500 | 6250.0 | 90.0° | 1.571 |
| 5 | 7.8125 | 7812.5 | 112.5° | 1.963 |
| 6 | 9.3750 | 9375.0 | 135.0° | 2.356 |
| 7 | 10.9375 | 10937.5 | 157.5° | 2.749 |
| 8 | 12.5000 | 12500.0 | 180.0° | 3.142 |
| 9 | 14.0625 | 14062.5 | 202.5° | 3.534 |
| 10 | 15.6250 | 15625.0 | 225.0° | 3.927 |
| 11 | 17.1875 | 17187.5 | 247.5° | 4.320 |
| 12 | 18.7500 | 18750.0 | 270.0° | 4.712 |
| 13 | 20.3125 | 20312.5 | 292.5° | 5.105 |
| 14 | 21.8750 | 21875.0 | 315.0° | 5.498 |
| 15 | 23.4375 | 23437.5 | 337.5° | 5.890 |

**Formula**:
```
Time Delay (µs) = Phase × (25 µs / 16)
                = Phase × 1.5625 µs

Phase Angle (°) = Phase × (360° / 16)
                = Phase × 22.5°

Phase Angle (rad) = Phase × (2π / 16)
                  = Phase × 0.3927 rad
```

### 2.2 Example: Phase = 5

**Time Delay**:
```
Time = 5 × 1.5625 µs = 7.8125 µs
```

**Phase Angle**:
```
Angle = 5 × 22.5° = 112.5°
      = 5 × 0.3927 rad = 1.963 rad
```

**Verification - Counter value when pulse starts**:
```
Counter(6:3) = 5 means counter is in range [40, 47]
Counter = 40 to 47 (8 values)
Time = 40 × 195.3125 ns = 7812.5 ns = 7.8125 µs ✓
```

### 2.3 Example: Two Emitters Creating Interference

**Emitter A**: Phase = 0 (0°)
**Emitter B**: Phase = 8 (180°)

**Time difference**:
```
ΔT = (8 - 0) × 1.5625 µs = 12.5 µs
```

**Phase difference**:
```
Δφ = (8 - 0) × 22.5° = 180°
```

**Physical interpretation**:
- Emitter A starts at t = 0 µs
- Emitter B starts at t = 12.5 µs
- This is exactly half a period (25 µs / 2 = 12.5 µs)
- **Result**: Destructive interference (waves cancel out) ✓

---

## 3. Pulse Timing Verification

### 3.1 Pulse Width Calculation

**From PhaseLine.vhd**:
```vhdl
signal s_counter : integer range 0 to 7 := 0;

if (s_phaseCurrent = to_integer(unsigned(counter))) then
    s_counter <= 7;  -- Start pulse
end if;

if (s_counter = 0) then
    pulse <= '0';
else
    s_counter <= s_counter - 1;  -- Decrement every clock cycle
    pulse <= '1' and enabled;
end if;
```

**Analysis**:
- `s_counter` is set to 7 when phase matches
- `s_counter` decrements on **every master clock cycle** (5.12 MHz)
- Pulse stays high while `s_counter > 0`

**Pulse Width** (in clock cycles):
```
Pulse lasts for: 7 clock cycles (values 7, 6, 5, 4, 3, 2, 1)
Width = 7 × Clock Period
      = 7 × 195.3125 ns
      = 1367.1875 ns
      ≈ 1.367 µs ✓
```

**This is the CORRECT pulse width!**

### 3.2 Duty Cycle Calculation

**Pulse ON time**: 1.367 µs
**Period**: 25 µs

**Duty Cycle**:
```
Duty Cycle = (ON time / Period) × 100%
           = (1.367 µs / 25 µs) × 100%
           = 0.0547 × 100%
           = 5.47% ✓
```

**Note**: This is a very low duty cycle, which is typical for ultrasonic transducers to prevent overheating.

### 3.3 Example: Pulse at Phase = 3

**Pulse starts when**: counter(6:3) = 3
```
Start time = 3 × 1.5625 µs = 4.6875 µs
```

**Pulse lasts for**: 7 clock cycles
```
Duration = 7 × 195.3125 ns = 1.367 µs
End time = 4.6875 µs + 1.367 µs = 6.055 µs
```

**Timeline** (showing clock cycles):
```
Time (µs):     4.688  4.883  5.078  5.273  5.469  5.664  5.859  6.055
Clock cycles:  24     25     26     27     28     29     30     31
s_counter:     7      6      5      4      3      2      1      0
Pulse:         1      1      1      1      1      1      1      0
               ████████████████████████████████████████████░░░░
               └────────── 1.367 µs ──────────┘
```

**Verification**:
```
Counter value when phase=3: counter(6:3) = 3
This means counter = 24-31 (binary: 011xxx)
Pulse starts at counter = 24
Pulse ends at counter = 31
Duration = 7 clock cycles ✓
```

---

## 4. Modulation Frequency Verification

### 4.1 chgClock Generation

**From AmpModulator.vhd**: chgClock pulses every `steps` clock cycles

**Formula**:
```
chgClock Period = steps × Clock Period
                = steps × 195.3125 ns

chgClock Frequency = 1 / (steps × 195.3125 ns)
                   = 5,120,000 Hz / steps
                   = 5.12 MHz / steps
```

### 4.2 Example Calculations

| steps | chgClock Period | chgClock Frequency | Calculation |
|-------|-----------------|-------------------|-------------|
| 10 | 1.953 µs | 512 kHz | 10 × 195.3 ns |
| 20 | 3.906 µs | 256 kHz | 20 × 195.3 ns |
| 100 | 19.53 µs | 51.2 kHz | 100 × 195.3 ns |
| 200 | 39.06 µs | 25.6 kHz | 200 × 195.3 ns |
| 256 | 50.00 µs | 20 kHz | 256 × 195.3 ns |
| 512 | 100.0 µs | 10 kHz | 512 × 195.3 ns |

### 4.3 Tactile Modulation Frequency

**From AllChannels.vhd**: The `s_enabled` signal is a 256-bit vector, and only ONE emitter toggles per chgClock pulse.

**For a single emitter**:
```
Toggle period = 256 × chgClock Period

Tactile Frequency = chgClock Frequency / 256
                  = (5.12 MHz / steps) / 256
                  = 5.12 MHz / (steps × 256)
                  = 20,000 Hz / steps
```

**Simplified Formula**:
```
Tactile Frequency (Hz) = 20,000 / steps

For 100 Hz tactile: steps = 20,000 / 100 = 200
For 200 Hz tactile: steps = 20,000 / 200 = 100
For 50 Hz tactile:  steps = 20,000 / 50 = 400
```

### 4.4 Verification Table: Modulation Frequencies

| steps | chgClock Freq | chgClock Period | Tactile Freq | Tactile Period | Use Case |
|-------|---------------|-----------------|--------------|----------------|----------|
| 10 | 512 kHz | 1.95 µs | 2000 Hz | 500 µs | Too fast |
| 50 | 102.4 kHz | 9.77 µs | 400 Hz | 2.5 ms | High freq tactile |
| 100 | 51.2 kHz | 19.5 µs | 200 Hz | 5 ms | **Optimal tactile** |
| 200 | 25.6 kHz | 39.1 µs | 100 Hz | 10 ms | **Optimal tactile** |
| 256 | 20 kHz | 50 µs | 78 Hz | 12.8 ms | Low freq tactile |
| 400 | 12.8 kHz | 78.1 µs | 50 Hz | 20 ms | Very low tactile |
| 512 | 10 kHz | 100 µs | 39 Hz | 25.6 ms | Threshold |

**Human tactile perception range**: ~20-1000 Hz, optimal ~50-300 Hz ✓

---

## 5. Complete System Example

### 5.1 Scenario: Two-Emitter Focal Point with 100 Hz Modulation

**Goal**: Create a focal point using 2 emitters with 45° phase difference, modulated at 100 Hz for tactile feedback.

#### Step 1: Java Calculates Phases

**Emitter #0**:
- Position: (0, 0, 0)
- Target focal point: (0, 0, 100 mm)
- Calculated phase: 0 (reference)

**Emitter #1**:
- Position: (10 mm, 0, 0)
- Target focal point: (0, 0, 100 mm)
- Path difference: ~0.5 mm
- Wavelength at 40 kHz: λ = c/f = 343 m/s / 40,000 Hz = 8.575 mm
- Phase shift: (0.5 mm / 8.575 mm) × 16 = 0.93 ≈ 1 division
- Calculated phase: 1

**Java sends**:
```
Serial packet: [254][0][1][0][0]...[0]
               └─┘ └┘ └┘
               CMD E0 E1
```

#### Step 2: FPGA Receives and Applies Calibration

**UARTReader** receives bytes at 115200 baud:
```
Byte time = 10 bits / 115200 = 86.8 µs per byte
Total packet time = 257 bytes × 86.8 µs = 22.3 ms
```

**Distribute Module** applies calibration:
```
Emitter #0:
  Java phase = 0
  PHASE_CORRECTION[0] = 11 (from calibration array)
  FPGA phase = (0 + 11) & 0x1F = 11

Emitter #1:
  Java phase = 1
  PHASE_CORRECTION[1] = 5 (from calibration array)
  FPGA phase = (1 + 5) & 0x1F = 6
```

#### Step 3: AllChannels Extracts Phase Bits

**Emitter #0**:
```
phase = 11 = 0b01011
phase(5:1) = 0b0101 = 5
```

**Emitter #1**:
```
phase = 6 = 0b00110
phase(5:1) = 0b0011 = 3
```

#### Step 4: PhaseLine Generates Pulses

**Counter timeline** (one 40 kHz cycle):

```
Time (µs):     0     1.56  3.13  4.69  6.25  7.81  9.38  10.94 12.50 14.06 15.63
Counter(6:3):  0     1     2     3     4     5     6     7     8     9     10

Emitter #0 (phase=5):
Pulse:         0     0     0     0     0     1     1     1     1     1     1
               ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████████████████████████
               Start at 7.81 µs ──────────────────┘ (lasts 1.367 µs)

Emitter #1 (phase=3):
Pulse:         0     0     0     1     1     1     1     1     1     1     0
               ░░░░░░░░░░░░░░░░░░████████████████████████████░░░░░░░░░░░░░░░░
               Start at 4.69 µs ──────┘ (lasts 1.367 µs)
```

**Phase difference**:
```
Δt = 7.81 µs - 4.69 µs = 3.12 µs
Δφ = (3.12 µs / 25 µs) × 360° = 45°
```

**Verification**:
```
Phase difference = (5 - 3) × 22.5° = 2 × 22.5° = 45° ✓
```

#### Step 5: Amplitude Modulation at 100 Hz

**Required steps value**:
```
steps = 20,000 / 100 Hz = 200
```

**chgClock timing**:
```
chgClock period = 200 × 195.3125 ns = 39,062.5 ns ≈ 39.06 µs
chgClock frequency = 25.6 kHz
```

**Emitter toggle timing**:
```
Each emitter toggles every: 256 × 39.06 µs = 10 ms
Toggle frequency: 100 Hz ✓
```

**Timeline over 30 ms**:
```
Time (ms):     0    5    10   15   20   25   30
               ├────┼────┼────┼────┼────┼────┤

s_enabled[0]:  1111111111000000000011111111110000000000111111
               ON────────OFF────────ON────────OFF────────ON──
               └──────────── 100 Hz (10 ms period) ──────────┘

s_enabled[1]:  1111111111000000000011111111110000000000111111
               ON────────OFF────────ON────────OFF────────ON──
```

**40 kHz output with modulation**:
```
When s_enabled = 1:
  Emitter outputs 40 kHz pulses (25 µs period, 1.367 µs pulse width)

When s_enabled = 0:
  Emitter is silent

Result:
  User feels 100 Hz vibration at the focal point! ✓
```

---

## 6. Wavelength and Spatial Resolution

### 6.1 Ultrasound Wavelength

**Speed of sound in air**: c = 343 m/s (at 20°C)
**Frequency**: f = 40 kHz

**Wavelength**:
```
λ = c / f
  = 343 m/s / 40,000 Hz
  = 0.008575 m
  = 8.575 mm ✓
```

### 6.2 Spatial Resolution per Phase Division

**Phase resolution**: 16 divisions per wavelength

**Spatial resolution**:
```
Δx = λ / 16
   = 8.575 mm / 16
   = 0.536 mm
   ≈ 0.5 mm ✓
```

**This means**: Each phase division corresponds to approximately 0.5 mm of path difference.

### 6.3 Example: Focal Point Positioning Accuracy

**If we want to move a focal point by 1 mm**:
```
Phase change needed = 1 mm / 0.536 mm = 1.87 ≈ 2 divisions
```

**If we want to move a focal point by 5 mm**:
```
Phase change needed = 5 mm / 0.536 mm = 9.33 ≈ 9 divisions
```

**Maximum path difference** (phase 0 to 15):
```
Max path diff = 15 × 0.536 mm = 8.04 mm ≈ λ ✓
```

---

## 7. Summary of Verified Values

| Parameter | Calculated Value | Verification |
|-----------|------------------|--------------|
| Master Clock | 5.12 MHz | ✓ (50 MHz × 64/625) |
| Clock Period | 195.3125 ns | ✓ (1 / 5.12 MHz) |
| Counter Period | 25 µs | ✓ (128 × 195.3 ns) |
| Ultrasonic Freq | 40 kHz | ✓ (1 / 25 µs) |
| Phase Divisions | 16 | ✓ (4 bits) |
| Time per Division | 1.5625 µs | ✓ (25 µs / 16) |
| Angle per Division | 22.5° | ✓ (360° / 16) |
| **Pulse Width** | **1.367 µs** | **✓ (7 × 195.3 ns)** |
| **Duty Cycle** | **5.47%** | **✓ (1.367 / 25)** |
| Wavelength | 8.575 mm | ✓ (343 m/s / 40 kHz) |
| Spatial Resolution | 0.536 mm | ✓ (8.575 mm / 16) |
| Tactile Freq (steps=200) | 100 Hz | ✓ (20 kHz / 200) |
| Tactile Freq (steps=100) | 200 Hz | ✓ (20 kHz / 100) |

**All calculations verified!** ✓

---

## 8. Key Findings

### 8.1 Corrected Pulse Width
The pulse width is **1.367 µs** (7 clock cycles at 5.12 MHz), NOT 10.9 µs as might be assumed from the counter value of 7.

### 8.2 Low Duty Cycle
The duty cycle is only **5.47%**, which is appropriate for ultrasonic transducers to:
- Prevent overheating
- Reduce power consumption
- Maintain transducer longevity

### 8.3 Tactile Modulation Formula
For tactile feedback at frequency F (Hz):
```
steps = 20,000 / F

Examples:
  50 Hz  → steps = 400
  100 Hz → steps = 200
  200 Hz → steps = 100
```

### 8.4 Spatial Resolution
With 16 phase divisions, the system can position focal points with approximately **0.5 mm** resolution.

---

## Document Version
- **Created**: 2026-01-16
- **Purpose**: Numerical verification of phase shifts and frequencies
- **System**: FPGA Tactile Modulation Firmware
- **Key Correction**: Pulse width is 1.367 µs (7 clock cycles), not 10.9 µs




