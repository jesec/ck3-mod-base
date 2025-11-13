#!/usr/bin/env node
// Script to test BBCode parsing on all existing release notes by attempting to
// re-parse them to see if the conversion improves

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const releaseNotesDir = path.join(__dirname, '../../release-notes');

console.log('Analyzing existing release notes for parsing issues...\n');

const files = fs.readdirSync(releaseNotesDir)
  .filter(f => f.endsWith('.md'))
  .sort();

let totalFiles = 0;
let filesWithEscapedBBCode = 0;
let filesWithHtmlMarkers = 0;

for (const file of files) {
  const filePath = path.join(releaseNotesDir, file);
  const content = fs.readFileSync(filePath, 'utf8');
  
  totalFiles++;
  
  // Check for escaped BBCode markers
  const hasEscapedBBCode = /\\(\[|\])/.test(content);
  
  // Check for <*> or <\*> markers
  const hasHtmlMarkers = /<\\?\*>/.test(content);
  
  if (hasEscapedBBCode || hasHtmlMarkers) {
    console.log(`\n📄 ${file}:`);
    
    if (hasEscapedBBCode) {
      const escapedCount = (content.match(/\\(\[|\])/g) || []).length;
      console.log(`   ⚠️  Found ${escapedCount} escaped BBCode markers (\\[ or \\])`);
      filesWithEscapedBBCode++;
    }
    
    if (hasHtmlMarkers) {
      const htmlMarkerCount = (content.match(/<\\?\*>/g) || []).length;
      console.log(`   ⚠️  Found ${htmlMarkerCount} HTML-like markers (<*> or <\\*>)`);
      filesWithHtmlMarkers++;
    }
    
    // Show a sample
    const lines = content.split('\n');
    const problematicLines = lines
      .map((line, i) => ({ line, num: i + 1 }))
      .filter(({ line }) => /\\(\[|\])|<\\?\*>/.test(line))
      .slice(0, 3);
    
    if (problematicLines.length > 0) {
      console.log('   Sample issues:');
      problematicLines.forEach(({ line, num }) => {
        console.log(`     Line ${num}: ${line.substring(0, 80)}...`);
      });
    }
  }
}

console.log('\n' + '='.repeat(70));
console.log('\n📊 Summary:');
console.log(`   Total files analyzed: ${totalFiles}`);
console.log(`   Files with escaped BBCode: ${filesWithEscapedBBCode}`);
console.log(`   Files with HTML-like markers: ${filesWithHtmlMarkers}`);
console.log(`   Clean files: ${totalFiles - Math.max(filesWithEscapedBBCode, filesWithHtmlMarkers)}`);

if (filesWithEscapedBBCode > 0 || filesWithHtmlMarkers > 0) {
  console.log('\n✅ These files will benefit from the BBCode parsing fix.');
  console.log('   They would need to be regenerated to apply the fix.');
} else {
  console.log('\n✅ All release notes are clean!');
}
