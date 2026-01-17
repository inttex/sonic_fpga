# WaveDrom Syntax Quick Reference

This guide shows you how to create and modify WaveDrom timing diagrams for your FPGA documentation.

---

## Basic Structure

```wavedrom
{
  signal: [
    {name: 'signal_name', wave: 'pattern'},
    {name: 'another_signal', wave: 'pattern', data: ['A','B','C']}
  ],
  config: { hscale: 2 },
  head: {
    text: 'Diagram Title',
    tick: 0
  }
}
```

---

## Wave Patterns

### Basic Patterns

| Character | Meaning | Visual |
|-----------|---------|--------|
| `p` | Positive clock edge | ┌┐┌┐┌┐ |
| `n` | Negative clock edge | ┐┌┐┌┐┌ |
| `P` | Positive clock (caps) | ┌──┐┌──┐ |
| `N` | Negative clock (caps) | ┐┌──┐┌── |
| `1` | High | ────── |
| `0` | Low | ────── |
| `.` | Continue previous | (extends) |
| `x` | Unknown/Don't care | xxxxxx |
| `z` | High impedance | zzzzzz |
| `=` | Data (with label) | ══════ |
| `2` | Data value 0 | ══════ |
| `3` | Data value 1 | ══════ |
| `4` | Data value 2 | ══════ |
| `5` | Data value 3 | ══════ |

### Examples

```wavedrom
{
  signal: [
    {name: 'clock', wave: 'p......'},
    {name: 'high', wave: '1......'},
    {name: 'low', wave: '0......'},
    {name: 'pulse', wave: '01.0...'},
    {name: 'data', wave: 'x2345x', data: ['A','B','C','D']}
  ]
}
```

---

## Timing Control

### Period (Horizontal Scaling)

```wavedrom
{
  signal: [
    {name: 'fast', wave: 'p.......', period: 0.5},
    {name: 'normal', wave: 'p.......', period: 1},
    {name: 'slow', wave: 'p.......', period: 2}
  ]
}
```

- `period: 0.5` = half width (faster)
- `period: 1` = normal width (default)
- `period: 2` = double width (slower)

### Global Horizontal Scale

```wavedrom
{
  signal: [...],
  config: { hscale: 2 }  // Makes entire diagram 2× wider
}
```

---

## Data Labels

### Adding Data Values

```wavedrom
{
  signal: [
    {name: 'address', wave: 'x2222x', data: ['0x00','0x01','0x02','0x03']},
    {name: 'data', wave: 'x3333x', data: ['A','B','C','D']}
  ]
}
```

**Key Points**:
- Use `2`, `3`, `4`, `5`, etc. for data states
- Provide labels in `data: [...]` array
- Number of data labels should match number of data states

---

## Grouping Signals

```wavedrom
{
  signal: [
    {name: 'clk', wave: 'p......'},
    {},  // Empty line for spacing
    ['Group Name',
      {name: 'signal1', wave: '01.0...'},
      {name: 'signal2', wave: '0..10..'}
    ],
    {},
    ['Another Group',
      {name: 'signal3', wave: '1.0....'}
    ]
  ]
}
```

---

## Edges and Annotations

### Adding Nodes

```wavedrom
{
  signal: [
    {name: 'clk', wave: 'p......', node: '.a.....'},
    {name: 'data', wave: '0.1..0.', node: '..b...c'}
  ],
  edge: [
    'a~>b Rising edge',
    'b~>c Falling edge'
  ]
}
```

**Node Placement**:
- `.` = no node
- `a`, `b`, `c`, etc. = node markers

**Edge Types**:
- `a~>b` = Arrow from a to b
- `a-~>b` = Dashed arrow
- `a~b` = Line (no arrow)

---

## Common FPGA Patterns

### Clock Signal

```wavedrom
{name: 'clk', wave: 'p...............', period: 0.5}
```

### Counter

```wavedrom
{name: 'counter', wave: 'x2222222x', data: ['0','1','2','3','4','5','6','7'], period: 0.5}
```

### Pulse (triggered by event)

```wavedrom
{name: 'pulse', wave: '0....1.....0....', node: '.....a.....b'}
```

### Phase-shifted signals

```wavedrom
{
  signal: [
    {name: 'phase0', wave: '01.....0........'},
    {name: 'phase1', wave: '0..1.....0......'},
    {name: 'phase2', wave: '0....1.....0....'}
  ]
}
```

---

## Real Example from Your Project

### Counter and Phase Division

```wavedrom
{
  signal: [
    {name: 'clk (5.12MHz)', wave: 'p...............', period: 0.5},
    {},
    {name: 'counter[6:0]', wave: 'x2222222222222x', data: ['0','1','2','3','4','5','6','7','8','...','125','126','127','0'], period: 0.5},
    {},
    {name: 'counter[6:3]', wave: 'x2.......3.....4', data: ['0','1','2'], period: 4}
  ],
  config: { hscale: 2 },
  head: {
    text: 'Counter Generation: 7-bit counter creates 40kHz period (25µs)',
    tick: 0
  }
}
```

**Explanation**:
- `clk`: Clock with `p` pattern, `period: 0.5` makes it faster
- `counter[6:0]`: Data values changing every clock
- `counter[6:3]`: Slower changes with `period: 4` (4× slower)
- `hscale: 2`: Makes entire diagram 2× wider for readability

---

## Tips for Your FPGA Diagrams

1. **Use `period` to show different clock domains**
   - Master clock: `period: 0.5`
   - Phase divisions: `period: 4` (8× slower)

2. **Use nodes and edges for timing measurements**
   ```wavedrom
   {name: 'pulse', wave: '0.1....0', node: '..a....b'},
   edge: ['a~>b 1.367µs']
   ```

3. **Group related signals**
   ```wavedrom
   ['PhaseLine Signals',
     {name: 'match', wave: '...'},
     {name: 's_counter', wave: '...'},
     {name: 'pulse', wave: '...'}
   ]
   ```

4. **Use empty `{}` for visual spacing**

5. **Add descriptive titles**
   ```wavedrom
   head: {
     text: 'Detailed description of what this shows',
     tick: 0
   }
   ```

---

## Testing Your Diagrams

1. **Online Editor**: https://wavedrom.com/editor.html
   - Paste your code
   - See instant preview
   - Export as SVG/PNG if needed

2. **GitHub**: Push `.md` files with WaveDrom blocks
   - GitHub renders them automatically
   - No plugins needed

3. **VS Code**: Install "WaveDrom" extension
   - Preview in editor
   - Export diagrams

---

## Common Mistakes to Avoid

❌ **Mismatched data labels**
```wavedrom
{name: 'data', wave: 'x2222x', data: ['A','B']}  // 4 states, only 2 labels!
```

✅ **Correct**
```wavedrom
{name: 'data', wave: 'x2222x', data: ['A','B','C','D']}  // 4 states, 4 labels
```

❌ **Forgetting commas**
```wavedrom
{
  signal: [
    {name: 'clk', wave: 'p...'}
    {name: 'data', wave: '01..'}  // Missing comma!
  ]
}
```

✅ **Correct**
```wavedrom
{
  signal: [
    {name: 'clk', wave: 'p...'},
    {name: 'data', wave: '01..'}
  ]
}
```

---

## Document Information

- **Created**: 2026-01-17
- **Purpose**: Quick reference for creating WaveDrom timing diagrams
- **Official Docs**: https://wavedrom.com/tutorial.html

