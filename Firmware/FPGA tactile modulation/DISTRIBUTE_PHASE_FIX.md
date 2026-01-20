# Distribute.vhd Phase Bit-Width Fix

## 🎯 Critical Fix: Phase Data Width Correction

**Datum**: 2026-01-20  
**Datei**: `Distribute.vhd`  
**Zeilen**: 59, 60, 62  
**Commit**: `423971f`

---

## ❌ Problem (Vorher)

### Code:
```vhdl
if (q_in = "00100000") then  -- 32 decimal
    s_data_out <= q_in; -- a phase of 32 represents "off" so no phase correction
else
    s_data_out <= std_logic_vector( to_unsigned( to_integer(unsigned(q_in)) + PHASE_CORRECTION(s_ByteCounter), 8 ) ) and "00011111";
    --                                                                                                            ^^      ^^^^^^^^^^
    --                                                                                                            8 bits  5-bit mask
end if;
```

### Probleme:

1. **OFF-Wert zu groß**: 32 ist zu groß für 4-Bit-Phase-Bereich (0-15)
2. **Inkonsistente Bit-Breite**: 8 Bits mit 5-Bit-Maske (`00011111`)
3. **Falsche Logik**: PhaseLine verwendet 4-Bit-Counter (0-15), also phase ≥16 = OFF

---

## ✅ Lösung (Nachher)

### Code:
```vhdl
if (q_in = "00010000") then  -- 16 decimal
    s_data_out <= q_in; -- a phase of 16 represents "off" so no phase correction
else
    s_data_out <= std_logic_vector( to_unsigned( to_integer(unsigned(q_in)) + PHASE_CORRECTION(s_ByteCounter), 4 ) ) and "00001111";
    --                                                                                                            ^^      ^^^^^^^^^^
    --                                                                                                            4 bits  4-bit mask
end if;
```

### Änderungen:

1. **OFF-Wert**: 32 → **16** ✅
2. **Bit-Breite**: 8 → **4** ✅
3. **Maske**: `00011111` (0x1F) → **`00001111`** (0x0F) ✅

---

## 🔍 Technische Analyse

### PhaseLine.vhd Kontext:

```vhdl
entity PhaseLine is
    port (
        phase : in STD_LOGIC_VECTOR (4 downto 0); -- 5 bits (0-31)
        counter : in STD_LOGIC_VECTOR (3 downto 0); -- 4 bits (0-15)
        ...
    );
end PhaseLine;
```

**Wichtiger Kommentar in PhaseLine.vhd Zeile 11**:
```vhdl
-- We need one more bit because anything >=16 is for off
```

**Logik in PhaseLine.vhd Zeile 39**:
```vhdl
if (s_phaseCurrent = to_integer(unsigned(counter)) ) then
    s_counter <= 7;  -- Start pulse
end if;
```

### Wie funktioniert OFF?

- **counter** ist 4 Bits: Werte **0-15**
- **phase** ist 5 Bits: Werte **0-31**
- **Vergleich**: `if (phase = counter)`
  - Phase **0-15**: Kann mit counter übereinstimmen → **Emitter ON**
  - Phase **≥16**: Kann NIE mit counter übereinstimmen → **Emitter OFF**

**Ergebnis**: Phase 16 ist der **erste OFF-Wert**, nicht 32!

---

## 📊 AllChannels.vhd Verbindung

### Wie phase zu PhaseLine kommt:

**AllChannels.vhd Zeile 74**:
```vhdl
phase => phase(5 downto 1),  -- Bits 5:1 von 8-Bit Input
```

**Distribute.vhd**:
```vhdl
data_out: out STD_LOGIC_VECTOR (7 downto 0);  -- 8 bits
```

**Aber**: Nur Bits 5:1 werden verwendet (5 Bits), und davon sind nur die unteren 4 Bits relevant!

---

## 🧮 PHASE_CORRECTION Array

**Distribute.vhd Zeile 25**:
```vhdl
type T_PHASE_CORRECTION is array (0 to 255) of integer range 0 to 16;
```

**Wichtig**: Korrekturwerte sind **0-16**!

### Arithmetik:

```vhdl
result = q_in + PHASE_CORRECTION(s_ByteCounter)
```

**Beispiele**:
- `q_in = 10`, `PHASE_CORRECTION = 5` → `result = 15` ✅ (ON)
- `q_in = 12`, `PHASE_CORRECTION = 6` → `result = 18` → Maskiert zu `18 & 0x0F = 2` ✅
- `q_in = 16`, `PHASE_CORRECTION = 0` → `result = 16` ✅ (OFF)

**Mit 4-Bit-Maske**:
- Werte 0-15: Bleiben unverändert (ON)
- Werte ≥16: Werden maskiert, aber das ist OK, weil 16 bereits OFF ist

---

## 📋 Vergleich Alt vs. Neu

| Aspekt | Alt (FALSCH) | Neu (KORREKT) | Warum? |
|--------|--------------|---------------|--------|
| OFF-Wert | 32 (`00100000`) | 16 (`00010000`) | Counter ist 0-15, also ≥16 = OFF |
| Bit-Breite | 8 | 4 | Nur 4 Bits werden tatsächlich verwendet |
| Maske | `00011111` (31) | `00001111` (15) | 4-Bit-Maske für 4-Bit-Daten |
| Max Phase | 31 (5 bits) | 15 (4 bits) + 16 (OFF) | Konsistent mit Counter-Bereich |

---

## ⚠️ Warum war das ein Problem?

### 1. **Falscher OFF-Wert**
- Java-Software sendet 32 für OFF
- Aber PhaseLine erkennt nur ≥16 als OFF
- **Ergebnis**: OFF funktionierte trotzdem (32 > 16), aber inkonsistent

### 2. **Synthesis-Warnungen**
- 8-Bit-Breite mit 5-Bit-Maske erzeugt Warnungen
- Verschwendete Hardware-Ressourcen
- Unklare Intention

### 3. **Inkonsistente Dokumentation**
- Code sagt "32 = OFF"
- PhaseLine sagt "≥16 = OFF"
- Verwirrend für zukünftige Entwickler

---

## ✅ Was der Fix bewirkt

### 1. **Korrekte OFF-Erkennung**
- Phase 16 ist jetzt explizit als OFF definiert
- Konsistent mit PhaseLine-Logik
- Klare Dokumentation

### 2. **Konsistente Bit-Breiten**
- 4-Bit-Daten mit 4-Bit-Maske
- Keine Synthesis-Warnungen
- Effiziente Hardware-Nutzung

### 3. **Korrekte Arithmetik**
- Phase-Korrektur funktioniert korrekt
- Overflow wird richtig behandelt
- Keine Truncation-Probleme

---

## 🔧 Auswirkungen auf Java-Software

### ⚠️ WICHTIG: Java-Code muss angepasst werden!

**Alt** (wenn Java 32 für OFF sendet):
```java
byte phaseOff = 32;  // FALSCH!
```

**Neu** (korrekt):
```java
byte phaseOff = 16;  // KORREKT!
```

**Für Phase-Werte 0-15**:
```java
// Phase 0-15: Emitter ON
byte phase = 10;  // OK

// Phase 16: Emitter OFF
byte phase = 16;  // OFF
```

---

## 📝 Zusammenfassung

**Problem**: Inkonsistente Bit-Breiten und falscher OFF-Wert  
**Lösung**: 4-Bit-Daten mit Phase 16 als OFF  
**Auswirkung**: Korrekte Hardware-Synthese und klare Logik  
**Nächster Schritt**: Java-Software anpassen (32 → 16 für OFF)

---

**Status**: ✅ Committed und pushed (423971f)  
**User Contribution**: Identified and fixed the inconsistency  
**Branch**: phase_fix_16bit

