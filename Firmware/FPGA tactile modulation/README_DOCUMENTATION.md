# FPGA Tactile Modulation - Documentation Index

## Overview

This documentation suite explains the complete communication and signal processing chain from Java application to FPGA hardware, showing how phase information becomes temporal ultrasonic signals for acoustic levitation and tactile feedback.

**System Purpose:** Control 256 ultrasonic emitters (40 kHz) with precise phase relationships to create acoustic focal points in 3D space, with optional amplitude modulation for tactile feedback.

---

## Documentation Files

### 1. **PHASE_VS_COUNTER_EXPLAINED.md** (Start Here!)
**Purpose:** Clarify the difference between phase (from Java) and counter (FPGA internal)

**Contents:**
- The confusion: What comes from Java vs what's internal
- Phase: Target time for each emitter (from Java)
- Counter: Current time reference (FPGA internal)
- Clock tower analogy
- How they work together
- Common misconceptions

**Best for:** Understanding the fundamental architecture, clearing up confusion about data sources

---

### 2. **PHASE_COMMUNICATION_DOCUMENTATION.md** (Main Document)
**Purpose:** Complete end-to-end explanation of the system

**Contents:**
- Part 1: Java - Phase Calculation
  - Physical distance to phase conversion
  - Discretization algorithm
  - Serial packet construction
  
- Part 2: FPGA - Serial Reception and Processing
  - UART reception
  - Command decoding in Distribute.vhd
  - Phase correction and scaling
  - Double buffering mechanism
  
- Part 3: FPGA - Timing Generation
  - Master clock and counter hierarchy
  - Bit extraction logic (counter[6:3] and phase[5:1])
  - Timing calculations
  
- Part 4: FPGA - Pulse Generation
  - Phase matching in PhaseLine.vhd
  - Pulse width and timing
  - Time division multiplexing in Mux8.vhd
  - Transducer resonance explanation
  
- Part 5: Complete Example - End to End
  - Step-by-step walkthrough with real numbers
  - 100mm focal point example
  
- Part 6: Phase Relationships Between Emitters
  - How different phases create focal points
  - Time offset calculations
  
- Part 7: Amplitude Modulation (Tactile Feedback)
  - AmpModulator.vhd operation
  - Synchronous emitter toggling
  - Frequency calculations
  
- Summary and Troubleshooting Guide

**Best for:** Understanding the complete system, learning how it works, debugging issues

---

### 3. **QUICK_REFERENCE.md**
**Purpose:** Fast lookup of values, commands, and parameters

**Contents:**
- Serial command table (254, 253, 252, etc.)
- Phase value transformation table (Java → FPGA)
- Timing parameters (frequencies, periods, bit widths)
- Bit extraction logic reference
- Amplitude modulation frequency table
- Memory map (emitter to pin mapping)
- Signal flow summary
- Common issues and solutions
- Java API quick reference
- VHDL component hierarchy
- Debugging signals checklist

**Best for:** Quick lookups during development, debugging, testing

---

### 4. **TIMING_DIAGRAMS.md**
**Purpose:** Visual representation of signal timing relationships

**Contents:**
1. Counter and Bit Extraction
   - 7-bit counter waveform
   - counter[6:3] and counter[2:0] extraction
   
2. Phase Matching and Pulse Generation
   - Example with phase = 10
   - s_counter countdown
   - Pulse output timing
   
3. Multiple Emitters with Different Phases
   - Three emitters (phase 0, 5, 10)
   - Time offset visualization
   
4. Time Division Multiplexing (Mux8)
   - 8 emitters sharing one pin
   - Multiplexer selection timing
   
5. Amplitude Modulation Timing
   - chgClock generation
   - s_enabled toggle pattern
   
6. Complete System Timing
   - All signals together for one emitter

**Best for:** Understanding timing relationships, oscilloscope measurements, debugging timing issues

---

## Interactive Diagrams

Three Mermaid diagrams are available (generated during documentation creation):

1. **Java to FPGA Phase Communication Flow**
   - Shows data flow from Java calculation to acoustic output
   - Color-coded by subsystem
   
2. **FPGA Timing and Phase Relationships**
   - Shows clock hierarchy and phase processing
   - Illustrates bit extraction and pulse generation
   
3. **Amplitude Modulation System (Tactile Feedback)**
   - Shows modulation control flow
   - Explains synchronous toggling mechanism

---

## Quick Start Guide

### For New Developers:
1. Start with **PHASE_VS_COUNTER_EXPLAINED.md** - Understand the architecture
2. Read **PHASE_COMMUNICATION_DOCUMENTATION.md** - Parts 1-4
3. Review **TIMING_DIAGRAMS.md** - Sections 1-3
4. Keep **QUICK_REFERENCE.md** open for lookups

### For Debugging:
1. Check **QUICK_REFERENCE.md** - "Common Issues and Solutions"
2. Use **QUICK_REFERENCE.md** - "Debugging Signals" table
3. Compare measurements with **TIMING_DIAGRAMS.md**

### For API Usage:
1. See **QUICK_REFERENCE.md** - "Java API Quick Reference"
2. See **QUICK_REFERENCE.md** - "Serial Commands" table
3. See **PHASE_COMMUNICATION_DOCUMENTATION.md** - Part 1 for algorithms

---

## Key Concepts Summary

### Phase in Space → Phase in Time
Physical distance differences between emitters and focal point are converted to timing differences in pulse generation. This creates constructive interference at the target location.

### 16 Phase Divisions
The system uses 16 discrete phase steps (0-15), giving 22.5° resolution. This is sufficient for creating stable focal points.

### Double Buffering
New phase values are written to `s_phasePrev` while `s_phaseCurrent` is active. The swap command (253) exchanges them atomically, preventing glitches.

### Bit Slicing for Efficiency
- `phase[5:1]` extracts 5 bits from 8-bit value (divide by 2)
- `counter[6:3]` extracts 4 bits from 7-bit counter (divide by 8)
- This creates the 16-step phase matching system

### Time Division Multiplexing
8 emitters share each output pin, selected by `counter[2:0]`. This reduces pin count from 256 to 32.

### Mechanical Resonance
Transducers receive pulses at 390.625 kHz but resonate at 40 kHz, converting digital pulses to continuous sine waves.

---

## System Specifications

| Parameter | Value |
|-----------|-------|
| Number of Emitters | 256 |
| Output Pins | 32 (8:1 multiplexing) |
| Transducer Frequency | 40 kHz |
| Phase Resolution | 16 steps (22.5°) |
| System Clock | 50 MHz |
| Pulse Frequency | 390.625 kHz |
| Pulse Width | 160 ns |
| Serial Baud Rate | 230400 |
| Amplitude Modulation | 0-6.3 kHz (limited) |

---

## File Structure

```
firmware/FPGA tactile modulation/
├── README_DOCUMENTATION.md          (This file - Index)
├── PHASE_VS_COUNTER_EXPLAINED.md    (Phase vs Counter clarification)
├── PHASE_COMMUNICATION_DOCUMENTATION.md  (Main technical document)
├── QUICK_REFERENCE.md               (Lookup tables and commands)
├── TIMING_DIAGRAMS.md               (Waveform diagrams)
└── src/
    ├── Distribute.vhd               (Command decoder, phase processing)
    ├── AllChannels.vhd              (256 PhaseLine + 32 Mux8 instances)
    ├── PhaseLine.vhd                (Phase matching, pulse generation)
    ├── Counter.vhd                  (7-bit counter)
    ├── AmpModulator.vhd             (Amplitude modulation clock)
    ├── Mux8.vhd                     (8:1 multiplexer)
    └── Masterclock.vhd              (PLL clock generation)
```

---

## Related Java Files

```
Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/
├── protocols/
│   └── SimpleFPGA_Tactile.java      (Serial protocol implementation)
├── algorithms/
│   └── SimplePhaseAlgorithms.java   (Phase calculation algorithms)
└── simulation/
    └── Transducer.java              (Phase discretization)
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-16 | Initial documentation suite created |

---

## Contact and Support

For questions about this documentation or the FPGA tactile modulation system, refer to:
- Code comments in VHDL files
- Java source code documentation
- This documentation suite

---

**Last Updated:** 2026-01-16  
**Documentation Suite Version:** 1.0

