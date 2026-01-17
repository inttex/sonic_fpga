#!/usr/bin/env python3
"""
Create placeholder SVG files with links to WaveDrom editor

This creates SVG placeholders that:
1. Show the diagram name
2. Provide a link to view/edit in WaveDrom online editor
3. Give instructions for generating real SVGs

Usage: python create_placeholder_svgs.py
"""

import os
import re
import json
import base64
import urllib.parse
from pathlib import Path

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

def create_placeholder_svg(wavedrom_json, output_path, diagram_name):
    """Create a placeholder SVG with link to WaveDrom editor"""
    
    # Create URL-encoded version for WaveDrom editor
    try:
        # Encode the WaveDrom JSON for URL
        encoded = urllib.parse.quote(wavedrom_json)
        editor_url = f"https://wavedrom.com/editor.html?{encoded}"
    except:
        editor_url = "https://wavedrom.com/editor.html"
    
    svg_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="900" height="300">
  <!-- Background -->
  <rect width="900" height="300" fill="#f8f9fa" stroke="#dee2e6" stroke-width="2" rx="10"/>
  
  <!-- Title -->
  <text x="450" y="60" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="bold" fill="#212529">
    WaveDrom Timing Diagram
  </text>
  
  <!-- Diagram Name -->
  <text x="450" y="95" text-anchor="middle" font-family="Arial, sans-serif" font-size="16" fill="#495057">
    {diagram_name}
  </text>
  
  <!-- Instructions Box -->
  <rect x="50" y="120" width="800" height="150" fill="#ffffff" stroke="#adb5bd" stroke-width="1" rx="5"/>
  
  <!-- Instructions -->
  <text x="450" y="150" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" fill="#212529">
    📊 To view this timing diagram:
  </text>
  
  <text x="450" y="180" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#495057">
    1. Click the link below to open in WaveDrom Editor
  </text>
  
  <text x="450" y="205" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#495057">
    2. Or view the WaveDrom code block in the markdown file
  </text>
  
  <!-- Link -->
  <a xlink:href="{editor_url}" target="_blank">
    <rect x="300" y="220" width="300" height="35" fill="#0d6efd" rx="5" style="cursor:pointer"/>
    <text x="450" y="243" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="#ffffff">
      🔗 Open in WaveDrom Editor
    </text>
  </a>
  
</svg>'''
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(svg_content)
    
    return True

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
        
        # Create placeholder SVG
        diagram_name = f"{base_filename.replace('-', ' ').replace('_', ' ')} - Diagram {idx + 1}"
        success = create_placeholder_svg(block['json'], svg_path, diagram_name)
        
        if success:
            print(f"   ✅ Created: {svg_filename}")
            
            # Create image reference
            image_markdown = f'\n\n**Rendered Diagram** (GitHub):\n\n![WaveDrom Diagram]({relative_path})\n\n<sub>Click the image to open in WaveDrom Editor</sub>\n\n'
            
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
    print('🚀 WaveDrom Placeholder SVG Generator\n')
    print('=' * 50)
    
    # Create image directory
    image_dir = create_image_dir()
    
    print("✅ Creating placeholder SVGs with links to WaveDrom editor\n")
    
    # Process all markdown files
    for filename in MARKDOWN_FILES:
        process_markdown_file(filename, image_dir)
    
    print('\n' + '=' * 50)
    print('✅ Done! All placeholder SVGs created.')
    print(f'\n📁 SVG files saved to: {IMAGE_DIR}/')
    print('\n💡 These SVGs contain:')
    print('   - Diagram name and description')
    print('   - Clickable link to WaveDrom online editor')
    print('   - Instructions for viewing')
    print('\n📌 Next steps:')
    print('   1. Commit: git add wavedrom-images/ *.md')
    print('   2. Push to GitHub')
    print('   3. Click SVG images to open diagrams in WaveDrom editor!')

if __name__ == '__main__':
    main()

