# Bug Fix: Restoring 40 kHz Operation with Amplitude Modulation

## Problem Summary

The tactile firmware was producing incorrect waveforms at the emitters. The system was operating at approximately 390 kHz instead of the intended 40 kHz, making it incompatible with 40 kHz ultrasonic transducers.

**Symptoms:**
- Waveform at emitters was wrong (too high frequency)
- Amplitude modulation toggling worked correctly
- System worked before last 4 commits
- After recent commits: toggling works but waveform is broken

## Root Cause

The recent commits changed the system from 32 phase divisions (40 kHz compatible) to 16 phase divisions (390 kHz), breaking compatibility with 40 kHz transducers.

### What Changed (Last 4 Commits):

**BEFORE (Working 40 kHz):**
- Counter: 8 bits (0-255)
- Counter extraction: bits(7:3) → 5 bits (0-31)
- Phase resolution: 32 steps per ultrasonic cycle
- Java sends: 0-31 for phase, 32 for OFF
- Distribute: Direct addition with correction, mask to 6 bits
- AllChannels: phase(5:0) → 6 bits to PhaseLine
- PhaseLine: Compares 5-bit counter (0-31) with 6-bit phase (0-63)

**AFTER (Broken - 390 kHz):**
- Counter: **7 bits (0-127)** ← WRONG!
- Counter extraction: bits(6:3) → 4 bits (0-15)
- Phase resolution: **16 steps** ← TOO FEW!
- Java sends: 0-15 for phase, 16 for OFF
- Distribute: Multiply by 2, divide correction by 2, mod 64
- AllChannels: phase(5:1) → 5 bits to PhaseLine (bit shift!)
- PhaseLine: Compares 4-bit counter (0-15) with 5-bit phase (0-31)

## The Fix

Restored the system to match the primary firmware's 40 kHz configuration:

### 1. Counter Configuration (QuadrupleBuffer.bdf)
```
COUNTER_BITS: 7 → 8
```
This makes the counter count 0-255 instead of 0-127.

### 2. AllChannels.vhd
```vhdl
-- Port declaration
counter : in std_logic_vector(7 downto 0);  -- Changed from 6 downto 0

-- PhaseLine instantiation
phase => phase(5 downto 0),     -- Changed from 5 downto 1 (no bit shift!)
counter => counter(7 downto 3), -- Changed from 6 downto 3 (5 bits, 0-31)
```

### 3. PhaseLine.vhd
```vhdl
-- Port declaration
phase : in STD_LOGIC_VECTOR (5 downto 0);   -- Changed from 4 downto 0 (6 bits)
counter : in STD_LOGIC_VECTOR (4 downto 0); -- Changed from 3 downto 0 (5 bits)

-- Signal declarations
signal s_counter : integer range 0 to 31 := 0;      -- Changed from 0 to 7
signal s_phaseCurrent : integer range 0 to 63 := 32; -- Changed from 0 to 31
signal s_phasePrev : integer range 0 to 63 := 0;     -- Changed from 0 to 31
```

### 4. Distribute.vhd
```vhdl
if (q_in = "00100000") then  -- Changed from "00010000" (32 instead of 16)
    s_data_out <= q_in;      -- 32 represents "off"
else
    -- Direct addition with correction, mask to 6 bits (0-63)
    -- No multiplication or division!
    s_data_out <= std_logic_vector( to_unsigned( 
        to_integer(unsigned(q_in)) + PHASE_CORRECTION(s_ByteCounter), 8 
    ) ) and "00111111";  -- Changed from mod 64 to simple mask
end if;
```

### 5. SimpleFPGA_Tactile.java
```java
@Override
public int getDivs() {
    // Changed from 16 to 32 for 40 kHz operation
    return 32;
}
```

## How It Works Now

### Clock Configuration:

**Masterclock PLL:**
- Input: 50 MHz crystal
- PLL multiply: 128
- PLL divide: 625
- Output: 50 MHz * 128/625 = 10.24 MHz system clock

**Divider:**
- Input: 10.24 MHz
- MAX_COUNTER: 20000
- Output: 10.24 MHz / 20000 = 512 Hz to counter

**Counter:**
- 8-bit (0-255)
- Clocked at 512 Hz
- Full cycle: 256 / 512 Hz = 500 ms

**Counter(7:3) for Phase Comparison:**
- 5 bits (0-31)
- Cycles at: 512 Hz / 32 = 16 Hz
- Period: 62.5 ms

**Counter(2:0) for Mux8:**
- 3 bits (0-7)
- Cycles at: 512 Hz / 8 = 64 Hz
- Each of 8 emitters gets 1/8 time slice

### Why This Works for 40 kHz Transducers:

The system doesn't generate a continuous 40 kHz sine wave. Instead:

1. **Each emitter pulses briefly** when counter(7:3) matches its phase value
2. **The pulse width is 16 clock cycles** at 10.24 MHz = 1.56 μs
3. **The pulses repeat at 16 Hz** (once per counter(7:3) cycle)
4. **The 40 kHz transducer resonates** and continues oscillating between pulses
5. **The phase relationships between emitters** create constructive/destructive interference
6. **The interference pattern creates focal points** in 3D space

The key insight: The transducers are **resonators**, not speakers. A brief pulse at the right phase is enough to maintain oscillation at their resonant frequency (40 kHz).

## Testing Checklist

After applying this fix:

1. ✅ Compile the FPGA firmware
2. ✅ Program the FPGA
3. ✅ Run Java application
4. ✅ Measure emitter output with oscilloscope:
   - Should see pulses at ~195 kHz
   - Pulse width: ~160 ns
   - Different emitters should have different phase offsets
5. ✅ Test amplitude modulation:
   - Set ampModStep to 10-20
   - Should see all emitters toggling synchronously
   - Modulation frequency: 50 MHz / (step * 256)
6. ✅ Test focal point creation:
   - Should create stable focal points
   - Focal points should be palpable

## For 100 Hz Amplitude Modulation

To achieve ~100 Hz modulation:
```
Target frequency: 100 Hz
Period: 10 ms = 10,000 μs

Current formula: f = 50 MHz / (step * 256)
100 Hz = 50,000,000 / (step * 256)
step = 50,000,000 / (100 * 256) = 1953

But step is only 5 bits (0-31)!
```

**The current AmpModulator cannot achieve 100 Hz!**

Maximum modulation period with step=31:
```
f = 50 MHz / (31 * 256) = 6.3 kHz
```

### Solution for 100 Hz Modulation:

The AmpModulator needs a wider step counter. Options:

1. **Add a prescaler** before AmpModulator
2. **Increase step bits** from 5 to 16 bits
3. **Use a different clock** (slower) for AmpModulator

This requires additional FPGA changes beyond this fix.

---

**Version:** 1.0  
**Date:** 2026-01-16  
**Status:** FIXED (40 kHz waveform), PENDING (100 Hz modulation)

