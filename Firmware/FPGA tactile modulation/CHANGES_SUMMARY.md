# Summary of Changes to Fix 40 kHz Operation

## Date: 2026-01-16

## Problem
The tactile firmware was producing incorrect waveforms after recent commits. The system was operating at approximately 390 kHz instead of being compatible with 40 kHz ultrasonic transducers.

## Root Causes

### 1. Clock Speed (CRITICAL)
**Masterclock.vhd** - PLL multiplier was set to 64 instead of 128
- **Before:** 50 MHz * 64/625 = 5.12 MHz system clock
- **After:** 50 MHz * 128/625 = 10.24 MHz system clock
- **Impact:** System was running at HALF speed

### 2. Counter Bit Width
**QuadrupleBuffer.bdf** - Counter was 7-bit instead of 8-bit
- **Before:** COUNTER_BITS = 7 (counts 0-127)
- **After:** COUNTER_BITS = 8 (counts 0-255)
- **Impact:** Only 16 phase steps instead of 32

### 3. Phase Bit Extraction
**AllChannels.vhd** - Wrong bits extracted from counter and phase
- **Before:** counter(6:3) → 4 bits, phase(5:1) → 5 bits
- **After:** counter(7:3) → 5 bits, phase(5:0) → 6 bits
- **Impact:** Reduced phase resolution

### 4. Phase Processing
**Distribute.vhd** - Incorrect phase calculation
- **Before:** Multiply by 2, divide correction by 2, mod 64
- **After:** Direct addition with correction, mask to 6 bits
- **Impact:** Wrong phase values sent to emitters

### 5. Java Phase Divisions
**SimpleFPGA_Tactile.java** - Wrong number of phase divisions
- **Before:** getDivs() = 16
- **After:** getDivs() = 32
- **Impact:** Java was sending wrong phase resolution

## Files Changed

### FPGA Firmware (firmware/FPGA tactile modulation/src/)

1. **Masterclock.vhd**
   - Line 138: `clk0_multiply_by => 128` (was 64)

2. **QuadrupleBuffer.bdf**
   - Line 445: `"COUNTER_BITS" "8"` (was "7")

3. **AllChannels.vhd**
   - Line 12: `counter : in std_logic_vector(7 downto 0)` (was 6 downto 0)
   - Line 74: `phase => phase(5 downto 0)` (was 5 downto 1)
   - Line 75: `counter => counter(7 downto 3)` (was 6 downto 3)

4. **PhaseLine.vhd**
   - Line 11: `phase : in STD_LOGIC_VECTOR (5 downto 0)` (was 4 downto 0)
   - Line 12: `counter : in STD_LOGIC_VECTOR (4 downto 0)` (was 3 downto 0)
   - Line 19: `signal s_counter : integer range 0 to 31` (was 0 to 7)
   - Line 20: `signal s_phaseCurrent : integer range 0 to 63` (was 0 to 31)
   - Line 21: `signal s_phasePrev : integer range 0 to 63` (was 0 to 31)

5. **Distribute.vhd**
   - Line 59: `if (q_in = "00100000") then` (was "00010000")
   - Line 62: `s_data_out <= q_in;` (was "00100000")
   - Line 66: Simplified calculation, removed multiply/divide/mod

### Java Software (Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/protocols/)

6. **SimpleFPGA_Tactile.java**
   - Line 51: `return 32;` (was 16)

## Testing Required

After programming the FPGA with these changes:

1. **Compile and Program:**
   - Open Quartus II
   - Compile the project
   - Program the FPGA

2. **Test Basic Operation:**
   - Run Java application
   - Send phase pattern
   - Verify no errors

3. **Test Amplitude Modulation:**
   - Set ampModStep to 10-20
   - Verify all emitters toggle synchronously
   - Check modulation frequency

4. **Test Focal Points:**
   - Create simple focal point
   - Verify it's palpable
   - Test multiple focal points

5. **Oscilloscope Verification (if available):**
   - Measure emitter output
   - Should see brief pulses at ~16 Hz
   - Pulse width should be ~1.56 μs
   - Different emitters should have different phase offsets

## Compatibility

These changes restore the tactile firmware to match the primary firmware's architecture:
- Same clock speed (10.24 MHz)
- Same counter resolution (8-bit)
- Same phase resolution (32 steps)
- Same phase processing logic

The tactile firmware retains its unique features:
- Amplitude modulation (AmpModulator)
- Pulse length control
- Modulation step control

## Next Steps

If 100 Hz amplitude modulation is required (for tactile feedback), the AmpModulator needs modification:
- Current maximum modulation period: ~158 μs (6.3 kHz)
- Required for 100 Hz: 10 ms period
- Solution: Add prescaler or increase step counter width

This is a separate enhancement beyond the current bug fix.

## Verification

To verify the fix worked:
1. The waveform at emitters should be correct (brief pulses, not continuous)
2. Focal points should be stable and palpable
3. Amplitude modulation should work (all emitters toggle together)
4. System should behave like primary firmware but with amplitude modulation capability

---

**Status:** READY FOR TESTING
**Confidence:** HIGH - Changes restore proven working configuration from primary firmware

