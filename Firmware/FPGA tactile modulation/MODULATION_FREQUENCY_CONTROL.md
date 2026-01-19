# Modulation Frequency Control Guide

## Overview

The tactile modulation frequency controls how fast the ultrasonic focal points toggle on/off, creating the tactile sensation. This is controlled by the **`steps`** parameter sent from Java to the FPGA.

---

## Current Status

### ✅ What Exists:

1. **FPGA Implementation** - `AmpModulator.vhd` module
   - Receives 5-bit `steps` value (0-31)
   - Generates `chgClock` signal to toggle emitters
   
2. **Java Protocol** - `SimpleFPGA_Tactile.java`
   - Method: `setAmpModulationStep(int step)`
   - Command format: `101XXXXX` (0xA0 | step)

### ❌ What's Missing:

**No GUI control!** There's currently no slider, spinner, or button in the GUI to adjust the modulation frequency.

---

## How Modulation Works

### FPGA Side (AmpModulator.vhd)

<augment_code_snippet path="Firmware/FPGA tactile modulation/src/AmpModulator.vhd" mode="EXCERPT">
````vhdl
if (s_stepCounter = to_integer(unsigned(steps))) then 
    s_stepCounter <= 0;
    s_chgClock <= '1';  -- Pulse to toggle emitters
    s_counter <= s_counter + 1;
else
    s_stepCounter <= s_stepCounter + 1;
    s_chgClock <= '0';
end if
````
</augment_code_snippet>

### Java Side (SimpleFPGA_Tactile.java)

<augment_code_snippet path="Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/protocols/SimpleFPGA_Tactile.java" mode="EXCERPT">
````java
public void setAmpModulationStep(int step){
    if(serial == null){
        return;
    }
    serial.writeByte(getAmpModStepCommand(step));
    serial.flush();
}
````
</augment_code_snippet>

---

## Modulation Frequency Calculation

### Formula:

```
Modulation Frequency = 5.12 MHz / (steps × 256)
```

### Examples:

| Step Value | Calculation | Frequency | Tactile Feel |
|------------|-------------|-----------|--------------|
| 1 | 5.12 MHz / (1 × 256) | **20 kHz** | Very fast vibration |
| 5 | 5.12 MHz / (5 × 256) | **4 kHz** | Fast vibration |
| 10 | 5.12 MHz / (10 × 256) | **2 kHz** | Medium-fast |
| 20 | 5.12 MHz / (20 × 256) | **1 kHz** | Medium |
| 31 | 5.12 MHz / (31 × 256) | **645 Hz** | Slower |

**Note:** For tactile feedback, typical range is **50-200 Hz**, which would require step values around **100-400**. However, the current FPGA implementation only supports 5-bit steps (0-31), limiting the range.

---

## How to Control Modulation (Currently)

### Option 1: Programmatically (No GUI)

You need to modify the Java code to call `setAmpModulationStep()`:

**File:** `Ultraino/Ultraino/AcousticFieldSim/src/acousticfield3d/gui/panels/TransControlPanel.java`

Add this code after connecting to the device:

```java
// After device connection (around line 310)
if (dc instanceof SimpleFPGA_Tactile) {
    SimpleFPGA_Tactile tactileDevice = (SimpleFPGA_Tactile) dc;
    tactileDevice.setAmpModulationStep(10);  // Set to 2 kHz
}
```

### Option 2: Add GUI Control (Recommended)

You need to add a slider or spinner to the GUI. Here's what to add:

#### Step 1: Add GUI Component

**File:** `TransControlPanel.form` (NetBeans GUI Designer)

Add a new `JSpinner` component:
- Name: `modStepSpinner`
- Label: "Mod Freq"
- Range: 1-31
- Default: 10

#### Step 2: Add Event Handler

**File:** `TransControlPanel.java`

```java
private void modStepSpinnerStateChanged(javax.swing.event.ChangeEvent evt) {
    if (device instanceof SimpleFPGA_Tactile) {
        int step = (Integer) modStepSpinner.getValue();
        ((SimpleFPGA_Tactile) device).setAmpModulationStep(step);
    }
}
```

---

## Quick Test Without GUI

### Using Java Console/Debugger:

1. Set a breakpoint in `TransControlPanel.java` after device connection
2. In the debugger console, execute:
   ```java
   ((SimpleFPGA_Tactile)device).setAmpModulationStep(5);
   ```
3. Observe the change in tactile sensation

### Using Code Modification:

**File:** `TransControlPanel.java` - `initSerialButtonActionPerformed()` method

Add after line ~310:

```java
if (device instanceof SimpleFPGA_Tactile) {
    SimpleFPGA_Tactile tactileDevice = (SimpleFPGA_Tactile) device;
    
    // Test different frequencies
    tactileDevice.setAmpModulationStep(1);   // Fast (20 kHz)
    // tactileDevice.setAmpModulationStep(10);  // Medium (2 kHz)
    // tactileDevice.setAmpModulationStep(20);  // Slow (1 kHz)
}
```

---

## Recommended GUI Addition

### Minimal Implementation:

Add to `TransControlPanel.java`:

```java
// In initComponents() - add after phaseSpinner
modStepLabel = new javax.swing.JLabel();
modStepSpinner = new javax.swing.JSpinner();

modStepLabel.setText("Mod Step");
modStepSpinner.setModel(new javax.swing.SpinnerNumberModel(
    Integer.valueOf(10),  // initial value
    Integer.valueOf(1),   // min
    Integer.valueOf(31),  // max
    Integer.valueOf(1)    // step
));
modStepSpinner.setToolTipText("Modulation step rate (1=fast, 31=slow)");
modStepSpinner.addChangeListener(new javax.swing.event.ChangeListener() {
    public void stateChanged(javax.swing.event.ChangeEvent evt) {
        modStepSpinnerStateChanged(evt);
    }
});

// Event handler
private void modStepSpinnerStateChanged(javax.swing.event.ChangeEvent evt) {
    if (device instanceof SimpleFPGA_Tactile) {
        int step = (Integer) modStepSpinner.getValue();
        ((SimpleFPGA_Tactile) device).setAmpModulationStep(step);
        System.out.println("Modulation step set to: " + step);
    }
}
```

---

## Summary

### Current Situation:
- ✅ FPGA supports modulation control
- ✅ Java protocol has the method
- ❌ **No GUI control exists**

### To Control Modulation:
1. **Quick test:** Hardcode `setAmpModulationStep()` call in Java
2. **Proper solution:** Add GUI spinner/slider (requires GUI modification)

### Frequency Range:
- **Step 1:** ~20 kHz (very fast)
- **Step 10:** ~2 kHz (medium)
- **Step 31:** ~645 Hz (slower)

**Note:** For typical tactile feedback (50-200 Hz), you may need to modify the FPGA to support larger step values or add a prescaler.

---

## Next Steps

Would you like me to:
1. **Add the GUI control** to TransControlPanel?
2. **Create a test program** to cycle through different frequencies?
3. **Modify the FPGA** to support a wider frequency range?

Let me know!

