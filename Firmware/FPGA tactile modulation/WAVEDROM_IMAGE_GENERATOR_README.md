# WaveDrom Image Generator - Setup & Usage

## Overview

This tool automatically generates SVG images from WaveDrom code blocks in your markdown files and updates the markdown to display them on GitHub.

---

## Prerequisites

You need **Node.js** installed on your system.

### Check if Node.js is installed:
```bash
node --version
```

If not installed, download from: https://nodejs.org/

---

## Setup (One-Time)

### Step 1: Install Dependencies

Open a terminal in this directory and run:

```bash
npm install
```

This will install the `wavedrom` package needed to generate SVG files.

---

## Usage

### Generate All Diagrams

Run the generator script:

```bash
npm run generate
```

Or directly:

```bash
node generate-wavedrom-images.js
```

### What It Does

1. ✅ Scans all markdown files for WaveDrom code blocks
2. ✅ Generates SVG images for each diagram
3. ✅ Saves SVGs to `wavedrom-images/` folder
4. ✅ Updates markdown files to include image references

### Files Processed

- `PHASE_SIGNAL_PATH_DOCUMENTATION.md`
- `DUTY_CYCLE_CORRECTION.md`
- `DUTY_CYCLE_FIX_IMPLEMENTATION.md`
- `MUX8_ANALYSIS.md`
- `WAVEDROM_DIAGRAMS_SUMMARY.md`

---

## Output

### Generated Files

All SVG images are saved to:
```
wavedrom-images/
├── PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-1.svg
├── PHASE_SIGNAL_PATH_DOCUMENTATION-diagram-2.svg
├── DUTY_CYCLE_CORRECTION-diagram-1.svg
├── ...
```

### Updated Markdown

Each WaveDrom code block will have an image reference added after it:

```markdown
```wavedrom
{
  signal: [...]
}
```

**Rendered Diagram** (GitHub):

![WaveDrom Diagram](./wavedrom-images/filename-diagram-1.svg)
```

---

## Workflow

### Initial Setup
```bash
# 1. Install dependencies
npm install

# 2. Generate all diagrams
npm run generate

# 3. Review the generated SVGs
# Check the wavedrom-images/ folder

# 4. Commit everything
git add wavedrom-images/
git add *.md
git commit -m "Add WaveDrom SVG diagrams"

# 5. Push to GitHub
git push
```

### After Editing WaveDrom Code

If you modify any WaveDrom diagrams in the markdown:

```bash
# 1. Clean old images (optional)
npm run clean

# 2. Regenerate all diagrams
npm run generate

# 3. Commit and push
git add wavedrom-images/ *.md
git commit -m "Update WaveDrom diagrams"
git push
```

---

## Troubleshooting

### Error: "WaveDrom not found"

**Solution**: Install dependencies
```bash
npm install
```

### Error: "node: command not found"

**Solution**: Install Node.js from https://nodejs.org/

### Diagrams not rendering on GitHub

**Possible causes**:
1. SVG files not committed to repository
2. Image paths incorrect (should be relative: `./wavedrom-images/...`)
3. GitHub caching (wait a few minutes or hard refresh)

### Want to regenerate everything

```bash
# Clean all generated images
npm run clean

# Generate fresh
npm run generate
```

---

## File Structure

```
Firmware/FPGA tactile modulation/
├── generate-wavedrom-images.js    # Generator script
├── package.json                    # Node.js dependencies
├── wavedrom-images/                # Generated SVG files (created by script)
│   ├── *.svg
├── PHASE_SIGNAL_PATH_DOCUMENTATION.md
├── DUTY_CYCLE_CORRECTION.md
├── ...
```

---

## How It Works

1. **Scans** markdown files for WaveDrom code blocks (```wavedrom ... ```)
2. **Parses** the JSON inside each block
3. **Renders** using the WaveDrom library
4. **Saves** as SVG files with descriptive names
5. **Updates** markdown to include image references

---

## Benefits

✅ **GitHub Compatible** - SVG images render perfectly on GitHub  
✅ **Automated** - No manual export needed  
✅ **Preserves Code** - WaveDrom blocks remain for editing  
✅ **Version Controlled** - SVG files tracked in Git  
✅ **Reproducible** - Regenerate anytime with one command  

---

## Next Steps

After running the generator:

1. ✅ Review generated SVG files in `wavedrom-images/`
2. ✅ Commit both the images and updated markdown files
3. ✅ Push to GitHub
4. ✅ View your documentation on GitHub to see rendered diagrams!

---

## Support

If you encounter issues:
1. Check Node.js is installed: `node --version`
2. Check dependencies are installed: `npm list wavedrom`
3. Try cleaning and regenerating: `npm run clean && npm run generate`

---

**Happy diagramming! 🎉**

