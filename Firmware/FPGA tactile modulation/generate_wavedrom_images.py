#!/usr/bin/env python3
"""
WaveDrom SVG Generator (Python Version)

This script:
1. Scans markdown files for WaveDrom code blocks
2. Generates SVG images using the wavedrom Python package
3. Updates markdown files to include image references

Usage: python generate_wavedrom_images.py
"""

import os
import re
import json
import sys
from pathlib import Path

try:
    import wavedrom
except ImportError:
    print("❌ Error: wavedrom package not found!")
    print("Please install it with: pip install wavedrom")
    sys.exit(1)

# Configuration
MARKDOWN_FILES = [
    'PHASE_SIGNAL_PATH_DOCUMENTATION.md',
    'DUTY_CYCLE_CORRECTION.md',
    'DUTY_CYCLE_FIX_IMPLEMENTATION.md',
    'MUX8_ANALYSIS.md',
    'WAVEDROM_DIAGRAMS_SUMMARY.md'
]

IMAGE_DIR = 'wavedrom-images'
SCRIPT_DIR = Path(__file__).parent

def create_image_dir():
    """Create image directory if it doesn't exist"""
    image_path = SCRIPT_DIR / IMAGE_DIR
    image_path.mkdir(exist_ok=True)
    print(f"✅ Image directory ready: {IMAGE_DIR}/")
    return image_path

def extract_wavedrom_blocks(content):
    """Extract WaveDrom code blocks from markdown content"""
    pattern = r'```wavedrom\n([\s\S]*?)\n```'
    blocks = []
    
    for match in re.finditer(pattern, content):
        blocks.append({
            'full_match': match.group(0),
            'json': match.group(1),
            'start_pos': match.start()
        })
    
    return blocks

def fix_wavedrom_json(wavedrom_text):
    """Convert JavaScript-style object notation to strict JSON"""
    import re

    # Step 1: Add quotes around unquoted property names
    # Pattern to match unquoted keys like: name: 'value' or name: value
    # Replace with: "name": 'value' or "name": value
    pattern = r'(\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:'
    fixed = re.sub(pattern, r'\1"\2":', wavedrom_text)

    # Step 2: Replace single quotes with double quotes for string values
    fixed = fixed.replace("'", '"')

    # Step 3: Fix array labels - WaveDrom allows ['Label', {...}] syntax
    # This is valid in WaveDrom but we need to ensure proper JSON formatting
    # The wavedrom library should handle this, so we just ensure proper quoting

    # Step 4: Handle special characters in strings (like degree symbol °)
    # These should be fine in JSON strings

    # Step 5: Fix trailing commas before closing brackets/braces (common JS error)
    fixed = re.sub(r',(\s*[}\]])', r'\1', fixed)

    return fixed

def generate_svg_from_wavedrom(wavedrom_json, output_path):
    """Generate SVG using wavedrom Python package"""
    try:
        # The wavedrom.render() function expects a STRING, not a dict
        # It will do its own parsing using YAML/JSON
        # We just need to pass the raw WaveDrom text

        # Render to SVG - pass the string directly
        svg_content = wavedrom.render(wavedrom_json)

        # Check if it's a string or object
        if hasattr(svg_content, 'tostring'):
            # It's an SVG object
            svg_content.saveas(str(output_path))
        else:
            # It's a string, write directly
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(svg_content)

        return True
    except Exception as e:
        print(f"   ❌ Error generating SVG: {e}")
        # Print the problematic JSON for debugging
        print(f"      First 200 chars: {wavedrom_json[:200]}")
        return False

def process_markdown_file(filename, image_dir):
    """Process a single markdown file"""
    file_path = SCRIPT_DIR / filename

    if not file_path.exists():
        print(f"⚠️  File not found: {filename}")
        return

    print(f"\n📄 Processing: {filename}")

    content = file_path.read_text(encoding='utf-8')
    blocks = extract_wavedrom_blocks(content)

    if not blocks:
        print(f"   No WaveDrom blocks found")
        return

    print(f"   Found {len(blocks)} WaveDrom diagram(s)")

    new_content = content
    offset = 0

    for idx, block in enumerate(blocks):
        base_filename = filename.replace('.md', '')
        svg_filename = f"{base_filename}-diagram-{idx + 1}.svg"
        svg_path = image_dir / svg_filename
        relative_path = f"./{IMAGE_DIR}/{svg_filename}"

        # Generate SVG
        success = generate_svg_from_wavedrom(block['json'], svg_path)

        if success:
            print(f"   ✅ Generated: {svg_filename}")

            # Create image reference
            image_markdown = f'\n\n**Rendered Diagram** (GitHub):\n\n![WaveDrom Diagram]({relative_path})\n\n'

            # Insert after WaveDrom code block
            insert_pos = block['start_pos'] + offset + len(block['full_match'])
            new_content = new_content[:insert_pos] + image_markdown + new_content[insert_pos:]
            offset += len(image_markdown)

    # Write updated markdown
    if offset > 0:
        file_path.write_text(new_content, encoding='utf-8')
        print(f"   ✅ Updated markdown file")

def main():
    """Main execution"""
    print('🚀 WaveDrom SVG Generator (Python)\n')
    print('=' * 50)

    # Create image directory
    image_dir = create_image_dir()

    print("✅ Using wavedrom Python package to generate SVGs\n")

    # Process all markdown files
    for filename in MARKDOWN_FILES:
        process_markdown_file(filename, image_dir)

    print('\n' + '=' * 50)
    print('✅ Done! All diagrams generated.')
    print(f'\n📁 SVG files saved to: {IMAGE_DIR}/')
    print('\n💡 Next steps:')
    print('   1. Review the generated SVG files')
    print('   2. Commit to repository: git add wavedrom-images/ *.md')
    print('   3. Push to GitHub to see diagrams render!')

if __name__ == '__main__':
    main()

