#!/usr/bin/env node
import bbobHTML from '@bbob/html';
import presetHTML5 from '@bbob/preset-html5';
import TurndownService from 'turndown';

// Real example from the 1.18.1 release notes
const realWorldExample = `## Bugfixes

\\[list\\]\\[*\\]

Customized Title names will once again be properly displayed in all relevant UIs. 

\\[*\\]

Women who serve as governors in Celestial realms will be referred to by their correct titles.

\\[*\\]

Winning a faction war to install a ruling regent no longer imprisons the ceremonial liege. 

<\\*>

Empire titles not part of a Hegemony can now de jure drift into a bordering Hegemony

<\\*>

Empire titles undergoing de jure drift are now striped on the Hegemony map mode.`;

console.log("Testing with real-world example from 1.18.1 release notes:\n");
console.log("=== Original Input ===");
console.log(realWorldExample);
console.log("\n");

// Apply the normalization
let normalizedBBCode = realWorldExample
  // Unescape backslash-escaped BBCode markers (Steam escapes these)
  .replace(/\\(\[|\])/g, '$1')
  // Convert <\*> (backslash-escaped) markers to [*]
  .replace(/<\\\*>/g, '[*]')
  // Convert <*> markers to [*] (alternative BBCode list format)
  .replace(/<\*>/g, '[*]')
  // Fix list items with closing tags [*]...[/*] -> [*]...
  .replace(/\[\*\](.*?)\[\/\*\]/gs, '[*]$1')
  // Fix URL attributes: [url=link style=button] -> [url=link]
  .replace(/\[url=([^\s\]]+)\s+[^\]]*\]/gi, '[url=$1]')
  // Add https:// to URLs that are missing protocol
  .replace(/\[url=(?!https?:\/\/)([^\]]+)\]/gi, '[url=https://$1]');

console.log("=== After Normalization ===");
console.log(normalizedBBCode);
console.log("\n");

// Convert BBCode to HTML
const html = bbobHTML(normalizedBBCode, presetHTML5());
console.log("=== HTML Output ===");
console.log(html);
console.log("\n");

// Convert HTML to Markdown
const turndownService = new TurndownService({
  headingStyle: 'atx',
  codeBlockStyle: 'fenced',
  bulletListMarker: '-'
});
const markdown = turndownService.turndown(html);
console.log("=== Final Markdown ===");
console.log(markdown);
