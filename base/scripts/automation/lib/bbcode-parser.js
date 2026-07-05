// BBCode to Markdown converter
// Direct conversion without HTML intermediate step

/**
 * Convert BBCode directly to Markdown
 */
export function bbcodeToMarkdown(bbcode) {
  let md = bbcode;

  // Step 1: Protect code blocks - preserve BBCode as-is for markdown output
  // Exception: Social media footer blocks should be processed, not preserved as code
  const codeBlocks = [];
  md = md.replace(/\[code\](.*?)\[\/code\]/gis, (match, content) => {
    // Detect social media footer pattern - these aren't real code, just styled callouts
    if (content.includes('Join the conversation') ||
        content.includes('social media') ||
        (content.includes('[url=') && content.includes('style=button'))) {
      // Don't protect - let URLs be processed normally, strip the code wrapper
      return content;
    }
    // Preserve actual code content as-is for markdown code fences
    const placeholder = `___CODE_BLOCK_${codeBlocks.length}___`;
    codeBlocks.push(content);
    return placeholder;
  });

  // Step 2: Protect inline code
  const inlineCodes = [];
  md = md.replace(/\[c\](.*?)\[\/c\]/gis, (match, content) => {
    const placeholder = `___INLINE_CODE_${inlineCodes.length}___`;
    inlineCodes.push(content);
    return placeholder;
  });

  // Step 3: Don't escape markdown special characters - keep asterisks literal
  // Asterisks in BBCode content are literal text, not markdown formatting

  // Step 4: Escaped brackets will be protected later, after BBCode processing
  const escapedBrackets = [];

  // Step 5: Unescape characters including asterisks
  for (let i = 0; i < 3; i++) {
    md = md
      .replace(/\\\\/g, '\\')
      .replace(/\\"/g, '"')
      .replace(/\\'/g, "'")
      .replace(/\\\*/g, '*'); // Unescape asterisks
  }

  // Step 6: Strip color tags (not supported in Markdown)
  md = md.replace(/\[color=[^\]]+\]/gi, '').replace(/\[\/color\]/gi, '');

  // Step 7: Expand/collapse tags - convert to HTML details/summary
  md = md.replace(/\[expand\s+type=details(?:\s+title="([^"]+)")?\s*\](.*?)\[\/expand\]/gis, (match, title, content) => {
    const summaryText = title || 'Show Details';
    return `<details>\n<summary>${summaryText}</summary>\n\n${content}\n</details>`;
  });

  // Step 8: Headings
  // First, handle special cases where links wrap headings - must happen BEFORE heading processing
  const headingLinks = [];
  md = md.replace(/\[url="?([^"\]\s]+)"?[^\]]*\]\[h1\](.*?)\[\/h1\]\[\/url\]/gis, (match, url, text) => {
    const cleanUrl = url.replace(/^["']|["']$/g, '');
    text = text.replace(/^\n+|\n+$/g, ''); // Trim newlines
    const placeholder = `___HEADING_LINK_H1_${headingLinks.length}___`;
    headingLinks.push({ level: 1, url: cleanUrl, text });
    return placeholder;
  });
  md = md.replace(/\[url="?([^"\]\s]+)"?[^\]]*\]\[h2\](.*?)\[\/h2\]\[\/url\]/gis, (match, url, text) => {
    const cleanUrl = url.replace(/^["']|["']$/g, '');
    text = text.replace(/^\n+|\n+$/g, ''); // Trim newlines
    const placeholder = `___HEADING_LINK_H2_${headingLinks.length}___`;
    headingLinks.push({ level: 2, url: cleanUrl, text });
    return placeholder;
  });
  md = md.replace(/\[url="?([^"\]\s]+)"?[^\]]*\]\[h3\](.*?)\[\/h3\]\[\/url\]/gis, (match, url, text) => {
    const cleanUrl = url.replace(/^["']|["']$/g, '');
    text = text.replace(/^\n+|\n+$/g, ''); // Trim newlines
    const placeholder = `___HEADING_LINK_H3_${headingLinks.length}___`;
    headingLinks.push({ level: 3, url: cleanUrl, text });
    return placeholder;
  });

  // Handle format tags wrapping headings
  // Bold wrapping heading - headings are already bold, so just output the heading
  md = md.replace(/\[b\]\[h1\](.*?)\[\/h1\]\[\/b\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `# ${content}`;
  });
  md = md.replace(/\[b\]\[h2\](.*?)\[\/h2\]\[\/b\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `## ${content}`;
  });
  md = md.replace(/\[b\]\[h3\](.*?)\[\/h3\]\[\/b\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `### ${content}`;
  });
  // Underline wrapping heading - use HTML underline inline with heading
  md = md.replace(/\[u\]\[h1\](.*?)\[\/h1\]\[\/u\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `# <u>${content}</u>`;
  });
  md = md.replace(/\[u\]\[h2\](.*?)\[\/h2\]\[\/u\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `## <u>${content}</u>`;
  });
  md = md.replace(/\[u\]\[h3\](.*?)\[\/h3\]\[\/u\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `### <u>${content}</u>`;
  });
  // Italic wrapping heading - use HTML em inline with heading
  md = md.replace(/\[i\]\[h1\](.*?)\[\/h1\]\[\/i\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `# <em>${content}</em>`;
  });
  md = md.replace(/\[i\]\[h2\](.*?)\[\/h2\]\[\/i\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `## <em>${content}</em>`;
  });
  md = md.replace(/\[i\]\[h3\](.*?)\[\/h3\]\[\/i\]/gis, (match, content) => {
    content = convertInlineFormatting(content);
    return `### <em>${content}</em>`;
  });

  // Headings - consume trailing newline to avoid extra blank lines
  md = md.replace(/\[h1\](.*?)\[\/h1\]\n?/gis, (match, content) => {
    // Trim newlines from content and process inline formatting
    content = content.replace(/^\n+|\n+$/g, '');
    content = convertInlineFormatting(content);
    return `# ${content}\n\n`;
  });
  md = md.replace(/\[h2\](.*?)\[\/h2\]\n?/gis, (match, content) => {
    content = content.replace(/^\n+|\n+$/g, '');
    content = convertInlineFormatting(content);
    return `## ${content}\n\n`;
  });
  md = md.replace(/\[h3\](.*?)\[\/h3\]\n?/gis, (match, content) => {
    content = content.replace(/^\n+|\n+$/g, '');
    content = convertInlineFormatting(content);
    return `### ${content}\n\n`;
  });

  // Step 9: Horizontal rules
  md = md.replace(/\[hr\]\[\/hr\]/gi, '\n---\n');

  // Step 10: YouTube embeds - extract video ID, strip BBCode parameters like ;full
  md = md.replace(/\[previewyoutube[= ]"?([^"\];]+)[^"\]]*"?[^\]]*\].*?\[\/previewyoutube\]/gis, (match, videoId) => {
    // Extract just the video ID (stop at semicolon which starts BBCode params)
    return `_[YouTube Video: https://www.youtube.com/watch?v=${videoId}]_`;
  });

  // Step 11: Links - handle both [url=...] and [url="..."] formats, strip quotes, handle empty parameter
  md = md.replace(/\[url=["']?["']?\](.*?)\[\/url\]/gis, (match, text) => {
    // Empty parameter - use text as both URL and link text
    return `[${text}](${text})`;
  });
  md = md.replace(/\[url="?([^"\]\s]+)"?[^\]]*\](.*?)\[\/url\]/gis, (match, url, text) => {
    // Capture URL (stop at space/quote/bracket), ignore any attributes after URL
    let cleanUrl = url.replace(/^["']|["']$/g, '');
    // Add https:// if protocol is missing
    if (!cleanUrl.match(/^https?:\/\//i)) {
      cleanUrl = 'https://' + cleanUrl;
    }
    return `[${text}](${cleanUrl})`;
  });
  // Auto-link [url]...[/url] format - wrap URL in angle brackets for link text
  md = md.replace(/\[url\](.*?)\[\/url\]/gis, '[<$1>]($1)');
  // Dynamic links - use href as URL, text as link text (or href if no text)
  md = md.replace(/\[dynamiclink\s+href="([^"]+)"\](.*?)\[\/dynamiclink\]/gis, (match, href, text) => {
    const linkText = text.trim() || href;
    return `[${linkText}](${href})`;
  });
  md = md.replace(/\[dynamiclink[^\]]*\](.*?)\[\/dynamiclink\]/gis, '$1'); // Strip other dynamic links

  // Step 12: Images - handle both [img src="..."] and [img]...[/img] formats
  // Each image should be on its own line for proper paragraph separation
  md = md.replace(/\[img\s+src="?([^"\]]+)"?\]\[\/img\]/gi, '\n\n![]($1)\n\n');
  md = md.replace(/\[img\]([^\[]+)\[\/img\]/gi, '\n\n![]($1)\n\n'); // Handle [img]url[/img] format

  // Step 13: Lists - handle inline first, then process with state machine
  // IMPORTANT: Process lists BEFORE auto-linking bare URLs to avoid interference

  // Normalize angle bracket list syntax to square brackets
  md = md.replace(/<\*>/g, '[*]');
  md = md.replace(/<\/\*>/g, '[/*]');

  // Lists can appear inline like "**China**[list]" - need to add newline before them
  md = md.replace(/([^\n])(\[list(?:=1)?\])/gi, '$1\n$2');
  md = md.replace(/([^\n])(\[olist\])/gi, '$1\n$2');

  // Add newlines AFTER list opening tags so items are on separate lines (preserve =1)
  md = md.replace(/(\[list(?:=1)?\])/gi, '$1\n');
  md = md.replace(/(\[olist\])/gi, '$1\n');

  // Add newlines BEFORE list closing tags
  md = md.replace(/\[\/list\]/gi, '\n[/list]');
  md = md.replace(/\[\/olist\]/gi, '\n[/olist]');

  // Add newlines after list item closing tags
  md = md.replace(/\[\/\*\]/gi, '\n');

  // Add spacing between consecutive lists
  md = md.replace(/\[\/list\](\s*)\[list/gi, '[/list]\n\n[list');
  md = md.replace(/\[\/olist\](\s*)\[olist/gi, '[/olist]\n\n[olist');

  // Add TWO newlines (blank line) after list closing to separate from following content
  // This ensures markdown parsers treat following content as separate from the list
  // Handle both cases: no newline and single newline after [/list]
  md = md.replace(/\[\/list\]([^\n])/gi, '[/list]\n\n$1');   // No newline case
  md = md.replace(/\[\/list\]\n([^\n])/gi, '[/list]\n\n$1'); // Single newline case
  md = md.replace(/\[\/olist\]([^\n])/gi, '[/olist]\n\n$1');
  md = md.replace(/\[\/olist\]\n([^\n])/gi, '[/olist]\n\n$1');

  // Normalize asterisk list items
  md = md.replace(/\[\*\]/g, '[*]');

  // Ensure each [*] starts on its own line (split consecutive items)
  // Use loop to handle any number of consecutive items
  while (md.match(/\[\*\]([^\[\n]*)\[\*\]/)) {
    md = md.replace(/\[\*\]([^\[\n]*)\[\*\]/g, '[*]$1\n[*]');
  }

  // Process lists with state machine
  md = processLists(md);

  // Step 14: Auto-link bare URLs (AFTER list processing to avoid interference)
  // Protect markdown links first to avoid auto-linking inside them
  const markdownLinks = [];
  md = md.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (match, text, url) => {
    const placeholder = `___MARKDOWN_LINK_${markdownLinks.length}___`;
    markdownLinks.push({ text, url });
    return placeholder;
  });

  // Only auto-link if not already in a markdown link
  md = md.replace(/(?<!\]\()https?:\/\/[^\s<>\[\]]+/g, (match) => {
    return `<${match}>`;
  });

  // Restore markdown links
  for (let i = 0; i < markdownLinks.length; i++) {
    const { text, url } = markdownLinks[i];
    md = md.replace(`___MARKDOWN_LINK_${i}___`, `[${text}](${url})`);
  }

  // Step 15: Tables (basic support - handles both [th] and [td] cells)
  // Match [table] with optional attributes like equalcells="1" colwidth="50,50"
  md = md.replace(/\[table(?:\s+[^\]]+)?\](.*?)\[\/table\]/gis, (match, content) => {
    // Match [tr] with optional attributes
    const rows = content.match(/\[tr(?:\s+[^\]]+)?\](.*?)\[\/tr\]/gis) || [];
    if (rows.length === 0) return '';

    let tableLines = [];
    let isFirstRow = true;

    for (const row of rows) {
      // Match both [th] and [td] cells with optional attributes like colspan="2"
      const thCells = row.match(/\[th(?:\s+[^\]]+)?\](.*?)\[\/th\]/gis) || [];
      const tdCells = row.match(/\[td(?:\s+[^\]]+)?\](.*?)\[\/td\]/gis) || [];

      // Use th cells if present (header row), otherwise use td cells
      const cells = thCells.length > 0 ? thCells : tdCells;
      const isHeaderRow = thCells.length > 0;

      const cellContents = cells.map(cell => {
        // Remove both [th] and [td] tags with optional attributes (e.g., colspan="2")
        let content = cell.replace(/\[th(?:\s+[^\]]+)?\]/gi, '').replace(/\[\/th\]/gi, '')
                          .replace(/\[td(?:\s+[^\]]+)?\]/gi, '').replace(/\[\/td\]/gi, '');
        // Convert inline formatting (bold, italic, etc.)
        content = convertInlineFormatting(content);
        // Replace newlines with <br> tags for multi-line cell content
        content = content.replace(/\n/g, '<br>');
        return content.trim();
      });

      tableLines.push('| ' + cellContents.join(' | ') + ' |');

      // Add separator after first row (which could be header or first data row)
      if (isFirstRow) {
        tableLines.push('| ' + cellContents.map(() => '---').join(' | ') + ' |');
        isFirstRow = false;
      }
    }

    // Add blank lines before and after table for marked.js to recognize it
    return '\n\n' + tableLines.join('\n') + '\n\n';
  });

  // Step 16: Paragraphs - handle alignment, remove empty ones
  // Remove empty paragraphs with attributes - just skip them
  md = md.replace(/\[p\s+[^\]]*\]\s*\[\/p\]/g, '\n\n');
  // Empty paragraphs become blank lines (markdown-first approach)
  md = md.replace(/\[p\]\[\/p\]/g, '\n\n');
  // Paragraphs with only whitespace become blank lines
  md = md.replace(/\[p\](\s+)\[\/p\]/g, '\n\n');
  // Preserve alignment as HTML with inline style
  md = md.replace(/\[p\s+align="(center|left|right)"[^\]]*\](.*?)\[\/p\]/gis, (match, align, content) => {
    content = content.replace(/([^\n])\n([^\n])/g, '$1  \n$2');
    content = content.trim();
    if (!content) return '\n\n';
    return `<p style="text-align: ${align}">${content}</p>\n\n`;
  });
  // Strip other attributes from paragraphs and convert single newlines to hard breaks
  md = md.replace(/\[p\s+[^\]]*\](.*?)\[\/p\]/gis, (match, content) => {
    // Convert single newlines to hard breaks (2 spaces + newline)
    // But preserve double newlines (paragraph breaks)
    content = content.replace(/([^\n])\n([^\n])/g, '$1  \n$2');
    return content + '\n\n';
  });
  // Remove plain [p] tags and convert single newlines to hard breaks
  md = md.replace(/\[p\](.*?)\[\/p\]/gis, (match, content) => {
    // Convert single newlines to hard breaks (2 spaces + newline)
    // But preserve double newlines (paragraph breaks)
    content = content.replace(/([^\n])\n([^\n])/g, '$1  \n$2');
    return content + '\n\n';
  });
  // Handle unclosed paragraph tags
  md = md.replace(/\[p\]([^\[]+)$/gm, '$1');
  md = md.replace(/\[p\s+[^\]]*\]([^\[]+)$/gm, '$1');

  // Step 17: Text formatting - move trailing/leading spaces OUTSIDE markers for valid Markdown
  // First handle nested bold+italic combinations to avoid malformed markdown
  md = md.replace(/\[b\]\[i\](.*?)\[\/i\]\[\/b\]/gis, (match, text) => {
    if (text.includes('\n')) {
      text = text.replace(/\n+/g, ' ');
    }
    const leadingSpace = text.match(/^(\s*)/)[0];
    const trailingSpace = text.match(/(\s*)$/)[0];
    const trimmed = text.trim();
    if (!trimmed) {
      return text;
    }
    // Nest italic (underscore) inside bold (double asterisks)
    return `${leadingSpace}**_${trimmed}_**${trailingSpace}`;
  });
  md = md.replace(/\[i\]\[b\](.*?)\[\/b\]\[\/i\]/gis, (match, text) => {
    if (text.includes('\n')) {
      text = text.replace(/\n+/g, ' ');
    }
    const leadingSpace = text.match(/^(\s*)/)[0];
    const trailingSpace = text.match(/(\s*)$/)[0];
    const trimmed = text.trim();
    if (!trimmed) {
      return text;
    }
    // Nest bold (double asterisks) inside italic (underscore)
    return `${leadingSpace}_**${trimmed}**_${trailingSpace}`;
  });

  // Then handle individual bold tags (process iteratively to handle nested/split tags)
  while (md.match(/\[b\](.*?)\[\/b\]/is)) {
    md = md.replace(/\[b\](.*?)\[\/b\]/is, (match, text) => {
      // Check for newlines and collapse to space per HTML inline element spec
      if (text.includes('\n')) {
        text = text.replace(/\n+/g, ' ');
      }
      // Move leading/trailing spaces outside markers for valid Markdown
      const leadingSpace = text.match(/^(\s*)/)[0];
      const trailingSpace = text.match(/(\s*)$/)[0];
      const trimmed = text.trim();
      if (!trimmed) {
        // Whitespace-only content - formatting doesn't matter, just preserve the space
        return text;
      }
      return `${leadingSpace}**${trimmed}**${trailingSpace}`;
    });
  }

  // Collapse double italic tags before processing
  md = md.replace(/\[i\]\[i\](.*?)\[\/i\]\[\/i\]/gis, '[i]$1[/i]');

  // Handle italic tags (process iteratively to handle nested/split tags)
  while (md.match(/\[i\](.*?)\[\/i\]/is)) {
    md = md.replace(/\[i\](.*?)\[\/i\]/is, (match, text) => {
      // Check for newlines and collapse to space
      if (text.includes('\n')) {
        text = text.replace(/\n+/g, ' ');
      }
      // Move leading/trailing spaces outside markers
      const leadingSpace = text.match(/^(\s*)/)[0];
      const trailingSpace = text.match(/(\s*)$/)[0];
      const trimmed = text.trim();
      if (!trimmed) {
        // Whitespace-only content - formatting doesn't matter, just preserve the space
        return text;
      }
      return `${leadingSpace}_${trimmed}_${trailingSpace}`;
    });
  }
  md = md.replace(/\[u\](.*?)\[\/u\]/gis, (match, text) => {
    if (text.includes('\n')) {
      text = text.replace(/\n+/g, ' ');
    }
    return `<u>${text}</u>`;
  });
  md = md.replace(/\[s\](.*?)\[\/s\]/gis, (match, text) => {
    if (text.includes('\n')) {
      text = text.replace(/\n+/g, ' ');
    }
    const leadingSpace = text.match(/^(\s*)/)[0];
    const trailingSpace = text.match(/(\s*)$/)[0];
    const trimmed = text.trim();
    if (!trimmed) {
      return `<s>${text}</s>`;
    }
    return `${leadingSpace}~~${trimmed}~~${trailingSpace}`;
  });
  md = md.replace(/\[strike\](.*?)\[\/strike\]/gis, (match, text) => {
    if (text.includes('\n')) {
      text = text.replace(/\n+/g, ' ');
    }
    const leadingSpace = text.match(/^(\s*)/)[0];
    const trailingSpace = text.match(/(\s*)$/)[0];
    const trimmed = text.trim();
    if (!trimmed) {
      return `<s>${text}</s>`;
    }
    return `${leadingSpace}~~${trimmed}~~${trailingSpace}`;
  });

  // Step 18: Now protect and restore escaped brackets (after all BBCode processing)
  md = md.replace(/\\\[([^\]]+)\]/g, (match, content) => {
    const placeholder = `___ESCAPED_BRACKET_${escapedBrackets.length}___`;
    escapedBrackets.push(content);
    return placeholder;
  });

  // Immediately restore them with markdown escaping
  for (let i = 0; i < escapedBrackets.length; i++) {
    md = md.replace(`___ESCAPED_BRACKET_${i}___`, `\\[${escapedBrackets[i]}]`);
  }

  // Step 19: Restore inline code
  for (let i = 0; i < inlineCodes.length; i++) {
    md = md.replace(`___INLINE_CODE_${i}___`, `\`${inlineCodes[i]}\``);
  }

  // Step 20: Restore code blocks as markdown code fences
  for (let i = 0; i < codeBlocks.length; i++) {
    md = md.replace(`___CODE_BLOCK_${i}___`, `\`\`\`\n${codeBlocks[i]}\n\`\`\``);
  }

  // Step 20: Restore heading links (must be after all other processing)
  for (let i = 0; i < headingLinks.length; i++) {
    const { level, url, text } = headingLinks[i];
    const headingText = convertInlineFormatting(text);
    const marker = '#'.repeat(level);
    md = md.replace(`___HEADING_LINK_H${level}_${i}___`, `${marker} [${headingText}](${url})`);
  }

  // Step 21: Replace Steam image placeholders with actual CDN URL
  md = md.replace(/\{STEAM_CLAN_IMAGE\}/g, 'https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/clans');

  // Step 22: Clean up excessive blank lines (but allow up to 2 consecutive)
  md = md.replace(/\n{4,}/g, '\n\n\n');

  // Step 22: Escape markdown delimiters that would cause double-nesting or unwanted emphasis
  // Pattern *_text_* creates <em><em>text</em></em>, so escape outer *
  // Use negative lookbehind/lookahead to NOT match ** (bold markers)
  md = md.replace(/(?<!\*)\*(_[^_]+_)\*(?!\*)/g, '\\*$1\\*');
  // Note: _**text**_ is CORRECT (italic containing bold), not double-nesting, so don't escape it

  // Escape literal *word* patterns that aren't our markdown formatting
  // Our bold uses ** and italic uses _, so single * surrounding words should be escaped
  // Match *word* but NOT **word** (bold) or *_word_* (already handled above)
  md = md.replace(/(?<!\*)\*([^\s*_][^*\n]*[^\s*_])\*(?!\*)/g, '\\*$1\\*');
  // Also handle single character: *x*
  md = md.replace(/(?<!\*)\*([^\s*_])\*(?!\*)/g, '\\*$1\\*');

  // Step 23: Trim leading and trailing whitespace
  md = md.trim();

  return md;
}

/**
 * Convert inline formatting in a string
 */
function convertInlineFormatting(text) {
  let result = text;

  // Strip color tags
  result = result.replace(/\[color=[^\]]+\]/gi, '').replace(/\[\/color\]/gi, '');

  // Collapse paragraph tags. convertInlineFormatting runs on INLINE contexts
  // (list items, table cells, headings) where a [p] must NOT introduce a
  // block-level break. If these tags survive to the standalone [p] handler
  // (Step 16), each [/p] becomes "\n\n", which injects blank lines between
  // list items and turns every list loose (double-blank-line bullets).
  // Instead, join adjacent paragraphs with a hard break and drop the wrappers,
  // keeping the item/cell content on a single logical block (tight lists).
  result = result.replace(/\[\/p\]\s*\[p(?:\s[^\]]*)?\]/gi, '<br>');
  result = result.replace(/\[p(?:\s[^\]]*)?\]/gi, '').replace(/\[\/p\]/gi, '');

  // Collapse double italic tags before processing
  result = result.replace(/\[i\]\[i\](.*?)\[\/i\]\[\/i\]/gis, '[i]$1[/i]');

  // Convert formatting - preserve ALL spaces
  result = result.replace(/\[b\](.*?)\[\/b\]/gis, (match, t) => {
    if (t.includes('\n')) t = t.replace(/\n+/g, ' ');
    return `**${t}**`;
  });
  result = result.replace(/\[i\](.*?)\[\/i\]/gis, (match, t) => {
    if (t.includes('\n')) t = t.replace(/\n+/g, ' ');
    // Move leading/trailing spaces outside markers for proper markdown parsing
    const leadingSpace = t.match(/^(\s*)/)[0];
    const trailingSpace = t.match(/(\s*)$/)[0];
    const trimmed = t.trim();
    if (!trimmed) return `<em>${t}</em>`; // Whitespace-only
    return `${leadingSpace}_${trimmed}_${trailingSpace}`;
  });
  result = result.replace(/\[u\](.*?)\[\/u\]/gis, (match, t) => {
    if (t.includes('\n')) t = t.replace(/\n+/g, ' ');
    return `<u>${t}</u>`;
  });

  return result;
}

/**
 * Process list structures with proper nesting using a state machine
 */
function processLists(text) {
  const lines = text.split('\n');
  const result = [];
  const listStack = []; // Stack to track current list depth and type
  let inListItem = false;
  let listItemContent = [];
  let listItemDepth = 0; // Track the depth at which the current item belongs

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Check for list start
    const listStartMatch = line.match(/\[list(=1)?\]/i);
    const olistMatch = line.match(/\[olist\]/i);
    if (listStartMatch || olistMatch) {
      const isNumbered = (listStartMatch && !!listStartMatch[1]) || !!olistMatch;
      listStack.push({ type: isNumbered ? 'ordered' : 'unordered', number: 1 });
      // Nested lists will naturally be on the next line after parent item
      continue;
    }

    // Check for list end
    if (line.match(/\[\/list\]/i) || line.match(/\[\/olist\]/i)) {
      if (inListItem) {
        // Flush current list item using the depth it was created at
        const indent = '    '.repeat(Math.max(0, listItemDepth));
        const currentList = listStack[listItemDepth];
        if (currentList && currentList.type === 'ordered') {
          result.push(`${indent}${currentList.number}.  ${listItemContent.join('\n')}`);
          currentList.number++;
        } else {
          result.push(`${indent}-   ${listItemContent.join('\n')}`);
        }
        listItemContent = [];
        inListItem = false;
      }
      listStack.pop();
      continue;
    }

    // Check for list item start (handle both [*] and [\*] from escaped asterisks)
    if (line.match(/\[\\\*\]/i) || line.match(/\[\*\]/i)) {
      if (inListItem) {
        // Flush previous list item using the depth it was created at
        const indent = '    '.repeat(Math.max(0, listItemDepth));
        const currentList = listStack[listItemDepth];
        if (currentList && currentList.type === 'ordered') {
          result.push(`${indent}${currentList.number}.  ${listItemContent.join('\n')}`);
          currentList.number++;
        } else {
          result.push(`${indent}-   ${listItemContent.join('\n')}`);
        }
        listItemContent = [];
      }

      // Extract content after [*] or [\*] and start new item at current depth
      const content = line.replace(/\[\\\*\]/i, '').replace(/\[\*\]/i, '').replace(/\[\/\\\*\]/gi, '').replace(/\[\/\*\]/gi, '');
      const processedContent = convertInlineFormatting(content);
      // Trim leading spaces from list item content (BBCode often has [*] Item with space after [*])
      listItemContent.push(processedContent.replace(/^\s+/, ''));
      listItemDepth = listStack.length - 1; // Set depth for this new item
      inListItem = true;
      continue;
    }

    // Check for list item end (if on its own line) - handle escaped asterisks
    if (line.match(/^\s*\[\/\\\*\]\s*$/i) || line.match(/^\s*\[\/\*\]\s*$/i)) {
      // End marker on its own line - item continues until here
      continue;
    }

    // Regular line
    if (inListItem) {
      // Continuation of list item content
      const processedLine = convertInlineFormatting(line);
      if (processedLine.trim()) {
        listItemContent.push(processedLine);
      }
    } else {
      // Not in a list item (either outside list or between list markers).
      // While still inside an enclosing list (listStack not empty), a blank line
      // is structural noise sitting between a nested sub-list and the following
      // sibling item. Emitting it would make the OUTER list loose (blank-line
      // gaps between every bullet). Drop it to keep the list tight. Blank lines
      // OUTSIDE any list (listStack empty) are preserved so that paragraphs and
      // separate sibling lists stay correctly spaced.
      if (listStack.length > 0 && !line.trim()) {
        continue;
      }
      // Pass through as regular content
      result.push(line);
    }
  }

  // Flush any remaining list item
  if (inListItem && listItemContent.length > 0) {
    const indent = '    '.repeat(Math.max(0, listItemDepth));
    const currentList = listStack[listItemDepth];
    if (currentList && currentList.type === 'ordered') {
      result.push(`${indent}${currentList.number}.  ${listItemContent.join('\n')}`);
    } else {
      result.push(`${indent}-   ${listItemContent.join('\n')}`);
    }
  }

  return result.join('\n');
}
