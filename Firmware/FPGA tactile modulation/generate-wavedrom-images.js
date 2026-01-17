#!/usr/bin/env node

/**
 * WaveDrom SVG Generator
 * 
 * This script:
 * 1. Scans markdown files for WaveDrom code blocks
 * 2. Generates SVG images for each diagram
 * 3. Saves SVGs to wavedrom-images/ folder
 * 4. Updates markdown files to include image references
 * 
 * Usage: node generate-wavedrom-images.js
 */

const fs = require('fs');
const path = require('path');

// Check if wavedrom is installed
try {
    require.resolve('wavedrom');
} catch (e) {
    console.error('❌ WaveDrom not found!');
    console.error('Please install it first:');
    console.error('  npm install wavedrom');
    process.exit(1);
}

const wavedrom = require('wavedrom');

// Configuration
const MARKDOWN_FILES = [
    'PHASE_SIGNAL_PATH_DOCUMENTATION.md',
    'DUTY_CYCLE_CORRECTION.md',
    'DUTY_CYCLE_FIX_IMPLEMENTATION.md',
    'MUX8_ANALYSIS.md',
    'WAVEDROM_DIAGRAMS_SUMMARY.md'
];

const IMAGE_DIR = 'wavedrom-images';
const SCRIPT_DIR = __dirname;

// Create image directory if it doesn't exist
const imageDirPath = path.join(SCRIPT_DIR, IMAGE_DIR);
if (!fs.existsSync(imageDirPath)) {
    fs.mkdirSync(imageDirPath);
    console.log(`✅ Created directory: ${IMAGE_DIR}/`);
}

// Extract WaveDrom blocks from markdown
function extractWaveDromBlocks(content) {
    const blocks = [];
    const regex = /```wavedrom\n([\s\S]*?)\n```/g;
    let match;
    let index = 0;
    
    while ((match = regex.exec(content)) !== null) {
        blocks.push({
            fullMatch: match[0],
            json: match[1],
            index: index++,
            startPos: match.index
        });
    }
    
    return blocks;
}

// Generate SVG from WaveDrom JSON
function generateSVG(wavedromJson, filename) {
    try {
        const waveData = JSON.parse(wavedromJson);
        const svg = wavedrom.renderWaveForm(0, waveData, wavedrom.waveSkin);
        
        // Add XML declaration and make it standalone
        const fullSvg = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n${svg}`;
        
        const svgPath = path.join(imageDirPath, filename);
        fs.writeFileSync(svgPath, fullSvg);
        
        return true;
    } catch (error) {
        console.error(`❌ Error generating SVG for ${filename}:`, error.message);
        return false;
    }
}

// Process a single markdown file
function processMarkdownFile(filename) {
    const filePath = path.join(SCRIPT_DIR, filename);
    
    if (!fs.existsSync(filePath)) {
        console.warn(`⚠️  File not found: ${filename}`);
        return;
    }
    
    console.log(`\n📄 Processing: ${filename}`);
    
    const content = fs.readFileSync(filePath, 'utf8');
    const blocks = extractWaveDromBlocks(content);
    
    if (blocks.length === 0) {
        console.log(`   No WaveDrom blocks found`);
        return;
    }
    
    console.log(`   Found ${blocks.length} WaveDrom diagram(s)`);
    
    let newContent = content;
    let offset = 0;
    
    blocks.forEach((block, idx) => {
        const baseFilename = filename.replace('.md', '');
        const svgFilename = `${baseFilename}-diagram-${idx + 1}.svg`;
        const relativePath = `./${IMAGE_DIR}/${svgFilename}`;
        
        // Generate SVG
        const success = generateSVG(block.json, svgFilename);
        
        if (success) {
            console.log(`   ✅ Generated: ${svgFilename}`);
            
            // Create the image reference to insert
            const imageMarkdown = `\n\n**Rendered Diagram** (GitHub):\n\n![WaveDrom Diagram](${relativePath})\n\n`;
            
            // Insert image reference after the WaveDrom code block
            const insertPos = block.startPos + offset + block.fullMatch.length;
            newContent = newContent.slice(0, insertPos) + imageMarkdown + newContent.slice(insertPos);
            offset += imageMarkdown.length;
        }
    });
    
    // Write updated markdown file
    if (offset > 0) {
        fs.writeFileSync(filePath, newContent);
        console.log(`   ✅ Updated markdown file`);
    }
}

// Main execution
console.log('🚀 WaveDrom SVG Generator\n');
console.log('=' .repeat(50));

MARKDOWN_FILES.forEach(processMarkdownFile);

console.log('\n' + '='.repeat(50));
console.log('✅ Done! All diagrams generated.');
console.log(`\n📁 SVG files saved to: ${IMAGE_DIR}/`);
console.log('\n💡 Next steps:');
console.log('   1. Review the generated SVG files');
console.log('   2. Commit the images to your repository');
console.log('   3. Push to GitHub to see the diagrams render!');

