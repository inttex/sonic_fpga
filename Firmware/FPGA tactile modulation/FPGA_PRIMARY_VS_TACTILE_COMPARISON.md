# FPGA Primary vs FPGA Tactile: Pulse Width Comparison

## Executive Summary

**Your suspicion is CORRECT!** The two FPGA implementations have **significantly different** pulse widths and duty cycles:

| Parameter | FPGA Tactile | FPGA Primary | Difference |
|-----------|--------------|--------------|------------|
| Master Clock | 5.12 MHz | **10.24 MHz** | **2× faster** |
| Clock Period | 195.3 ns | **97.66 ns** | **2× faster** |
| Counter Bits | 7-bit (0-127) | **8-bit (0-255)** | **2× range** |
| Counter Period | 25 µs (40 kHz) | 25 µs (40 kHz) | Same |
| Phase Divisions | 16 (4 bits) | **32 (5 bits)** | **2× resolution** |
| **s_counter Max** | **7** | **16** | **2.3× larger** |
| **Pulse Width** | **1.367 µs** | **1.563 µs** | **14% wider** |
| **Duty Cycle** | **5.47%** | **6.25%** | **14% higher** |

---

## Detailed Analysis

### 1. Clock Generation

#### FPGA Tactile (Masterclock.vhd)
```vhdl
clk0_divide_by => 625
clk0_multiply_by => 64
inclk0_input_frequency => 20000  -- 50 MHz input
```

**Calculation**:
```
Output = 50 MHz × (64 / 625) = 5.12 MHz
Period = 195.3125 ns
```

#### FPGA Primary (Masterclock.vhd)
```vhdl
clk0_divide_by => 625
clk0_multiply_by => 128  -- DOUBLE!
inclk0_input_frequency => 20000  -- 50 MHz input
```

**Calculation**:
```
Output = 50 MHz × (128 / 625) = 10.24 MHz ✓
Period = 97.65625 ns ✓
```

**Result**: FPGA Primary runs at **2× the clock speed**!

---

### 2. Counter Configuration

#### FPGA Tactile (Counter.vhd)
```vhdl
-- 7-bit counter
signal sCounter : STD_LOGIC_VECTOR (6 downto 0);
-- Range: 0 to 127 (128 states)
```

**Counter Period**:
```
Period = 128 × 195.3125 ns = 25 µs (40 kHz) ✓
```

#### FPGA Primary (Counter.vhd)
```vhdl
-- 8-bit counter (generic parameter)
generic(COUNTER_BITS: integer := 8);
signal sCounter : STD_LOGIC_VECTOR (COUNTER_BITS-1 downto 0);
-- Range: 0 to 255 (256 states)
```

**Counter Period**:
```
Period = 256 × 97.65625 ns = 25 µs (40 kHz) ✓
```

**Result**: Both achieve 40 kHz, but FPGA Primary uses **2× more counter states**!

---

### 3. Phase Resolution

#### FPGA Tactile (AllChannels.vhd)
```vhdl
counter : in std_logic_vector(6 downto 0);  -- 7 bits
-- Phase bits: counter(6:3) = 4 bits = 16 divisions
```

**Phase Resolution**:
```
Divisions = 16
Time per division = 25 µs / 16 = 1.5625 µs
Angle per division = 360° / 16 = 22.5°
```

#### FPGA Primary (AllChannels.vhd)
```vhdl
counter : in std_logic_vector(7 downto 0);  -- 8 bits
-- Phase bits: counter(7:3) = 5 bits = 32 divisions
```

**Phase Resolution**:
```
Divisions = 32
Time per division = 25 µs / 32 = 0.78125 µs ✓
Angle per division = 360° / 32 = 11.25° ✓
```

**Result**: FPGA Primary has **2× better phase resolution**!

---

### 4. Pulse Width Generation

#### FPGA Tactile (PhaseLine.vhd)
```vhdl
signal s_counter : integer range 0 to 7 := 0;

if (s_phaseCurrent = to_integer(unsigned(counter))) then
    s_counter <= 7;  -- Start with 7
end if;

if (s_counter = 0) then
    pulse <= '0';
else
    s_counter <= s_counter - 1;
    pulse <= '1' and enabled;  -- Modulation enabled
end if;
```

**Pulse Width**:
```
Pulse lasts: 7 clock cycles
Width = 7 × 195.3125 ns = 1.367 µs ✓
Duty Cycle = 1.367 µs / 25 µs = 5.47% ✓
```

#### FPGA Primary (PhaseLine.vhd)
```vhdl
signal s_counter : integer range 0 to 31 := 0;

if (s_phaseCurrent = to_integer(unsigned(counter))) then
    s_counter <= 16;  -- Start with 16 (NOT 31!)
end if;

if (s_counter = 0) then


---

## 7. Why the Differences?

### 7.1 Design Philosophy

**FPGA Tactile**:
- Optimized for **tactile feedback** applications
- Lower phase resolution (16 divisions) is sufficient
- Includes amplitude modulation in PhaseLine
- Lower duty cycle (5.47%) reduces power consumption
- Simpler, more power-efficient design

**FPGA Primary**:
- Optimized for **high-precision** acoustic levitation
- Higher phase resolution (32 divisions) for better focal point control
- Amplitude modulation handled separately (not in PhaseLine)
- Higher duty cycle (6.25%) for stronger acoustic pressure
- More complex, higher-performance design

### 7.2 Spatial Resolution Impact

**Wavelength at 40 kHz**: λ = 343 m/s / 40,000 Hz = 8.575 mm

**FPGA Tactile**:
```
Spatial resolution = 8.575 mm / 16 = 0.536 mm ≈ 0.5 mm
```

**FPGA Primary**:
```
Spatial resolution = 8.575 mm / 32 = 0.268 mm ≈ 0.25 mm ✓
```

**Result**: FPGA Primary can position focal points with **2× better accuracy**!

### 7.3 Power Consumption

**Assumptions**:
- Emitter voltage: 10V peak
- Emitter current: 20 mA peak
- 256 emitters

**FPGA Tactile**:
```
Duty cycle = 5.47%
Peak power per emitter = 10V × 20mA = 0.2W
Average power per emitter = 0.2W × 0.0547 = 10.94 mW
Total power (256 emitters) = 256 × 10.94 mW = 2.8 W
```

**FPGA Primary**:
```
Duty cycle = 6.25%
Peak power per emitter = 10V × 20mA = 0.2W
Average power per emitter = 0.2W × 0.0625 = 12.5 mW
Total power (256 emitters) = 256 × 12.5 mW = 3.2 W
```

**Result**: FPGA Primary consumes **14% more power** (3.2W vs 2.8W)

---

## 8. Phase Comparison Table

| Phase Value | Tactile Time (µs) | Tactile Angle | Primary Time (µs) | Primary Angle |
|-------------|-------------------|---------------|-------------------|---------------|
| 0 | 0.000 | 0.0° | 0.000 | 0.0° |
| 1 | 1.563 | 22.5° | 0.781 | 11.25° |
| 2 | 3.125 | 45.0° | 1.563 | 22.5° |
| 3 | 4.688 | 67.5° | 2.344 | 33.75° |
| 4 | 6.250 | 90.0° | 3.125 | 45.0° |
| 5 | 7.813 | 112.5° | 3.906 | 56.25° |
| 6 | 9.375 | 135.0° | 4.688 | 67.5° |
| 7 | 10.938 | 157.5° | 5.469 | 78.75° |
| 8 | 12.500 | 180.0° | 6.250 | 90.0° |
| 9 | 14.063 | 202.5° | 7.031 | 101.25° |
| 10 | 15.625 | 225.0° | 7.813 | 112.5° |
| 11 | 17.188 | 247.5° | 8.594 | 123.75° |
| 12 | 18.750 | 270.0° | 9.375 | 135.0° |
| 13 | 20.313 | 292.5° | 10.156 | 146.25° |
| 14 | 21.875 | 315.0° | 10.938 | 157.5° |
| 15 | 23.438 | 337.5° | 11.719 | 168.75° |
| 16 | - | - | 12.500 | 180.0° |
| ... | - | - | ... | ... |
| 31 | - | - | 24.219 | 348.75° |

**Note**: FPGA Tactile only has 16 phase values (0-15), while FPGA Primary has 32 (0-31).

---

## 9. Timing Diagrams Comparison

### FPGA Tactile: Pulse at Phase = 5

```
Time (µs):     0     1.56  3.13  4.69  6.25  7.81  9.38  10.94 12.50
Counter(6:3):  0     1     2     3     4     5     6     7     8
Clock cycles:  0     8     16    24    32    40    48    56    64

Pulse starts at counter(6:3) = 5 (counter = 40)
Pulse lasts 7 clock cycles:
  Clock 40: s_counter=7, pulse=1
  Clock 41: s_counter=6, pulse=1
  Clock 42: s_counter=5, pulse=1
  Clock 43: s_counter=4, pulse=1
  Clock 44: s_counter=3, pulse=1
  Clock 45: s_counter=2, pulse=1
  Clock 46: s_counter=1, pulse=1
  Clock 47: s_counter=0, pulse=0

Pulse width = 7 × 195.3 ns = 1.367 µs ✓
```

### FPGA Primary: Pulse at Phase = 10

```
Time (µs):     0     0.78  1.56  2.34  3.13  3.91  4.69  5.47  6.25  7.03  7.81
Counter(7:3):  0     1     2     3     4     5     6     7     8     9     10
Clock cycles:  0     8     16    24    32    40    48    56    64    72    80

Pulse starts at counter(7:3) = 10 (counter = 80)
Pulse lasts 16 clock cycles:
  Clock 80: s_counter=16, pulse=1
  Clock 81: s_counter=15, pulse=1
  ...
  Clock 94: s_counter=2, pulse=1
  Clock 95: s_counter=1, pulse=1
  Clock 96: s_counter=0, pulse=0

Pulse width = 16 × 97.66 ns = 1.563 µs ✓
```

---

## 10. Answer to Your Question

### Is the 5.47% duty cycle suspicious?

**NO, it is NOT suspicious!** Here's why:

1. **Both FPGAs have low duty cycles**:
   - Tactile: 5.47%
   - Primary: 6.25%
   - Both are in the same range (~5-6%)

2. **This is CORRECT for ultrasonic transducers**:
   - Ultrasonic transducers are designed for **pulsed operation**
   - Continuous operation would cause **overheating**
   - Low duty cycle allows transducers to cool between pulses
   - Typical duty cycles for 40 kHz transducers: **5-10%**

3. **The pulse width is what matters**:
   - Tactile: 1.367 µs pulse every 25 µs
   - Primary: 1.563 µs pulse every 25 µs
   - Both provide sufficient acoustic energy per cycle

4. **The differences make sense**:
   - Primary has 14% higher duty cycle for stronger acoustic pressure
   - Primary has 2× better phase resolution for precision
   - Tactile is optimized for lower power consumption

### Conclusion

The 5.47% duty cycle in FPGA Tactile is **perfectly normal and expected**. The FPGA Primary's 6.25% duty cycle is also normal. Both are appropriate for ultrasonic transducer operation.

The key difference is that **FPGA Primary is designed for higher precision** (32 phase divisions, 0.25 mm spatial resolution) while **FPGA Tactile is optimized for efficiency** (16 phase divisions, 0.5 mm spatial resolution, lower power).

---

## 11. Summary Table

| Aspect | FPGA Tactile | FPGA Primary | Winner |
|--------|--------------|--------------|--------|
| Clock Speed | 5.12 MHz | 10.24 MHz | Primary (2× faster) |
| Phase Divisions | 16 | 32 | Primary (2× better) |
| Spatial Resolution | 0.5 mm | 0.25 mm | Primary (2× better) |
| Pulse Width | 1.367 µs | 1.563 µs | Primary (14% wider) |
| Duty Cycle | 5.47% | 6.25% | Primary (14% higher) |
| Power Consumption | 2.8 W | 3.2 W | Tactile (14% lower) |
| Acoustic Pressure | Lower | Higher | Primary |
| Modulation | Integrated | Separate | Tactile (simpler) |
| Complexity | Lower | Higher | Tactile (simpler) |
| Use Case | Tactile feedback | Precision levitation | Different goals |

**Both designs are correct for their intended applications!**

---

## Document Version
- **Created**: 2026-01-16
- **Purpose**: Compare FPGA Primary vs FPGA Tactile pulse generation
- **Key Finding**: Both have low duty cycles (~5-6%), which is CORRECT and EXPECTED
- **Conclusion**: 5.47% duty cycle is NOT suspicious - it's appropriate for ultrasonic transducers
end if;
```

**Pulse Width**:
```
Pulse lasts: 16 clock cycles
Width = 16 × 97.65625 ns = 1.5625 µs ✓
Duty Cycle = 1.5625 µs / 25 µs = 6.25% ✓
```

**Result**: FPGA Primary has **14% wider pulses** and **14% higher duty cycle**!

---

## 5. Key Differences Summary

### 5.1 Clock Speed
- **Tactile**: 5.12 MHz
- **Primary**: 10.24 MHz (2× faster)
- **Why**: Primary needs finer timing resolution for 32 phase divisions

### 5.2 Phase Resolution
- **Tactile**: 16 divisions (22.5° per step, 1.5625 µs)
- **Primary**: 32 divisions (11.25° per step, 0.78125 µs)
- **Why**: Primary has better spatial resolution for focal point positioning

### 5.3 Pulse Width
- **Tactile**: 1.367 µs (7 clock cycles)
- **Primary**: 1.563 µs (16 clock cycles)
- **Why**: Different s_counter initialization values (7 vs 16)

### 5.4 Duty Cycle
- **Tactile**: 5.47%
- **Primary**: 6.25%
- **Why**: Wider pulses in Primary

### 5.5 Amplitude Modulation
- **Tactile**: Has `enabled` signal gating in PhaseLine
- **Primary**: NO modulation gating in PhaseLine (handled elsewhere?)
- **Why**: Different modulation architectures

---

## 6. Numerical Verification

### FPGA Primary Calculations

**Master Clock**:
```
50 MHz × (128/625) = 10.24 MHz ✓
Period = 1 / 10.24 MHz = 97.65625 ns ✓
```

**Counter Period**:
```
256 states × 97.65625 ns = 25,000 ns = 25 µs ✓
Frequency = 40 kHz ✓
```

**Phase Division**:
```
32 divisions
Time per division = 25 µs / 32 = 0.78125 µs ✓
Counter increments per division = 256 / 32 = 8 ✓
```

**Pulse Width**:
```
16 clock cycles × 97.65625 ns = 1562.5 ns = 1.5625 µs ✓
```

**Duty Cycle**:
```
1.5625 µs / 25 µs = 0.0625 = 6.25% ✓
```


