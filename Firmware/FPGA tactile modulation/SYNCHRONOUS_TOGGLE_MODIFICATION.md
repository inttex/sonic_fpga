# Synchronous Emitter Toggle Modification

## 🎯 Änderung: Von sequenziellem zu synchronem Toggle

**Datum**: 2026-01-20  
**Datei**: `AllChannels.vhd`  
**Zeilen**: 95-102

---

## Vorher: Sequenzielles Toggle (Original)

### Code:
```vhdl
AllChannels: process (chgClock) begin 
    if (rising_edge(chgClock)) then
        s_enabled( to_integer(unsigned(pulse_length)) ) <= NOT s_enabled( to_integer(unsigned(pulse_length)) );
    end if;
end process;
```

### Verhalten:
- **Ein Emitter** pro chgClock-Puls wird getoggled
- Emitter-Index bestimmt durch `pulse_length` (= AmpModulator.amp)
- Sequenzieller Scan: 0→1→2→...→255→0
- **Ergebnis**: Vibrations-Welle durch die Array

### Frequenzen:
- Toggle pro Emitter: 20 kHz - 640 kHz (abhängig von steps)
- Scan-Durchlauf: 78 Hz - 2.5 kHz

---

## Nachher: Synchrones Toggle (Modifiziert)

### Code:
```vhdl
AllChannels: process (chgClock) begin 
    if (rising_edge(chgClock)) then
        if (pulse_length = "00000000") then
            -- Toggle ALL emitters synchronously when pulse_length = 0
            s_enabled <= NOT s_enabled;
        end if;
    end if;
end process;
```

### Verhalten:
- **Alle 256 Emitter** werden gleichzeitig getoggled
- Trigger: Wenn `pulse_length = 0` (d.h. AmpModulator.amp = 0)
- Passiert **einmal pro AmpModulator-Zyklus** (alle 256 chgClock-Pulse)
- **Ergebnis**: Synchrone Modulation aller Emitter

### Frequenzen:
```
Toggle-Frequenz = 640 kHz / (256 × (steps + 1))
```

| steps | Toggle-Frequenz | Periode | UART-Befehl |
|-------|-----------------|---------|-------------|
| 0 | 2.5 kHz | 400 µs | 0xA0 |
| 5 | 416.67 Hz | 2.4 ms | 0xA5 |
| **10** | **227.27 Hz** | **4.4 ms** | **0xAA** (Default) |
| 15 | 156.25 Hz | 6.4 ms | 0xAF |
| 20 | 119.05 Hz | 8.4 ms | 0xB4 |
| 31 | 78.125 Hz | 12.8 ms | 0xBF |

---

## 🔍 Wie funktioniert der Trigger?

### AmpModulator-Zyklus:

| chgClock Puls | amp (pulse_length) | Aktion |
|---------------|-------------------|--------|
| 0 | 0 | ✅ **Toggle ALLE Emitter!** |
| 1 | 1 | ❌ Nichts (pulse_length ≠ 0) |
| 2 | 2 | ❌ Nichts |
| 3 | 3 | ❌ Nichts |
| ... | ... | ... |
| 255 | 255 | ❌ Nichts |
| 256 | 0 | ✅ **Toggle ALLE Emitter!** |
| 257 | 1 | ❌ Nichts |

**Ergebnis**: Alle 256 chgClock-Pulse wird einmal getoggled.

---

## 📊 Timing-Beispiel (steps = 10)

### chgClock-Frequenz:
```
640 kHz / (10 + 1) = 58.18 kHz
Periode: 17.19 µs
```

### Toggle-Ereignis:
```
256 × 17.19 µs = 4.4 ms
Frequenz: 227.27 Hz
```

### Zeitlicher Ablauf:

| Zeit | amp | chgClock | Alle Emitter |
|------|-----|----------|--------------|
| 0.00 ms | 0 | ↑ | **Toggle!** (ON↔OFF) |
| 0.02 ms | 1 | ↑ | - |
| 0.03 ms | 2 | ↑ | - |
| ... | ... | ... | ... |
| 4.38 ms | 255 | ↑ | - |
| **4.40 ms** | **0** | **↑** | **Toggle!** |
| 4.42 ms | 1 | ↑ | - |

---

## 🎯 Anwendungen

### Synchrone Modulation:
- ✅ Alle Emitter schwingen mit gleicher Frequenz
- ✅ Perfekt für **Amplitudenmodulation** (AM)
- ✅ Erzeugt **gleichmäßige taktile Vibration**
- ✅ Keine Phasenverschiebung zwischen Emittern

### Steuerung via UART:
- Sende `0xA0` (steps=0) → 2.5 kHz Toggle
- Sende `0xAA` (steps=10) → 227 Hz Toggle (Default)
- Sende `0xBF` (steps=31) → 78 Hz Toggle

### Mögliche Effekte:
1. **Niederfrequente Vibration** (78-227 Hz)
   - Taktiles Feedback
   - Haptische Signale

2. **Mittelfrequente Modulation** (227-416 Hz)
   - Textur-Simulation
   - Dynamische Effekte

3. **Hochfrequente Modulation** (416 Hz - 2.5 kHz)
   - Feine Vibrationen
   - Schnelle Puls-Effekte

---

## ⚠️ Wichtige Hinweise

### 1. AmpModulator muss laufen
- Der Toggle erfolgt nur, wenn AmpModulator aktiv ist
- AmpModulator zählt kontinuierlich 0→255→0
- Bei amp=0 erfolgt der Toggle

### 2. Frequenz-Bereich
- **Minimum**: 78 Hz (steps=31)
- **Maximum**: 2.5 kHz (steps=0)
- **Default**: 227 Hz (steps=10)

### 3. Duty Cycle
- Toggle bedeutet: ON→OFF oder OFF→ON
- Bei kontinuierlichem Toggle: 50% Duty Cycle
- Emitter sind abwechselnd ON/OFF

---

## 🔧 VHDL-Details

### Parallele Zuweisung:
```vhdl
s_enabled <= NOT s_enabled;
```

**Was passiert hier?**
- `s_enabled` ist ein `STD_LOGIC_VECTOR(255 downto 0)`
- `NOT s_enabled` invertiert **alle 256 Bits gleichzeitig**
- Parallele Hardware-Operation (1 Clock-Zyklus)

**Äquivalent zu**:
```vhdl
for i in 0 to 255 loop
    s_enabled(i) <= NOT s_enabled(i);
end loop;
```

Aber die parallele Zuweisung ist:
- ✅ Kürzer
- ✅ Klarer
- ✅ Synthesiert zu gleicher Hardware

---

## 📝 Zusammenfassung

**Änderung**: Von sequenziellem zu synchronem Toggle  
**Trigger**: pulse_length = 0 (einmal pro AmpModulator-Zyklus)  
**Frequenz**: 78 Hz - 2.5 kHz (steuerbar via UART)  
**Effekt**: Alle 256 Emitter schwingen synchron  
**Anwendung**: Taktile Modulation, Vibrations-Effekte

---

**Status**: ✅ Implementiert in AllChannels.vhd (Zeilen 95-102)

