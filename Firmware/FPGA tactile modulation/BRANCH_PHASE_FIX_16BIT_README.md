# Branch: phase_fix_16bit

## Overview

This branch contains the **working FPGA code from commit 57461792** combined with **all documentation and WaveDrom improvements** from the fix-phase-calibration-16divs branch.

---

## What's in This Branch

### ✅ Working FPGA Code (from commit 57461792)

**File:** `Firmware/FPGA tactile modulation/src/Distribute.vhd`

```vhdl
type T_PHASE_CORRECTION is array (0 to 255) of integer range 0 to 16;
constant PHASE_CORRECTION : T_PHASE_CORRECTION := (11,5,6,5,13,14,13,13,5,6,6,13,14,5,6,6,...);
```

**Status:**
- ✅ Generates 40kHz carrier signal
- ✅ Modulation at ~100Hz with 50% duty cycle
- ✅ Phase calibration values divided by 2 for 16-division system
- ✅ Range 0-16 (correct for 16 phase divisions)

**Known Issues:**
- ❌ Individual emitter on/off switching doesn't work properly (clicking but no signal change)
- ❌ Modulation is NOT synchronous across all emitters (phase shifts up to 10ms observed)

---

### ✅ Complete Documentation (cherry-picked)

All documentation has been preserved from the fix-phase-calibration-16divs branch:

#### 1. **PHASE_SIGNAL_PATH_DOCUMENTATION.md**
- Complete signal flow from Java to FPGA to emitters
- Detailed timing diagrams with WaveDrom
- Clock generation and frequency calculations
- Phase-shifted pulse generation examples
- Amplitude modulation for tactile feedback

#### 2. **NUMERICAL_VERIFICATION.md**
- Verified all clock frequencies and timing calculations
- Pulse width calculations
- Duty cycle analysis
- Phase shift calculations with examples
- Modulation frequency verification

#### 3. **FPGA_PRIMARY_VS_TACTILE_COMPARISON.md**
- Comparison of Primary (32 divisions) vs Tactile (16 divisions)
- Clock generation differences
- Pulse width and duty cycle comparison
- Spatial resolution analysis

#### 4. **DUTY_CYCLE_CORRECTION.md**
- Analysis of why 50% duty cycle is standard for ultrasonic levitation
- Literature review and evidence
- Current implementation analysis (5.47% vs 50%)

#### 5. **DUTY_CYCLE_FIX_IMPLEMENTATION.md**
- Proposed fix for achieving 50% duty cycle
- Code changes required
- Timing diagrams showing the fix

#### 6. **MUX8_ANALYSIS.md**
- Analysis of Mux8 module and 8:1 multiplexing
- Timing diagrams

---

### ✅ WaveDrom Timing Diagrams

All WaveDrom diagrams have been generated as SVG files and embedded in the documentation:

**Total:** 22 SVG timing diagrams

**Files:**
- `wavedrom-images/PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-*.svg` (6 diagrams)
- `wavedrom-images/DUTY_CYCLE_CORRECTION-diagram-*.svg` (2 diagrams)
- `wavedrom-images/DUTY_CYCLE_FIX_IMPLEMENTATION-diagram-*.svg` (2 diagrams)
- `wavedrom-images/MUX8_ANALYSIS-diagram-*.svg` (2 diagrams)
- `wavedrom-images/WAVEDROM_DIAGRAMS_SUMMARY-diagram-*.svg` (10 diagrams)

**Scripts:**
- `generate_wavedrom_images.py` - Python script to generate SVG files
- `generate-wavedrom-images.js` - Node.js alternative
- `package.json` - Node.js dependencies
- `venv/` - Python virtual environment with wavedrom package

---

### ✅ GUI Modulation Control

**Files:**
- `Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/gui/panels/TransControlPanel.java`
- `Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/gui/panels/TransControlPanel.form`

**Feature:**
- Added "Mod Step" spinner to Devs tab
- Range: 1-31
- Controls modulation frequency: ~645Hz to 20kHz
- Real-time adjustment without recompiling

**Documentation:**
- `GUI_MODULATION_CONTROL_ADDED.md`
- `MODULATION_FREQUENCY_CONTROL.md`

---

## Branch History

```
* 6f62183 (HEAD -> phase_fix_16bit) Add GUI modulation control and WaveDrom SVG diagrams
* 530be51 add wavedrom_diagrams
* 96bfc1c add wavedrom_diagrams
* 3a78b51 CRITICAL FINDING: Duty cycle should be 50%, not 5.47%!
* 427e568 Add FPGA Primary vs Tactile comparison - duty cycle analysis
* 14c1b1d Add numerical verification document with corrected pulse width
* ca16758 Add comprehensive phase signal path documentation
* 5746179 Apply new phase calibration (divided by 2) for 16-division system  <-- WORKING CODE
```

---

## What Was NOT Included

**Commit 0319c27** - "FIX: Implement 50% duty cycle by using phase division clock"

This commit modified `PhaseLine.vhd` to attempt to fix the duty cycle issue, but it was **NOT cherry-picked** because:
1. The working code is from commit 57461792 (before this fix)
2. This fix may have introduced the synchronization issues

---

## Outstanding Issues to Investigate

### 1. Individual Emitter Control
**Problem:** Switching individual emitters on/off doesn't work properly
- Clicking sound is heard
- Signal doesn't seem to change

**Suspected Cause:** `pulse_length` signal handling in AllChannels.vhd

### 2. Modulation Synchronization
**Problem:** Modulation is not synchronous across all emitters
- Phase shifts of up to 10ms observed
- Expected: All emitters on/off at the same time
- Observed: Sequential toggling

**Suspected Cause:** 
```vhdl
AllChannels: process (chgClock) begin 
    if (rising_edge(chgClock)) then
        s_enabled( to_integer(unsigned(pulse_length)) ) <= NOT s_enabled( to_integer(unsigned(pulse_length)) );
    end if;
end process;
```

This toggles only ONE emitter at a time (indexed by `pulse_length`), not all emitters synchronously.

---

## Next Steps

1. **Investigate modulation synchronization issue**
   - Understand the intended behavior of `pulse_length` signal
   - Determine if all emitters should modulate together or individually
   - Fix AllChannels.vhd if needed

2. **Test individual emitter control**
   - Verify the GUI control mechanism
   - Check signal path from GUI to FPGA

3. **Consider duty cycle fix**
   - Evaluate if 50% duty cycle is needed
   - Test the fix from commit 0319c27 separately
   - Ensure it doesn't break synchronization

---

## How to Use This Branch

```bash
# Checkout the branch
git checkout phase_fix_16bit

# Build the FPGA project
cd "Firmware/FPGA tactile modulation"
# Use Quartus to compile

# Generate WaveDrom diagrams (if needed)
.\venv\Scripts\python.exe generate_wavedrom_images.py

# Build the Java GUI
cd Ultraino/Ultraino/AcousticFieldSim
# Use your Java build process
```

---

**Created:** 2026-01-19  
**Base Commit:** 57461792 (working code)  
**Branch:** phase_fix_16bit

