#!/usr/bin/env node
import bbobHTML from '@bbob/html';
import presetHTML5 from '@bbob/preset-html5';
import TurndownService from 'turndown';

// Test different list formats
const testCases = [
  {
    name: "List items on same line",
    input: "[list][*]Item 1[*]Item 2[*]Item 3[/list]"
  },
  {
    name: "List items with newlines between",
    input: "[list]\n[*]Item 1\n[*]Item 2\n[*]Item 3\n[/list]"
  },
  {
    name: "List items with blank lines (Steam format)",
    input: "[list][*]\n\nItem 1\n\n[*]\n\nItem 2\n\n[*]\n\nItem 3\n\n[/list]"
  },
  {
    name: "List with [*] followed by newline and content",
    input: "[list][*]\nItem 1\n[*]\nItem 2[/list]"
  }
];

console.log("Testing different BBCode list formats:\n");

for (const testCase of testCases) {
  console.log(`\n=== ${testCase.name} ===`);
  console.log("Input:");
  console.log(testCase.input);
  console.log("\nHTML:");
  const html = bbobHTML(testCase.input, presetHTML5());
  console.log(html);
  console.log("\nMarkdown:");
  const turndownService = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-'
  });
  const markdown = turndownService.turndown(html);
  console.log(markdown);
}
