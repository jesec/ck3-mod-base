#!/usr/bin/env node
import bbobHTML from '@bbob/html';
import presetHTML5 from '@bbob/preset-html5';
import TurndownService from 'turndown';

// Test with different BBCode inputs
const testCases = [
  {
    name: "Normal list with [*]",
    input: "[list][*]Item 1[*]Item 2[*]Item 3[/list]"
  },
  {
    name: "Escaped list markers",
    input: "\\[list\\]\\[*\\]Item 1\\[*\\]Item 2\\[/list\\]"
  },
  {
    name: "Mixed with closing tags",
    input: "[list][*]Item 1[/*][*]Item 2[/*][/list]"
  },
  {
    name: "Just [*] without closing",
    input: "[list][*]Item 1[*]Item 2[/list]"
  },
  {
    name: "With <*> markers",
    input: "[list]<*>Item 1<*>Item 2[/list]"
  }
];

console.log("Testing BBCode to Markdown conversion:\n");

for (const testCase of testCases) {
  console.log(`\n=== ${testCase.name} ===`);
  console.log("Input:", testCase.input);
  
  // Apply the normalization from index.js
  let normalizedBBCode = testCase.input
    // Fix list items
    .replace(/\[\*\](.*?)\[\/\*\]/gs, '[*]$1')
    // Fix URL attributes: [url=link style=button] -> [url=link]
    .replace(/\[url=([^\s\]]+)\s+[^\]]*\]/gi, '[url=$1]')
    // Add https:// to URLs that are missing protocol
    .replace(/\[url=(?!https?:\/\/)([^\]]+)\]/gi, '[url=https://$1]');
  
  console.log("Normalized:", normalizedBBCode);
  
  // Convert BBCode to HTML
  const html = bbobHTML(normalizedBBCode, presetHTML5());
  console.log("HTML:", html);
  
  // Convert HTML to Markdown
  const turndownService = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-'
  });
  const markdown = turndownService.turndown(html);
  console.log("Markdown:", markdown);
}
