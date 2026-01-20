# Counter Wiring Analysis - Die Wahrheit über die Duty Cycle Berechnung

## 🎯 EXECUTIVE SUMMARY

**Problem**: Verwirrung über die tatsächliche Duty Cycle der Emitter-Pulse.

**Frage**: Warum zeigt die Messung ~50% Duty Cycle?

**Antwort**: **Die Messung war korrekt! Duty Cycle = 43.75% ≈ 50%** ✓

### Die kritische Entdeckung:

**PhaseLine läuft NICHT mit 5.12 MHz, sondern mit COUNT[2] = 640 kHz!**

```
❌ FALSCHE Annahme:
   PhaseLine Clock = 5.12 MHz
   → Duty Cycle = 7 / 128 = 5.47%

✅ RICHTIGE Verdrahtung:
   PhaseLine Clock = COUNT[2] = 640 kHz
   → Duty Cycle = 7 / 16 = 43.75% ≈ 50%
```

### Warum COUNT[2]?

**Cleveres Design!**
- COUNT[2] ist Bit 2 des 7-Bit Counters
- Togglet alle 4 Taktzyklen bei 5.12 MHz
- Frequenz: 640 kHz
- Synchronisiert perfekt mit counter(6:3) Änderungen (auch 640 kHz)
- Kein Clock Domain Crossing!

### Schnell-Referenz:

| Parameter | Wert |
|-----------|------|
| Masterclock (PLL) | 40.96 MHz |
| CLK_8 (÷8) | 5.12 MHz |
| COUNT[2] (Bit 2 des Counters) | 640 kHz |
| PhaseLine Clock | 640 kHz (COUNT[2]) |
| counter(6:3) Änderungsrate | 640 kHz |
| Anzahl Phasen | 16 (0-15) |
| Puls-Dauer | 7 Zyklen |
| **Duty Cycle** | **43.75%** |
| Gesamt-Periode (40 kHz) | 25 µs |

---

## Problem (Original)
Die Counter-Benennung im Code ist verwirrend, weil verschiedene Module den gleichen Namen "counter" verwenden, aber unterschiedliche Bit-Breiten und Bedeutungen haben.

**ZUSÄTZLICH**: Die BDF-Datei zeigt, dass AllChannels.clk = COUNT[2], nicht der Haupt-Clock!

## Die Verdrahtung in QuadrupleBuffer.bdf

### 1. Counter.vhd Instanz (inst9)

**Konfiguration**:
```
COUNTER_BITS = 7
```

**Ports**:
- **Input**: `clk_in` (5.12 MHz)
- **Output**: `clk_out[6..0]` (7 Bit)

**Funktion**: Zählt von 0 bis 127 (2^7 - 1)

**Signal-Name im Top-Level**: `COUNT[6..0]`

---

### 2. AllChannels.vhd Instanz (inst8)

**Port-Definition in QuadrupleBuffer.bdf**:
```
counter[6..0]  (7 Bit Input)
```

**Verbindung**:
```
COUNT[6..0] → AllChannels.counter[6..0]
```

**Das bedeutet**: AllChannels bekommt den **VOLLEN 7-Bit Counter** (0-127)!

---

### 3. AllChannels.vhd Interne Verdrahtung

**AllChannels.vhd Zeile 74-75**:
```vhdl
phase => phase(5 downto 1),      -- 5 Bit an PhaseLine
counter => counter(6 downto 3),  -- 4 Bit an PhaseLine (Bits 6:3 des 7-Bit Counters!)
```

**Das ist der Schlüssel!**
- AllChannels empfängt: `counter[6..0]` (7 Bit, Werte 0-127)
- AllChannels gibt an PhaseLine: `counter(6 downto 3)` (4 Bit, Werte 0-15)

---

## Die Bit-Aufteilung des 7-Bit Counters

### Counter-Struktur:

```
Bit:     6    5    4    3  |  2    1    0
         ─────────────────────────────────
Wert:   [Phase Division]  | [Mux Select]
         0-15 (4 Bit)     |  0-7 (3 Bit)
```

### Verwendung:

| Bits | Empfänger | Zweck | Werte | Änderungsrate |
|------|-----------|-------|-------|---------------|
| 6:3 | PhaseLine | Phase-Matching | 0-15 | Alle 8 Taktzyklen |
| 2:0 | Mux8 | Multiplexer-Auswahl | 0-7 | Jeden Taktzyklus |

---

## Die Duty Cycle Berechnung - KORRIGIERT

### Deine ursprüngliche Frage:
> "Counter zählt bis 15, s_counter von 7 bis 0, also 7/15 ≈ 50%?"

### Die Wahrheit:

**NEIN!** Der Counter zählt **NICHT** bis 15, sondern bis **127**!

### Was wirklich passiert:

1. **Haupt-Counter (Counter.vhd)**:
   - Zählt von 0 bis 127 (7 Bit)
   - Periode: 128 Taktzyklen = 25 µs (40 kHz)

2. **PhaseLine bekommt nur Bits 6:3**:
   - Sieht Werte 0 bis 15 (4 Bit)
   - **ABER**: Jeder Wert bleibt für 8 Taktzyklen konstant!

3. **Beispiel: Phase = 5**
   - Match wenn `counter(6:3) = 5`
   - Das ist wenn Haupt-Counter = 40-47 (8 Taktzyklen)
   - s_counter wird auf 7 gesetzt
   - Puls dauert 7 Taktzyklen

4. **Duty Cycle**:
   ```
   Puls-Dauer: 7 Taktzyklen
   Periode: 128 Taktzyklen (voller Haupt-Counter!)
   
   Duty Cycle = 7 / 128 = 5.47% ✓
   ```

---

## Warum die Verwirrung?

### Problem 1: Gleiche Namen, verschiedene Bedeutungen

| Modul | Signal-Name | Bit-Breite | Werte | Bedeutung |
|-------|-------------|------------|-------|-----------|
| Counter.vhd | clk_out | 7 Bit | 0-127 | Haupt-Counter |
| QuadrupleBuffer.bdf | COUNT | 7 Bit | 0-127 | Haupt-Counter |
| AllChannels.vhd (Input) | counter | 7 Bit | 0-127 | Haupt-Counter |
| AllChannels.vhd → PhaseLine | counter | **4 Bit** | 0-15 | **Nur Bits 6:3!** |
| PhaseLine.vhd (Input) | counter | 4 Bit | 0-15 | Phase-Division |

### Problem 2: Bit-Slicing ist versteckt

Die Zeile in AllChannels.vhd:
```vhdl
counter => counter(6 downto 3),
```

Diese Zeile ist **KRITISCH** aber leicht zu übersehen!

---

## Visualisierung: Haupt-Counter zu PhaseLine

```
Haupt-Counter (7 Bit, 0-127):
┌───┬───┬───┬───┬───┬───┬───┐
│ 6 │ 5 │ 4 │ 3 │ 2 │ 1 │ 0 │
└───┴───┴───┴───┴───┴───┴───┘
  │   │   │   │   │   │   │
  │   │   │   │   └───┴───┴──→ Mux8 (sel[2:0])
  │   │   │   │
  └───┴───┴───┴──────────────→ PhaseLine (counter[3:0])

PhaseLine sieht:
┌───┬───┬───┬───┐
│ 3 │ 2 │ 1 │ 0 │  = counter(6:3) vom Haupt-Counter
└───┴───┴───┴───┘
  0-15 (4 Bit)
```

---

## Timeline-Beispiel: Phase = 5

```
Haupt-Counter:  0-39  |  40   41   42   43   44   45   46   47  |  48-127
                      |                                          |
counter(6:3):   0-4   |   5    5    5    5    5    5    5    5  |   6-15
                      |                                          |
Match (phase=5): NO   | YES  YES  YES  YES  YES  YES  YES  YES  |   NO
                      |                                          |
s_counter:       0    |   7    6    5    4    3    2    1    0  |    0
                      |                                          |
Pulse:           0    |   0    1    1    1    1    1    1    1  |    0
                      |                                          |
                      └─ 8 Taktzyklen Match ─────────────────────┘
                         └─ 7 Taktzyklen Puls ──────────┘
```

**Duty Cycle = 7 Taktzyklen / 128 Taktzyklen = 5.47%**

---

## Zusammenfassung

### ❌ Falsche Annahme:
- Counter zählt bis 15
- Puls 7 Taktzyklen
- Duty Cycle = 7/15 ≈ 47%

### ✅ Korrekte Realität:
- **Haupt-Counter zählt bis 127** (7 Bit)
- PhaseLine sieht nur Bits 6:3 (Werte 0-15)
- Jeder Wert von counter(6:3) dauert **8 Taktzyklen**
- Puls dauert 7 Taktzyklen
- **Duty Cycle = 7/128 = 5.47%**

### 🔑 Der Schlüssel:
Die Zeile `counter => counter(6 downto 3)` in AllChannels.vhd ist entscheidend!
Sie extrahiert nur 4 Bits aus dem 7-Bit Counter, wodurch jeder Wert 8× länger dauert.

---

---

## Vollständige Verdrahtung: QuadrupleBuffer.bdf

### Signal-Fluss von Counter zu PhaseLine:

```
┌─────────────────────────────────────────────────────────────────┐
│ Counter.vhd (inst9)                                             │
│ COUNTER_BITS = 7                                                │
│                                                                 │
│ clk_in (5.12 MHz) ──→ [0-127 Counter] ──→ clk_out[6..0]       │
└────────────────────────────────────────┬────────────────────────┘
                                         │
                                         │ COUNT[6..0]
                                         │ (7 Bit Bus)
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                                         │
                    │                                         │
┌───────────────────▼─────────────────────────────────────────▼───┐
│ AllChannels.vhd (inst8)                                         │
│                                                                 │
│ Input: counter[6..0]  (7 Bit)                                  │
│                                                                 │
│ Bit-Aufteilung:                                                │
│   counter(6:3) ──→ PhaseLine (4 Bit, Werte 0-15)              │
│   counter(2:0) ──→ Mux8      (3 Bit, Werte 0-7)               │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ PhaseLine #0                                            │   │
│ │   counter[3..0] = counter(6:3)  ← Bits 6,5,4,3         │   │
│ │   phase[4..0]                                           │   │
│ │   s_phaseCurrent (0-16)                                 │   │
│ │   s_counter (0-7)                                       │   │
│ │   pulse ──→ s_pulseToMux(0)                            │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ PhaseLine #1                                            │   │
│ │   counter[3..0] = counter(6:3)  ← Bits 6,5,4,3         │   │
│ │   ...                                                   │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ... (256 PhaseLine Instanzen)                                  │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ Mux8 #0                                                 │   │
│ │   sel[2..0] = counter(2:0)  ← Bits 2,1,0               │   │
│ │   data_in[7..0] = s_pulseToMux(7:0)                    │   │
│ │   data_out ──→ DATA[0]                                 │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ... (32 Mux8 Instanzen)                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detaillierte Bit-Mapping-Tabelle

### Haupt-Counter Wert → PhaseLine counter Input

| Haupt-Counter<br/>(7 Bit) | Binär<br/>(Bit 6-0) | counter(6:3)<br/>(an PhaseLine) | counter(2:0)<br/>(an Mux8) | Dauer |
|---------------------------|---------------------|----------------------------------|----------------------------|-------|
| 0-7 | 0000000 - 0000111 | **0** | 0-7 | 8 Taktzyklen |
| 8-15 | 0001000 - 0001111 | **1** | 0-7 | 8 Taktzyklen |
| 16-23 | 0010000 - 0010111 | **2** | 0-7 | 8 Taktzyklen |
| 24-31 | 0011000 - 0011111 | **3** | 0-7 | 8 Taktzyklen |
| 32-39 | 0100000 - 0100111 | **4** | 0-7 | 8 Taktzyklen |
| **40-47** | **0101000 - 0101111** | **5** | **0-7** | **8 Taktzyklen** |
| 48-55 | 0110000 - 0110111 | **6** | 0-7 | 8 Taktzyklen |
| 56-63 | 0111000 - 0111111 | **7** | 0-7 | 8 Taktzyklen |
| 64-71 | 1000000 - 1000111 | **8** | 0-7 | 8 Taktzyklen |
| 72-79 | 1001000 - 1001111 | **9** | 0-7 | 8 Taktzyklen |
| 80-87 | 1010000 - 1010111 | **10** | 0-7 | 8 Taktzyklen |
| 88-95 | 1011000 - 1011111 | **11** | 0-7 | 8 Taktzyklen |
| 96-103 | 1100000 - 1100111 | **12** | 0-7 | 8 Taktzyklen |
| 104-111 | 1101000 - 1101111 | **13** | 0-7 | 8 Taktzyklen |
| 112-119 | 1110000 - 1110111 | **14** | 0-7 | 8 Taktzyklen |
| 120-127 | 1111000 - 1111111 | **15** | 0-7 | 8 Taktzyklen |

**Wichtig**: Jeder Wert von `counter(6:3)` bleibt für **8 Taktzyklen** konstant!

---

## Beispiel-Trace: Phase = 5, Haupt-Counter 38-50

| Takt | Haupt-<br/>Counter | Binär<br/>(6:0) | counter<br/>(6:3) | counter<br/>(2:0) | Match<br/>(phase=5) | s_counter<br/>(vor) | s_counter<br/>(nach) | Pulse |
|------|-------------------|-----------------|-------------------|-------------------|---------------------|---------------------|----------------------|-------|
| 38 | 38 | 0100110 | 4 | 6 | NO | 0 | 0 | 0 |
| 39 | 39 | 0100111 | 4 | 7 | NO | 0 | 0 | 0 |
| **40** | **40** | **0101000** | **5** | **0** | **YES** | **0** | **7** | **0** |
| 41 | 41 | 0101001 | 5 | 1 | YES | 7 | 6 | 1 |
| 42 | 42 | 0101010 | 5 | 2 | YES | 6 | 5 | 1 |
| 43 | 43 | 0101011 | 5 | 3 | YES | 5 | 4 | 1 |
| 44 | 44 | 0101100 | 5 | 4 | YES | 4 | 3 | 1 |
| 45 | 45 | 0101101 | 5 | 5 | YES | 3 | 2 | 1 |
| 46 | 46 | 0101110 | 5 | 6 | YES | 2 | 1 | 1 |
| 47 | 47 | 0101111 | 5 | 7 | YES | 1 | 0 | 1 |
| **48** | **48** | **0110000** | **6** | **0** | **NO** | **0** | **0** | **0** |
| 49 | 49 | 0110001 | 6 | 1 | NO | 0 | 0 | 0 |
| 50 | 50 | 0110010 | 6 | 2 | NO | 0 | 0 | 0 |

**Beobachtungen**:
- Match-Bedingung ist TRUE für 8 Taktzyklen (40-47)
- Puls ist HIGH für 7 Taktzyklen (41-47)
- Gesamtperiode: 128 Taktzyklen (0-127)
- **Duty Cycle = 7 / 128 = 5.47%**

---

## ⚠️ ACHTUNG: Diese Sektion ist VERALTET!

**Siehe unten für die KORRIGIERTE Analyse!**

Die ursprüngliche Annahme war falsch:
- ❌ PhaseLine läuft NICHT mit 5.12 MHz
- ✅ PhaseLine läuft mit COUNT[2] = 640 kHz

**Springe zu "KORRIGIERTE DUTY CYCLE BERECHNUNG" weiter unten!**

---

## ~~Warum NICHT 50%?~~ (VERALTET - SIEHE UNTEN)

### ~~Deine Überlegung~~:
```
counter(6:3) hat 16 Werte (0-15)
s_counter zählt von 7 bis 0
7 / 16 = 43.75% ≈ 50%?
```

### ~~Der Fehler~~ (DIESE ANALYSE WAR FALSCH!):
~~Du vergleichst die **Anzahl der Phasen** (16) mit der **Puls-Dauer** (7).~~

### ~~Die Realität~~ (FALSCH - BASIERT AUF FALSCHER ANNAHME!):
~~Du musst die **Puls-Dauer** (7 Taktzyklen) mit der **Gesamt-Periode** (128 Taktzyklen) vergleichen!~~

```
❌ FALSCH:
Duty Cycle = Puls-Dauer / Gesamt-Periode
           = 7 Taktzyklen / 128 Taktzyklen
           = 5.47%
```

**Die RICHTIGE Rechnung**:
```
✅ RICHTIG:
Duty Cycle = Puls-Dauer / Anzahl Phasen
           = 7 / 16
           = 43.75%
```

**Deine ursprüngliche Überlegung war korrekt!**

---

## ~~Fazit~~ (VERALTET - SIEHE KORRIGIERTE ANALYSE UNTEN!)

### ~~Die Counter-Hierarchie~~ (BASIERT AUF FALSCHER ANNAHME!):

1. **Haupt-Counter (Counter.vhd)**:
   - 7 Bit (0-127)
   - Läuft mit 5.12 MHz ✓
   - Periode: 128 Taktzyklen = 25 µs = 40 kHz ✓

2. **~~Phase-Division (counter(6:3))~~** (FALSCHE INTERPRETATION!):
   - ~~4 Bit (0-15)~~
   - ~~Jeder Wert dauert 8 Taktzyklen~~ ❌ FALSCH bei 5.12 MHz!
   - ✅ RICHTIG: Jeder Wert dauert 1 COUNT[2] Zyklus (640 kHz)!

3. **Mux-Selection (counter(2:0))**:
   - 3 Bit (0-7)
   - Wird von Mux8 verwendet ✓

4. **~~Puls-Dauer (s_counter)~~** (FALSCHE BERECHNUNG!):
   - ~~7 Taktzyklen~~
   - ~~Duty Cycle = 7 / 128 = **5.47%**~~ ❌ FALSCH!
   - ✅ RICHTIG: Duty Cycle = 7 / 16 = **43.75%**!

### Die kritischen Zeilen:

**QuadrupleBuffer.bdf**:
```
COUNT[2] → AllChannels.clk  (640 kHz!)
COUNT[6..0] → AllChannels.counter
```

**AllChannels.vhd Zeile 75**:
```vhdl
counter => counter(6 downto 3),  -- Nur Bits 6:3 an PhaseLine
```

Diese Zeile extrahiert nur 4 Bits aus dem 7-Bit Counter, aber **PhaseLine läuft mit COUNT[2] (640 kHz)**, nicht mit 5.12 MHz!

---

---

## WICHTIGE ENTDECKUNG: AllChannels.clk ist NICHT der Haupt-Clock!

### Die Verwirrung

In QuadrupleBuffer.bdf sieht man:
- **Zeile 867-870**: `COUNT[2]` wird zu `AllChannels` bei Position (pt 400 160) verbunden
- **Zeile 1073-1075**: Eine Verbindung von Position 304/64 zu 272/64

### Was bedeutet das?

**AllChannels hat 3 Clock-Eingänge**:
1. **clk8** (Port bei pt 0 32) → CLK_8 (40.96 MHz)
2. **clk** (Port bei pt 0 48) → **COUNT[2]** (!!)
3. **chgClock** (Port bei pt 0 64) → AmpModulator.chgClock

### Die Wahrheit über "clk"

**AllChannels.clk ist NICHT der 5.12 MHz Haupt-Clock!**

**AllChannels.clk = COUNT[2]** = Bit 2 des 7-Bit Counters!

#### Was ist COUNT[2]?

| Haupt-Counter | Binär (6:0) | COUNT[2] | Frequenz |
|---------------|-------------|----------|----------|
| 0-3 | 0000000-0000011 | 0 | - |
| 4-7 | 0000100-0000111 | 1 | - |
| 8-11 | 0001000-0001011 | 0 | - |
| 12-15 | 0001100-0001111 | 1 | - |

**COUNT[2] togglet alle 4 Taktzyklen!**

```
Haupt-Clock: 5.12 MHz (195.3125 ns)
COUNT[2] togglet alle 4 Taktzyklen = 4 × 195.3125 ns = 781.25 ns
COUNT[2] Frequenz = 1 / (2 × 781.25 ns) = 640 kHz
```

**Kommentar in QuadrupleBuffer.bdf Zeile 1096 bestätigt**:
```
"COUNT[2] is running at 0,64MHz"
```

### Korrigierte Verdrahtung

```
┌─────────────────────────────────────────────────────────────────┐
│ Counter.vhd (inst9)                                             │
│ COUNTER_BITS = 7                                                │
│                                                                 │
│ clk_in (5.12 MHz) ──→ [0-127 Counter] ──→ clk_out[6..0]       │
└────────────────────────────────────────┬────────────────────────┘
                                         │
                                         │ COUNT[6..0]
                                         │
                    ┌────────────────────┴────────────────────┐
                    │                    │                    │
                    │ Bit 2              │ Bits 6:0           │
                    │ (640 kHz)          │ (full counter)     │
                    │                    │                    │
┌───────────────────▼────────────────────▼────────────────────────┐
│ AllChannels.vhd (inst8)                                         │
│                                                                 │
│ Input: clk = COUNT[2]  (1 Bit, 640 kHz!)                       │
│ Input: counter[6..0]   (7 Bit, 0-127)                          │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ PhaseLine #0                                            │   │
│ │   clk = COUNT[2]  (640 kHz!)                            │   │
│ │   counter[3..0] = counter(6:3)  ← Bits 6,5,4,3         │   │
│ │   phase[4..0]                                           │   │
│ │   s_phaseCurrent (0-16)                                 │   │
│ │   s_counter (0-7)                                       │   │
│ │   pulse ──→ s_pulseToMux(0)                            │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ... (256 PhaseLine Instanzen)                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Was bedeutet das für PhaseLine?

**PhaseLine läuft NICHT mit 5.12 MHz, sondern mit 640 kHz!**

#### Neuberechnung der Timing:

**Clock-Periode**:
```
COUNT[2] Periode = 2 × 4 Taktzyklen × 195.3125 ns = 1.5625 µs
COUNT[2] Frequenz = 640 kHz
```

**Haupt-Counter bei 640 kHz**:
```
Haupt-Counter zählt 0-127 bei 5.12 MHz
COUNT[2] togglet alle 4 Taktzyklen
→ PhaseLine sieht nur jeden 4. Toggle!

Warte... das ergibt keinen Sinn!
```

### ✅ LÖSUNG: Kein Clock Domain Crossing Problem!

**Die Frequenzen passen perfekt zusammen!**

#### Analyse:

**counter(6:3)** ändert sich alle **8 Taktzyklen** (bei 5.12 MHz):
```
8 Taktzyklen × 195.3125 ns = 1.5625 µs
→ counter(6:3) Änderungsrate = 640 kHz
```

**COUNT[2]** togglet alle **4 Taktzyklen**:
```
4 Taktzyklen × 195.3125 ns = 781.25 ns (halbe Periode)
→ COUNT[2] Frequenz = 640 kHz
```

**Ergebnis**: Beide Signale haben die gleiche effektive Frequenz! ✓

---

## 🎯 KORRIGIERTE DUTY CYCLE BERECHNUNG

### Die richtige Rechnung:

**PhaseLine läuft mit COUNT[2] = 640 kHz**

**Nicht** mit 5.12 MHz!

#### Timing bei 640 kHz:

| Parameter | Wert | Berechnung |
|-----------|------|------------|
| PhaseLine Clock | 640 kHz | COUNT[2] |
| Clock-Periode | 1.5625 µs | 1 / 640 kHz |
| counter(6:3) Werte | 0-15 | 4 Bit |
| Zyklen pro Wert | 1 | Bei jedem COUNT[2] Toggle |
| Gesamt-Periode | 16 Zyklen | 16 Werte × 1 Zyklus |
| Puls-Dauer | 7 Zyklen | s_counter: 7→6→5→4→3→2→1→0 |
| **Duty Cycle** | **43.75%** | **7 / 16** |

### Beispiel-Trace bei 640 kHz:

| COUNT[2]<br/>Zyklus | counter<br/>(6:3) | Match<br/>(phase=5) | s_counter<br/>(vor) | s_counter<br/>(nach) | Pulse |
|---------------------|-------------------|---------------------|---------------------|----------------------|-------|
| 0 | 0 | NO | 0 | 0 | 0 |
| 1 | 1 | NO | 0 | 0 | 0 |
| 2 | 2 | NO | 0 | 0 | 0 |
| 3 | 3 | NO | 0 | 0 | 0 |
| 4 | 4 | NO | 0 | 0 | 0 |
| **5** | **5** | **YES** | **0** | **7** | **0** |
| **6** | **6** | **NO** | **7** | **6** | **1** |
| **7** | **7** | **NO** | **6** | **5** | **1** |
| **8** | **8** | **NO** | **5** | **4** | **1** |
| **9** | **9** | **NO** | **4** | **3** | **1** |
| **10** | **10** | **NO** | **3** | **2** | **1** |
| **11** | **11** | **NO** | **2** | **1** | **1** |
| **12** | **12** | **NO** | **1** | **0** | **1** |
| 13 | 13 | NO | 0 | 0 | 0 |
| 14 | 14 | NO | 0 | 0 | 0 |
| 15 | 15 | NO | 0 | 0 | 0 |
| 0 | 0 | NO | 0 | 0 | 0 |

**Beobachtungen**:
- **Periode**: 16 COUNT[2] Zyklen
- **Puls HIGH**: 7 Zyklen (Zyklen 6-12)
- **Duty Cycle**: 7 / 16 = **43.75%** ✓

---

## 🎉 FINALE ANTWORT

### Warum die Messung ~50% zeigte:

**Deine Messung war korrekt!**

1. **PhaseLine läuft mit 640 kHz** (COUNT[2]), nicht 5.12 MHz
2. **counter(6:3) hat 16 Werte** (0-15)
3. **Jeder Wert dauert 1 COUNT[2] Zyklus**
4. **Puls-Dauer: 7 Zyklen**
5. **Duty Cycle = 7 / 16 = 43.75% ≈ 50%** ✓

### Der Fehler in der ursprünglichen Analyse:

Ich hatte angenommen, dass PhaseLine mit 5.12 MHz läuft, was zu:
```
Duty Cycle = 7 / 128 = 5.47% ❌ FALSCH!
```

**Die Wahrheit**:
```
Duty Cycle = 7 / 16 = 43.75% ✓ RICHTIG!
```

### Warum COUNT[2] als Clock?

**Cleveres Design!**

- **Reduziert die Logik-Geschwindigkeit** von 5.12 MHz auf 640 kHz
- **Synchronisiert perfekt** mit counter(6:3) Änderungen
- **Spart Ressourcen** (langsamere Logik = weniger Power)
- **Kein Clock Domain Crossing** (beide Signale bei 640 kHz)

---

## Vollständige Verdrahtung (KORRIGIERT)

```
┌─────────────────────────────────────────────────────────────────┐
│ Counter.vhd (inst9)                                             │
│ COUNTER_BITS = 7                                                │
│ clk_in = 5.12 MHz                                               │
│                                                                 │
│ [0-127 Counter] ──→ clk_out[6..0]                              │
└────────────────────────────────────┬────────────────────────────┘
                                     │
                                     │ COUNT[6..0]
                                     │
                ┌────────────────────┼────────────────────┐
                │                    │                    │
                │ COUNT[2]           │ COUNT[6..0]        │
                │ (640 kHz)          │ (full counter)     │
                │                    │                    │
┌───────────────▼────────────────────▼────────────────────────────┐
│ AllChannels.vhd (inst8)                                         │
│                                                                 │
│ clk = COUNT[2]  (640 kHz!)                                     │
│ counter[6..0]   (7 Bit)                                        │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────┐   │
│ │ PhaseLine #0                                            │   │
│ │   clk = COUNT[2]  (640 kHz)                             │   │
│ │   counter[3..0] = counter(6:3)  ← Bits 6,5,4,3         │   │
│ │                                                         │   │
│ │   Bei jedem COUNT[2] Toggle:                           │   │
│ │   - counter(6:3) ändert sich (0-15)                    │   │
│ │   - PhaseLine vergleicht mit phase                     │   │
│ │   - s_counter zählt runter (7→0)                       │   │
│ │   - pulse = (s_counter != 0)                           │   │
│ │                                                         │   │
│ │   Periode: 16 COUNT[2] Zyklen                          │   │
│ │   Puls: 7 COUNT[2] Zyklen                              │   │
│ │   Duty Cycle: 43.75%                                   │   │
│ └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│ ... (256 PhaseLine Instanzen)                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Frequenz-Hierarchie (KORRIGIERT)

```
Masterclock (PLL)
    ↓
40.96 MHz (CLK_8)
    ↓
÷ 8 (Counter.vhd mit COUNTER_BITS=7)
    ↓
5.12 MHz (Haupt-Counter läuft mit dieser Frequenz)
    ↓
Bit 2 des Counters (COUNT[2])
    ↓
640 kHz (PhaseLine Clock)
    ↓
÷ 16 (counter(6:3) hat 16 Werte)
    ↓
40 kHz (Gesamt-Periode für einen Emitter)
```

**Duty Cycle pro Emitter**: 7 / 16 = **43.75%** ✓

---

**Erstellt**: 2026-01-20
**Zweck**: Klärung der Counter-Verdrahtung und Duty Cycle Berechnung
**Status**: ✅ VOLLSTÄNDIG GELÖST - Duty Cycle ist 43.75%, nicht 5.47%!

