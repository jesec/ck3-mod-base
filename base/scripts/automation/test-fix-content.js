#!/usr/bin/env node
// Script to show what fixed content would look like for problematic files

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import bbobHTML from '@bbob/html';
import presetHTML5 from '@bbob/preset-html5';
import TurndownService from 'turndown';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const releaseNotesDir = path.join(__dirname, '../../release-notes');

function fixBBCodeContent(content) {
  // Extract the body content (after the ---) to avoid touching the header
  const parts = content.split('---\n');
  if (parts.length < 2) return content;
  
  const header = parts[0] + '---\n';
  const body = parts.slice(1).join('---\n');
  
  // Apply normalization to the body
  let normalizedBBCode = body
    // Unescape backslash-escaped BBCode markers (Steam escapes these)
    .replace(/\\(\[|\])/g, '$1')
    // Convert <\*> (backslash-escaped) markers to [*]
    .replace(/<\\\*>/g, '[*]')
    // Convert <*> markers to [*] (alternative BBCode list format)
    .replace(/<\*>/g, '[*]')
    // Fix unclosed [list] tags by adding [/list] before next heading or [list]
    .replace(/(\[list\](?:(?!\[\/list\]|\[list\]).)*?)(\n##?\s|\[list\]|$)/gs, '$1[/list]$2')
    // Fix list items with closing tags [*]...[/*] -> [*]...
    .replace(/\[\*\](.*?)\[\/\*\]/gs, '[*]$1');
  
  // Convert to HTML
  const html = bbobHTML(normalizedBBCode, presetHTML5());
  
  // Convert to Markdown
  const turndownService = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-'
  });
  const markdown = turndownService.turndown(html);
  
  return header + markdown;
}

// Test on 1_18_1_0_2025-11-12.md
const testFile = '1_18_1_0_2025-11-12.md';
const filePath = path.join(releaseNotesDir, testFile);

console.log(`Testing fix on ${testFile}...\n`);

const originalContent = fs.readFileSync(filePath, 'utf8');
const fixedContent = fixBBCodeContent(originalContent);

// Show a comparison of a section
const originalLines = originalContent.split('\n').slice(18, 45);
const fixedLines = fixedContent.split('\n').slice(18, 45);

console.log('=== BEFORE (with parsing issues) ===\n');
originalLines.forEach((line, i) => console.log(`${(19 + i).toString().padStart(3)}: ${line}`));

console.log('\n=== AFTER (fixed) ===\n');
fixedLines.forEach((line, i) => console.log(`${(19 + i).toString().padStart(3)}: ${line}`));

// Write to a test file for manual inspection
const testOutputPath = '/tmp/1_18_1_0_2025-11-12_FIXED.md';
fs.writeFileSync(testOutputPath, fixedContent);
console.log(`\n✅ Full fixed file written to: ${testOutputPath}`);

// Count improvements
const originalEscaped = (originalContent.match(/\\(\[|\])/g) || []).length;
const fixedEscaped = (fixedContent.match(/\\(\[|\])/g) || []).length;
const originalHtml = (originalContent.match(/<\\?\*>/g) || []).length;
const fixedHtml = (fixedContent.match(/<\\?\*>/g) || []).length;

console.log('\n📊 Improvements:');
console.log(`   Escaped BBCode markers: ${originalEscaped} → ${fixedEscaped}`);
console.log(`   HTML-like markers: ${originalHtml} → ${fixedHtml}`);
