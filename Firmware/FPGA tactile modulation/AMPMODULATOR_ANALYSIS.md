# AmpModulator Analysis - Sequential Emitter Toggle System

## 🎯 Executive Summary

**AmpModulator** ist ein Modul zur **sequenziellen Steuerung** der Emitter.

**Funktion**: Generiert einen langsam ansteigenden Zählerwert (0-255) mit konfigurierbarer Geschwindigkeit.

**Zweck**: Schaltet Emitter sequenziell ein/aus für **taktile Modulation** (z.B. Vibrations-Effekte).

**WICHTIG**: Dies ist KEINE Amplitudenmodulation im klassischen Sinne, sondern ein **sequenzieller Toggle-Mechanismus**!

---

## Port-Definition (AmpModulator.vhd)

```vhdl
entity AmpModulator is
    port (
        clk       : in  STD_LOGIC;                    -- Clock input
        steps     : in  STD_LOGIC_VECTOR (4 downto 0); -- Speed control (0-31)
        amp       : out STD_LOGIC_VECTOR (7 downto 0); -- Amplitude output (0-255)
        chgClock  : out STD_LOGIC                      -- Change indicator pulse
    );
end AmpModulator;
```

### Inputs:

1. **clk** (1 bit)
   - Clock-Signal für den Modulator
   - **Verbindung in QuadrupleBuffer.bdf**: `COUNT[2]` (640 kHz)
   - **WICHTIG**: Läuft mit 640 kHz, nicht mit 5.12 MHz!

2. **steps** (5 bits, 0-31)
   - Steuert die Geschwindigkeit der Amplitudenänderung
   - **Verbindung in QuadrupleBuffer.bdf**: `Distribute.ampModStep[4..0]`
   - Höherer Wert = langsamere Änderung
   - Wert 0 = schnellste Änderung (jeder Clock-Zyklus)
   - Wert 31 = langsamste Änderung (alle 32 Clock-Zyklen)

### Outputs:

1. **amp** (8 bits, 0-255)
   - Aktueller Zählerwert (Emitter-Index)
   - Zählt von 0 bis 255, dann wieder von 0
   - **Verbindung in QuadrupleBuffer.bdf**: `AllChannels.pulse_length[7..0]`
   - **Verwendung**: Bestimmt, welcher Emitter getoggled wird!

2. **chgClock** (1 bit)
   - Puls-Signal, das bei jeder Zähler-Änderung HIGH wird
   - **Verbindung in QuadrupleBuffer.bdf**: `AllChannels.chgClock`
   - Dauer: 1 Clock-Zyklus HIGH, dann LOW bis zur nächsten Änderung
   - **Verwendung**: Triggert das Toggle des Emitters!

---

## Funktionsweise

### Interne Signale:

```vhdl
signal s_amp         : STD_LOGIC_VECTOR (7 downto 0) := (others => '1'); -- Amplitude (0-255)
signal s_counter     : integer range 0 to 255 := 0;                      -- Amplitude counter
signal s_stepCounter : integer range 0 to 31 := 0;                       -- Step counter
signal s_chgClock    : STD_LOGIC := '0';                                 -- Change clock
```

### Algorithmus:

```vhdl
process (clk) begin
    if (rising_edge(clk)) then
        if (s_stepCounter = to_integer(unsigned(steps))) then
            -- Time to change amplitude!
            s_stepCounter <= 0;
            s_chgClock <= '1';  -- Pulse HIGH for 1 cycle
            s_amp <= std_logic_vector(to_unsigned(s_counter, 8));

            if (s_counter = 255) then
                s_counter <= 0;  -- Wrap around
            else
                s_counter <= s_counter + 1;
            end if
        else
            -- Keep counting steps
            s_stepCounter <= s_stepCounter + 1;
            s_chgClock <= '0';
        end if
    end if
end process;
```

### Timing-Beispiel (steps = 5):

| Clock | s_stepCounter | Match? | s_counter | s_amp | chgClock |
|-------|---------------|--------|-----------|-------|----------|
| 0 | 0 | NO | 0 | 255 | 0 |
| 1 | 1 | NO | 0 | 255 | 0 |
| 2 | 2 | NO | 0 | 255 | 0 |
| 3 | 3 | NO | 0 | 255 | 0 |
| 4 | 4 | NO | 0 | 255 | 0 |
| **5** | **5** | **YES** | **0** | **0** | **1** |
| 6 | 0 | NO | 1 | 0 | 0 |
| 7 | 1 | NO | 1 | 0 | 0 |
| 8 | 2 | NO | 1 | 0 | 0 |
| 9 | 3 | NO | 1 | 0 | 0 |
| 10 | 4 | NO | 1 | 0 | 0 |
| **11** | **5** | **YES** | **1** | **1** | **1** |
| 12 | 0 | NO | 2 | 1 | 0 |

**Beobachtungen**:
- **chgClock** ist HIGH für 1 Zyklus alle (steps + 1) Zyklen
- **s_amp** ändert sich bei jedem chgClock-Puls
- **s_counter** zählt von 0 bis 255, dann wieder von 0

---

## Verbindungen in QuadrupleBuffer.bdf

### AmpModulator (inst14):

**Position**: (rect 88 16 272 96)

**Inputs**:
- **clk** ← `COUNT[2]` (640 kHz)
  - Connector: (pt 48 48) → (pt 88 48)
  - Label: "COUNT[2]" bei (rect 40 24 91 36)

- **steps[4..0]** ← `Distribute.ampModStep[4..0]`
  - Connector: (pt 72 64) → (pt 88 64)
  - Intermediate: (pt 112 256) → (pt 72 128) → (pt 72 64)

**Outputs**:
- **amp[7..0]** → `AllChannels.pulse_length[7..0]`
  - Connector: (pt 272 48) → (pt 288 48) → (pt 288 208) → (pt 400 208)
  - **VERWENDET!** Bestimmt, welcher Emitter getoggled wird

- **chgClock** → `AllChannels.chgClock`
  - Connector: (pt 272 64) → (pt 304 64) → (pt 304 176) → (pt 400 176)
  - **VERWENDET!** Triggert das Toggle-Event

---

## Frequenz-Berechnung

### Clock-Frequenz:

**AmpModulator.clk = COUNT[2] = 640 kHz**

Periode: 1.5625 µs

### chgClock-Frequenz:

**Abhängig von `steps` Wert**:

```
chgClock Frequenz = 640 kHz / (steps + 1)
```

| steps | Divisor | chgClock Frequenz | Periode |
|-------|---------|-------------------|---------|
| 0 | 1 | 640 kHz | 1.5625 µs |
| 1 | 2 | 320 kHz | 3.125 µs |
| 5 | 6 | 106.67 kHz | 9.375 µs |
| 10 | 11 | 58.18 kHz | 17.1875 µs |
| 15 | 16 | 40 kHz | 25 µs |
| 20 | 21 | 30.48 kHz | 32.8125 µs |
| 31 | 32 | 20 kHz | 50 µs |

### Vollständiger Amplituden-Zyklus (0→255→0):

**Dauer für einen kompletten Durchlauf**:

```
Zyklus-Dauer = 256 × (steps + 1) / 640 kHz
```

| steps | Zyklus-Dauer | Frequenz |
|-------|--------------|----------|
| 0 | 400 µs | 2.5 kHz |
| 5 | 2.4 ms | 416.67 Hz |
| 10 | 4.4 ms | 227.27 Hz |
| 15 | 6.4 ms | 156.25 Hz |
| 20 | 8.4 ms | 119.05 Hz |
| 31 | 12.8 ms | 78.125 Hz |

---

## Distribute.vhd - ampModStep Quelle

### Port-Definition:

```vhdl
ampModStep : out std_logic_vector(4 downto 0); -- 5 bits (0-31)
```

### Initialisierung:

```vhdl
signal s_ampModStep : std_logic_vector(4 downto 0) := "01010"; -- Default: 10
```

**Default-Wert**: 10 (binär: 01010)

### Steuerung via UART:

**Distribute.vhd** empfängt Befehle über UART und setzt `ampModStep`:

```vhdl
elsif (q_in(7 downto 5) = "101") then -- "101XXXXX" is step set
    s_ampModStep <= q_in(4 downto 0);
    s_ByteCounter <= 0;
    s_swap_out <= '0';
    s_set_out <= '0';
```

**UART-Befehl-Format**:

| Bits 7-5 | Bits 4-0 | Bedeutung |
|----------|----------|-----------|
| 101 | XXXXX | Set ampModStep = XXXXX |

**Beispiele**:
- `0xA0` (10100000) → ampModStep = 0 (schnellste Änderung)
- `0xA5` (10100101) → ampModStep = 5
- `0xAA` (10101010) → ampModStep = 10 (default)
- `0xAF` (10101111) → ampModStep = 15
- `0xBF` (10111111) → ampModStep = 31 (langsamste Änderung)

---

## ⚡ Verwendung in AllChannels.vhd - DAS IST DER SCHLÜSSEL!

**AllChannels.vhd** empfängt BEIDE Outputs von AmpModulator:

```vhdl
chgClock : in  STD_LOGIC;
pulse_length : in STD_LOGIC_VECTOR (7 downto 0);
```

### Der Toggle-Mechanismus (Zeile 95-99):

```vhdl
AllChannels: process (chgClock) begin
    if (rising_edge(chgClock)) then
        s_enabled( to_integer(unsigned(pulse_length)) ) <= NOT s_enabled( to_integer(unsigned(pulse_length)) );
    end if
end process;
```

### Was passiert hier?

1. **Bei jedem chgClock-Puls** (alle (steps+1) Zyklen bei 640 kHz)
2. **Wird der Emitter** mit Index **pulse_length** (= amp Wert 0-255)
3. **Ein- oder ausgeschaltet** (toggle: `NOT s_enabled(i)`)

### Beispiel-Ablauf (steps = 10):

| Zeit | amp | chgClock | Aktion |
|------|-----|----------|--------|
| 0 µs | 0 | 0→1 | Emitter 0: ON → OFF (oder OFF → ON) |
| 17.2 µs | 1 | 0→1 | Emitter 1: Toggle |
| 34.4 µs | 2 | 0→1 | Emitter 2: Toggle |
| ... | ... | ... | ... |
| 4.4 ms | 255 | 0→1 | Emitter 255: Toggle |
| 4.4 ms | 0 | 0→1 | Emitter 0: Toggle (wieder) |

**Ergebnis**: Ein **sequenzieller Scan** durch alle 256 Emitter, wobei jeder Emitter bei jedem Durchlauf getoggled wird!

---

## ⚡ WICHTIGE ENTDECKUNG: Taktile Modulation durch sequenzielles Toggle!

**AmpModulator.amp** wird zu **AllChannels.pulse_length** verbunden!

### Was bedeutet das?

1. **AmpModulator zählt intern** von 0 bis 255
2. **amp Output** wird als **Emitter-Index** verwendet
3. **chgClock** triggert das **Toggle-Event**
4. **Ergebnis**: Sequenzielles Ein-/Ausschalten aller 256 Emitter

### Warum "AmpModulator"?

Der Name ist **irreführend**! Es ist KEINE Amplitudenmodulation, sondern:
- **Sequenzieller Scan** durch alle Emitter
- **Toggle-Mechanismus** für taktile Effekte
- **Programmierbare Geschwindigkeit** (via steps)

**Tatsächliche Funktion**:
- Erzeugt eine **Vibrations-Welle** durch die Emitter-Array
- Geschwindigkeit steuerbar via UART (steps = 0-31)
- Frequenz des Scans: 78 Hz bis 2.5 kHz (für kompletten Durchlauf)

---

## Signal-Fluss-Diagramm

```
UART (230.4 kBaud)
    ↓
UARTReader
    ↓
o_RX_Byte[7..0]
    ↓
Distribute.q_in[7..0]
    ↓
[Decode: "101XXXXX"]
    ↓
Distribute.ampModStep[4..0]  (Default: 10)
    ↓
AmpModulator.steps[4..0]
    ↓
┌─────────────────────────────────────┐
│ AmpModulator                        │
│                                     │
│ clk = COUNT[2] (640 kHz)           │
│ steps = ampModStep (0-31)          │
│                                     │
│ s_stepCounter: 0 → steps → 0      │
│ s_counter: 0 → 255 → 0             │
│                                     │
│ When s_stepCounter = steps:        │
│   - chgClock = HIGH (1 cycle)      │
│   - s_counter++                    │
│   - amp = s_counter                │
│                                     │
└─────────────────────────────────────┘
    ↓                    ↓
    amp[7..0]        chgClock
    ↓                    ↓
AllChannels.pulse_length[7..0]  AllChannels.chgClock
    ↓                    ↓
    └────────┬───────────┘
             ↓
    ┌───────────────────────────────┐
    │ AllChannels Process:          │
    │                               │
    │ if rising_edge(chgClock) then │
    │   s_enabled(pulse_length)     │
    │     <= NOT s_enabled(...)     │
    │ end if                        │
    │                               │
    │ TOGGLE Emitter #pulse_length! │
    └───────────────────────────────┘
             ↓
    Emitter 0, 1, 2, ..., 255
    (sequenziell getoggled)
```

---

## Zusammenfassung

### Was AmpModulator tut:

1. **Zählt** von 0 bis 255 mit konfigurierbarer Geschwindigkeit
2. **Generiert** einen Puls (`chgClock`) bei jeder Zähler-Änderung
3. **Steuert** sequenziell alle 256 Emitter (Toggle-Mechanismus)
4. **Erzeugt** taktile Vibrations-Effekte durch die Emitter-Array

### Was AmpModulator NICHT tut:

1. **Moduliert NICHT** die Amplitude der Emitter-Pulse (trotz des Namens!)
2. **Ändert NICHT** die Puls-Stärke oder -Länge
3. **Beeinflusst NICHT** die Phase der Emitter

### Aktueller Zweck:

**Sequenzieller Emitter-Toggle** mit UART-Steuerung:
- Schaltet Emitter sequenziell ein/aus (0→1→2→...→255→0)
- Toggle-Frequenz: 20 kHz bis 640 kHz (pro Emitter)
- Scan-Frequenz: 78 Hz bis 2.5 kHz (kompletter Durchlauf)
- Erzeugt **taktile Vibrations-Wellen** durch die Array

### Anwendungen:

- **Taktile Feedback-Effekte** (Vibration, Textur)
- **Bewegungs-Simulation** (Wellen, Strömungen)
- **Aufmerksamkeits-Signale** (pulsierende Bereiche)
- **Dynamische Intensitäts-Modulation** (durch Toggle-Frequenz)

---

**Erstellt**: 2026-01-20
**Aktualisiert**: 2026-01-20 (Korrektur nach Hinweis des Benutzers!)
**Zweck**: Vollständige Analyse von AmpModulator und seinen Verbindungen
**Status**: ✅ Dokumentiert - amp und chgClock werden für sequenzielles Emitter-Toggle verwendet!

---

## 🙏 Danke für die Korrektur!

**Ursprünglicher Fehler**: Ich hatte behauptet, dass `amp` ungenutzt sei.

**Tatsache**: `amp` ist verbunden zu `AllChannels.pulse_length[7..0]` und wird aktiv verwendet!

**Verbindung in QuadrupleBuffer.bdf**:
```
AmpModulator.amp[7..0] (pt 272 48)
  → (pt 288 48)
  → (pt 288 208)
  → (pt 400 208)
  → AllChannels.pulse_length[7..0]
```

**Verwendung in AllChannels.vhd (Zeile 95-99)**:
```vhdl
AllChannels: process (chgClock) begin
    if (rising_edge(chgClock)) then
        s_enabled( to_integer(unsigned(pulse_length)) ) <= NOT s_enabled( to_integer(unsigned(pulse_length)) );
    end if
end process;
```

**Funktion**: Sequenzielles Toggle der Emitter für taktile Modulation!


