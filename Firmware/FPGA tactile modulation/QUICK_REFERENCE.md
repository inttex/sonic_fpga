# Quick Reference Guide - FPGA Tactile Modulation

## Serial Commands

| Command | Byte Value | Description |
|---------|-----------|-------------|
| Start Phases | 254 (0xFE) | Begin phase data transmission |
| Swap Buffers | 253 (0xFD) | Activate new phase values |
| Multiplex | 252 (0xFC) | Toggle multiplex mode |
| Start Amplitudes | 251 (0xFB) | Begin amplitude data (unused in current version) |
| Amp Mod Step | 101XXXXX (0xA0-0xBF) | Set amplitude modulation rate (XXXXX = 0-31) |
| Phase Data | 0-16 | Phase value for one emitter (0-15 = phase, 16 = OFF) |

## Phase Value Transformations

| Stage | Value Range | Bits | Description |
|-------|-------------|------|-------------|
| Java Continuous | 0.0 - 2.0 | float | Normalized phase (0 = 0°, 2 = 360°) |
| Java Discrete | 0 - 15 | 4 bits | Discretized phase (16 divisions) |
| Serial Transmission | 0 - 16 | 8 bits | 0-15 = phase, 16 = OFF |
| FPGA Distribute | 0 - 63 | 6 bits | (phase * 2) + correction |
| FPGA AllChannels | 0 - 31 | 5 bits | bits(5:1) extraction |
| FPGA PhaseLine | 0 - 15 | 4 bits | counter(6:3) comparison |

## Timing Parameters

| Parameter | Value | Calculation |
|-----------|-------|-------------|
| System Clock | 50 MHz | Crystal oscillator |
| Clock Period | 20 ns | 1 / 50 MHz |
| Counter Range | 0 - 127 | 7 bits |
| Counter Period | 2.56 μs | 128 * 20 ns |
| Phase Steps | 16 | counter(6:3) range |
| Phase Step Time | 160 ns | 8 * 20 ns |
| Pulse Width | 160 ns | 8 clock cycles |
| Pulse Frequency | 390.625 kHz | 1 / 2.56 μs |
| Transducer Frequency | 40 kHz | Mechanical resonance |
| Phase Resolution | 22.5° | 360° / 16 |

## Bit Extraction Logic

### Counter Bits
```
counter[6:0] = 7-bit counter (0-127)
counter[6:3] = 4-bit phase counter (0-15)    → PhaseLine comparison
counter[2:0] = 3-bit mux selector (0-7)      → Mux8 selection
```

### Phase Bits
```
phase[7:0] = 8-bit phase value from Distribute
phase[5:1] = 5-bit phase (0-31)              → PhaseLine storage
phase[0]   = ignored (LSB)
```

## Amplitude Modulation Frequencies

| Step Value | chgClock Period | Modulation Frequency | Use Case |
|------------|----------------|---------------------|----------|
| 0 | 20 ns | 50 MHz | Too fast (not useful) |
| 1 | 5.12 μs | 195 kHz | Too fast |
| 5 | 25.6 μs | 39 kHz | Too fast |
| 10 | 51.2 μs | 19.5 kHz | Too fast |
| 20 | 102.4 μs | 9.8 kHz | Still too fast |
| 31 | 158.7 μs | 6.3 kHz | Maximum (still fast) |

**Note:** Current implementation cannot achieve tactile frequencies (1-200 Hz). 
The step counter would need to be wider (more bits) for proper tactile modulation.

## Memory Map

| Address | Emitter Range | Output Pin |
|---------|--------------|------------|
| 0-7 | Emitters 0-7 | Pin 0 |
| 8-15 | Emitters 8-15 | Pin 1 |
| 16-23 | Emitters 16-23 | Pin 2 |
| ... | ... | ... |
| 248-255 | Emitters 248-255 | Pin 31 |

## Signal Flow Summary

### Phase Data (From Java)
```
Java Phase (0-15)
    ↓ Serial (230400 baud)
Distribute: (phase * 2) + correction
    ↓ bits(5:1)
AllChannels: Extract to 5-bit value (0-31)
    ↓ Store in PhaseLine
PhaseLine: Wait for counter match
```

### Counter (FPGA Internal - NOT from Java)
```
Counter.vhd: 7-bit counter (0-127)
    ↓ bits(6:3)
AllChannels: Extract to 4-bit value (0-15)
    ↓ Broadcast to all PhaseLine
PhaseLine: Compare with stored phase
```

### Combined Output
```
PhaseLine: Generate pulse when counter = phase
    ↓ AND with enabled
PhaseLine: Output pulse (8 cycles)
    ↓ Mux by counter(2:0)
Mux8: Select 1 of 8 emitters
    ↓ Driver circuit
Transducer: 40 kHz acoustic wave
```

## Common Issues and Solutions

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| No output | No swap command | Send swap (253) after phases |
| Wrong phases | Incorrect correction | Check PHASE_CORRECTION array |
| Jitter | Phase wrapping | Verify mod 64 in Distribute |
| No modulation | Step = 0 | Set ampModStep to 10-31 |
| All emitters same | No phase data | Send 254 + 256 phase bytes |

## Java API Quick Reference

```java
// Create device
SimpleFPGA_Tactile device = new SimpleFPGA_Tactile();

// Send phase pattern
device.sendPattern(transducers);  // Sends 254 + phase data

// Activate new phases
device.switchBuffers();  // Sends 253

// Set amplitude modulation
device.setAmpModulationStep(10);  // Sends 0xAA (10100000 | 00001010)

// Toggle multiplex mode
device.sendToogleQuickMultiplexMode();  // Sends 252
```

## VHDL Component Hierarchy

```
Top Level
├── Masterclock (PLL)
├── Counter (7-bit)
├── UART Receiver
├── Distribute (Command decoder)
├── AmpModulator (Modulation clock)
└── AllChannels
    ├── PhaseLine (×256 instances)
    └── Mux8 (×32 instances)
```

## Debugging Signals

| Signal | Location | What to Check |
|--------|----------|---------------|
| `byte_in` | UART → Distribute | Should pulse for each byte |
| `q_in` | UART → Distribute | Should show 254, then phase values |
| `swap_out` | Distribute → AllChannels | Should pulse when 253 received |
| `set_out` | Distribute → AllChannels | Should pulse for each phase byte |
| `counter` | Counter → AllChannels | Should count 0-127 continuously |
| `chgClock` | AmpModulator → AllChannels | Should pulse at modulation rate |
| `s_enabled` | AllChannels internal | Should toggle on chgClock |
| `pulse` | PhaseLine → Mux8 | Should pulse when phase matches |
| `data_out` | Mux8 → Output pins | Final multiplexed output |

---

**Version:** 1.0  
**Date:** 2026-01-16  
**Companion Document:** PHASE_COMMUNICATION_DOCUMENTATION.md

