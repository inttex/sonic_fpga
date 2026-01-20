# AmpModulator Analysis - Amplitude Modulation System

## 🎯 Executive Summary

**AmpModulator** ist ein Modul zur **Amplitudenmodulation** der Emitter-Signale.

**Funktion**: Generiert einen langsam ansteigenden Amplitudenwert (0-255) mit konfigurierbarer Geschwindigkeit.

**Zweck**: Ermöglicht sanfte Amplitudenänderungen (Fade-In/Fade-Out) für die Emitter.

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
   - Aktueller Amplitudenwert
   - Zählt von 0 bis 255, dann wieder von 0
   - **Verwendung**: Wird NICHT in QuadrupleBuffer verwendet! (Ungenutzt)

2. **chgClock** (1 bit)
   - Puls-Signal, das bei jeder Amplitudenänderung HIGH wird
   - **Verbindung in QuadrupleBuffer.bdf**: `AllChannels.chgClock`
   - Dauer: 1 Clock-Zyklus HIGH, dann LOW bis zur nächsten Änderung

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
- **amp[7..0]** → **UNGENUTZT!**
  - Kein Connector gefunden in QuadrupleBuffer.bdf

- **chgClock** → `AllChannels.chgClock`
  - Connector: (pt 272 64) → (pt 304 64) → (pt 304 176) → (pt 400 176)

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

## Verwendung von chgClock in AllChannels

**AllChannels.vhd** empfängt `chgClock` als Input:

```vhdl
chgClock : in  STD_LOGIC;
```

**ABER**: In der aktuellen Implementierung wird `chgClock` **NICHT verwendet**!

### Mögliche zukünftige Verwendung:

`chgClock` könnte verwendet werden, um:
1. **Amplitudenmodulation** der Pulse zu synchronisieren
2. **Fade-In/Fade-Out** Effekte zu steuern
3. **Zeitgesteuerte Änderungen** der Emitter-Parameter

**Aktueller Status**: Ungenutzt (potenzielle zukünftige Erweiterung)

---

## ⚠️ WICHTIGE ENTDECKUNG: amp Output ist ungenutzt!

**AmpModulator.amp** wird in QuadrupleBuffer.bdf **NICHT verbunden**!

### Was bedeutet das?

1. **AmpModulator zählt intern** von 0 bis 255
2. **amp Output** wird generiert, aber nirgendwo verwendet
3. **Nur chgClock** wird verwendet (als Timing-Signal)

### Warum?

**Vermutung**: AmpModulator wurde ursprünglich für Amplitudenmodulation entwickelt, aber:
- Die tatsächliche Amplitudensteuerung erfolgt möglicherweise anders
- Oder: Die Funktion ist noch nicht implementiert
- Oder: `chgClock` wird für andere Zwecke verwendet (z.B. Synchronisation)

**Aktuell**: AmpModulator dient hauptsächlich als **programmierbarer Taktteiler**:
- Input: 640 kHz (COUNT[2])
- Output: chgClock mit Frequenz = 640 kHz / (steps + 1)

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
    (UNGENUTZT!)         ↓
                    AllChannels.chgClock
                    (UNGENUTZT!)
```

---

## Zusammenfassung

### Was AmpModulator tut:

1. **Zählt** von 0 bis 255 mit konfigurierbarer Geschwindigkeit
2. **Generiert** einen Puls (`chgClock`) bei jeder Zähler-Änderung
3. **Teilt** die 640 kHz Clock durch (steps + 1)

### Was AmpModulator NICHT tut:

1. **Moduliert NICHT** die Amplitude der Emitter-Pulse (amp ist ungenutzt)
2. **Beeinflusst NICHT** direkt die Emitter-Ausgänge
3. **Wird NICHT** für die Haupt-Puls-Generierung verwendet

### Aktueller Zweck:

**Programmierbarer Taktteiler** mit UART-Steuerung:
- Erzeugt ein Timing-Signal (chgClock) mit variabler Frequenz
- Frequenz-Bereich: 20 kHz bis 640 kHz
- Steuerbar über UART-Befehle

### Potenzielle zukünftige Verwendung:

- **Amplitudenmodulation** der Emitter (wenn amp Output verbunden wird)
- **Fade-Effekte** (sanfte Übergänge)
- **Zeitgesteuerte Änderungen** (synchronisiert mit chgClock)

---

**Erstellt**: 2026-01-20
**Zweck**: Vollständige Analyse von AmpModulator und seinen Verbindungen
**Status**: ✅ Dokumentiert - amp und chgClock sind aktuell ungenutzt!


