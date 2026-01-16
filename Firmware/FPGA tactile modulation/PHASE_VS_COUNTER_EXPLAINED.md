# Phase vs Counter - Understanding the Two Signals

## The Confusion

When reading the code, it's easy to think that **both** `phase` and `counter` come from Java. This is **NOT** true!

---

## Two Separate Signals

### 1. Phase (FROM JAVA)
**Source:** Java application → Serial → UART → Distribute → AllChannels → PhaseLine

**What it is:** The TARGET time when each emitter should pulse

**Characteristics:**
- Different for each emitter (256 different values)
- Calculated based on distance to focal point
- Sent via serial communication
- Stored in each PhaseLine instance
- Static (doesn't change until new data sent)

**Example:**
```
Emitter 0: phase = 10  (stored in PhaseLine #0)
Emitter 1: phase = 5   (stored in PhaseLine #1)
Emitter 2: phase = 0   (stored in PhaseLine #2)
...
Emitter 255: phase = 12 (stored in PhaseLine #255)
```

---

### 2. Counter (FPGA INTERNAL)
**Source:** Masterclock → Counter.vhd → AllChannels → ALL PhaseLine instances

**What it is:** The CURRENT time reference that all emitters watch

**Characteristics:**
- Same for ALL emitters (broadcast to all 256 PhaseLine instances)
- Generated internally by FPGA counter
- Counts continuously: 0→1→2→...→15→0→1→...
- Changes every 160 ns
- Never sent from Java

**Example:**
```
Time 0.0 μs:   counter = 0  (broadcast to all 256 PhaseLine)
Time 0.16 μs:  counter = 1  (broadcast to all 256 PhaseLine)
Time 0.32 μs:  counter = 2  (broadcast to all 256 PhaseLine)
...
Time 1.6 μs:   counter = 10 (broadcast to all 256 PhaseLine)
...
Time 2.4 μs:   counter = 15 (broadcast to all 256 PhaseLine)
Time 2.56 μs:  counter = 0  (wraps around)
```

---

## How They Work Together

### The Clock Analogy

Think of it like a clock tower and many alarm clocks:

**Counter = Clock Tower**
- One clock tower in the town square
- Everyone can see it
- Shows the current time: 0, 1, 2, 3, ..., 15, 0, 1, ...
- Runs continuously

**Phase = Alarm Clocks**
- Each person (emitter) has their own alarm clock
- Each alarm is set to a different time
- Person 0's alarm: set to 10
- Person 1's alarm: set to 5
- Person 2's alarm: set to 0

**What Happens:**
- Clock tower shows 0 → Person 2's alarm rings! (phase=0 matches counter=0)
- Clock tower shows 1 → Nobody's alarm rings
- Clock tower shows 2 → Nobody's alarm rings
- ...
- Clock tower shows 5 → Person 1's alarm rings! (phase=5 matches counter=5)
- ...
- Clock tower shows 10 → Person 0's alarm rings! (phase=10 matches counter=10)

---

## In the VHDL Code

### AllChannels.vhd Port Declaration
```vhdl
entity AllChannels is
    port (
        counter : in std_logic_vector(6 downto 0);  -- FROM Counter.vhd (FPGA internal)
        phase : in std_logic_vector(7 downto 0);    -- FROM Distribute.vhd (from Java)
        ...
    );
end AllChannels;
```

### AllChannels.vhd - Broadcasting
```vhdl
-- ALL 256 PhaseLine instances get the SAME counter value
PhaseLine_inst : PhaseLine PORT MAP (
    counter => counter(6 downto 3),  -- Same for all 256 instances
    phase => phase(5 downto 1),      -- Different for each instance (set one at a time)
    ...
);
```

### PhaseLine.vhd - Comparison
```vhdl
-- Each PhaseLine compares its stored phase with the broadcast counter
if (s_phaseCurrent = to_integer(unsigned(counter))) then
    s_counter <= 7;  -- Start pulse when they match!
end if;
```

---

## Data Flow Diagram

```
JAVA                          FPGA
====                          ====

Calculate phase for           [Masterclock]
each emitter                       ↓
    ↓                         [Counter.vhd]
Send via serial                    ↓
    ↓                         counter(6:3) → 0,1,2,...,15,0,1,...
[UART]                             ↓
    ↓                              ↓
[Distribute]                       ↓
    ↓                              ↓
phase for emitter 0 ──→ [PhaseLine #0] ← counter (broadcast)
phase for emitter 1 ──→ [PhaseLine #1] ← counter (broadcast)
phase for emitter 2 ──→ [PhaseLine #2] ← counter (broadcast)
    ...                     ...
phase for emitter 255 → [PhaseLine #255] ← counter (broadcast)
```

---

## Key Takeaways

1. **Phase comes FROM Java** - It's the target time for each emitter
2. **Counter is FPGA internal** - It's the current time reference
3. **Counter is broadcast to ALL emitters** - They all see the same time
4. **Phase is unique per emitter** - Each has its own target time
5. **Pulse happens when counter = phase** - When current time matches target time

---

## Why This Design?

This design is elegant because:

1. **Synchronization:** All emitters use the same time reference (counter)
2. **Simplicity:** Java only needs to send target phases, not timing signals
3. **Precision:** FPGA counter provides precise, jitter-free timing
4. **Scalability:** Adding more emitters doesn't require more timing signals

---

## Common Misconception

❌ **WRONG:** "Java sends both phase and counter values"
✅ **CORRECT:** "Java sends phase values. Counter is generated internally by FPGA."

❌ **WRONG:** "Each emitter has its own counter"
✅ **CORRECT:** "All emitters share one counter, but each has its own phase"

❌ **WRONG:** "Counter comes through serial communication"
✅ **CORRECT:** "Counter is generated by Counter.vhd from the system clock"

---

**Version:** 1.0  
**Date:** 2026-01-16  
**Related Documents:** PHASE_COMMUNICATION_DOCUMENTATION.md, QUICK_REFERENCE.md

