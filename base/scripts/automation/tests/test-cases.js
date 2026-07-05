// Test cases for BBCode parser
// Each test case has: name, bbcode input, expected markdown output

export const testCases = [
  // Critical bug fixes
  {
    name: 'H2 heading with correct capture group',
    bbcode: '[h2]Bugfixes[/h2]',
    expected: '## Bugfixes'
  },
  {
    name: 'Multiple H2 headings',
    bbcode: '[h2]Features[/h2]\n[h2]Balance[/h2]\n[h2]Bugfixes[/h2]',
    expected: '## Features\n\n## Balance\n\n## Bugfixes'
  },
  {
    name: 'Multi-line bold tag (newline collapses to space per HTML spec)',
    bbcode: '[b]Price: 30% off\nMore text[/b]',
    expected: '**Price: 30% off More text**' // Inline element newlines → space
  },
  {
    name: 'Multi-line italic tag (newline collapses to space per HTML spec)',
    bbcode: '[i]Line 1\nLine 2[/i]',
    expected: '_Line 1 Line 2_' // Inline element newlines → space
  },
  {
    name: 'Color tags stripped',
    bbcode: '[color=#FF0000]Red text[/color] normal',
    expected: 'Red text normal'
  },
  {
    name: 'Color in heading',
    bbcode: '[h2][color=#FF0000]Important[/color][/h2]',
    expected: '## Important'
  },

  // Angle bracket content preservation
  {
    name: 'Angle bracket variable',
    bbcode: '[p]Set <VARIABLE_NAME> here[/p]',
    expected: 'Set <VARIABLE_NAME> here'
  },
  {
    name: 'Angle bracket in list',
    bbcode: '[list][*]Note: <eaten by rats>[/*][/list]',
    expected: '-   Note: <eaten by rats>'
  },
  {
    name: 'Generic type syntax',
    bbcode: '[p]Function<T>(param)[/p]',
    expected: 'Function<T>(param)'
  },

  // Code blocks
  {
    name: 'Code block preserves BBCode',
    bbcode: '[code][url=test]Link[/url] [b]bold[/b][/code]',
    expected: '```\n[url=test]Link[/url] [b]bold[/b]\n```'
  },
  {
    name: 'Code block with newlines',
    bbcode: '[code]Line 1\nLine 2\nLine 3[/code]',
    expected: '```\nLine 1\nLine 2\nLine 3\n```'
  },
  {
    name: 'Inline code [c] tag',
    bbcode: '[c]inline_code[/c]',
    expected: '`inline_code`'
  },
  {
    name: 'Multiple [c] tags in paragraphs',
    bbcode: '[p][c]line1[/c][/p][p][c]line2[/c][/p][p][c]line3[/c][/p]',
    expected: '`line1`\n\n`line2`\n\n`line3`'
  },

  // Lists
  {
    name: 'Simple unordered list',
    bbcode: '[list][*]Item 1[/*][*]Item 2[/*][/list]',
    expected: '-   Item 1\n-   Item 2'
  },
  {
    name: 'List with mixed syntax',
    bbcode: '[list][*]Item 1[/*]<*>Item 2</*>[/list]',
    expected: '-   Item 1\n-   Item 2'
  },
  {
    name: 'Ordered list',
    bbcode: '[olist][*]First[/*][*]Second[/*][/olist]',
    expected: '1.  First\n2.  Second'
  },
  {
    name: 'Nested list (2 levels)',
    bbcode: '[list][*]Parent[list][*]Child[/*][/list][/*][/list]',
    expected: '-   Parent\n    -   Child'
  },
  {
    name: 'Nested list (3 levels)',
    bbcode: '[list][*]L1[list][*]L2[list][*]L3[/*][/list][/*][/list][/*][/list]',
    expected: '-   L1\n    -   L2\n        -   L3'
  },

  // Links
  {
    name: 'Basic link',
    bbcode: '[url=https://example.com]Click here[/url]',
    expected: '[Click here](https://example.com)'
  },
  {
    name: 'Link with style attribute',
    bbcode: '[url=https://example.com style=button]Button[/url]',
    expected: '[Button](https://example.com)'
  },
  {
    name: 'Link with quotes',
    bbcode: '[url="https://example.com"]Link[/url]',
    expected: '[Link](https://example.com)'
  },
  {
    name: 'Link with apostrophes (malformed BBCode)',
    bbcode: "[url='https://example.com']Link[/url]",
    expected: '[Link](https://example.com)'
  },
  {
    name: 'Auto-link syntax',
    bbcode: '[url]https://example.com[/url]',
    expected: '[<https://example.com>](https://example.com)'
  },
  {
    name: 'Empty dynamiclink uses URL as text',
    bbcode: '[dynamiclink href="https://store.steampowered.com/app/123"][/dynamiclink]',
    expected: '[https://store.steampowered.com/app/123](https://store.steampowered.com/app/123)'
  },
  {
    name: 'Discord url=]syntax',
    bbcode: '[url=]https://discord.gg/test[/url]',
    expected: '[https://discord.gg/test](https://discord.gg/test)'
  },

  // Images
  {
    name: 'Image basic syntax',
    bbcode: '[img]https://example.com/test.png[/img]',
    expected: '![](https://example.com/test.png)'
  },
  {
    name: 'Image with src attribute',
    bbcode: '[img src="https://example.com/test.png"][/img]',
    expected: '![](https://example.com/test.png)'
  },
  {
    name: 'Image with Steam CDN',
    bbcode: '[img]{STEAM_CLAN_IMAGE}/123/test.png[/img]',
    expected: '![](https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/clans/123/test.png)'
  },

  // Paragraphs and line breaks
  {
    name: 'Empty paragraphs become blank lines (markdown-first)',
    bbcode: '[p][/p][p]Text[/p][p][/p]',
    expected: '\n\nText\n\n'
  },
  {
    name: 'Empty paragraph with space becomes blank lines',
    bbcode: '[p] [/p]',
    expected: '\n\n'
  },
  {
    name: 'Paragraph breaks within [p] tag',
    bbcode: '[p]Para 1\n\nPara 2\n\nPara 3[/p]',
    expected: 'Para 1\n\nPara 2\n\nPara 3'
  },
  {
    name: 'Line breaks within paragraph (hard breaks)',
    bbcode: '[p]Line 1\nLine 2\nLine 3[/p]',
    expected: 'Line 1  \nLine 2  \nLine 3' // <br> → 2 spaces + newline
  },
  {
    name: 'Unclosed paragraph tag',
    bbcode: '[p]Text without closing',
    expected: 'Text without closing'
  },
  {
    name: 'Bare text with double newlines wrapped in paragraphs',
    bbcode: 'Para 1\n\nPara 2\n\nPara 3',
    expected: 'Para 1\n\nPara 2\n\nPara 3' // Now properly wrapped
  },

  // YouTube
  {
    name: 'YouTube embed with semicolon syntax',
    bbcode: '[previewyoutube=dQw4w9WgXcQ;full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=dQw4w9WgXcQ>]_' // ;full stripped (BBCode param, not URL param)
  },
  {
    name: 'YouTube embed with quote syntax',
    bbcode: '[previewyoutube="abc123";full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=abc123>]_'
  },

  // Special tags
  {
    name: 'Horizontal rule',
    bbcode: '[hr][/hr]',
    expected: '---'
  },
  {
    name: 'Expand tags stripped',
    bbcode: '[expand type=details]Hidden[/expand]',
    expected: '<details>\n<summary>Show Details</summary>\n\nHidden\n</details>'
  },
  {
    name: 'Strikethrough [s]',
    bbcode: '[s]deleted[/s]',
    expected: '~~deleted~~'
  },
  {
    name: 'Strikethrough [strike]',
    bbcode: '[strike]removed text[/strike]',
    expected: '~~removed text~~'
  },

  // Character escaping
  {
    name: 'Underscores in variable names',
    bbcode: '[p]VARIABLE_NAME_HERE[/p]',
    expected: 'VARIABLE_NAME_HERE'
  },
  {
    name: 'Asterisks in math',
    bbcode: '[p]6 * 1.5 = 9[/p]',
    expected: '6 * 1.5 = 9'
  },
  {
    name: 'Escaped asterisks remain escaped in output',
    bbcode: '[p]\\*important\\*[/p]',
    expected: '\\*important\\*' // Literal asterisks escaped to prevent markdown emphasis
  },
  {
    name: 'Hyphens unescaped',
    bbcode: '[b]------------[/b]',
    expected: '**------------**'
  },

  // Text formatting
  {
    name: 'Bold text',
    bbcode: '[b]bold[/b]',
    expected: '**bold**'
  },
  {
    name: 'Italic text',
    bbcode: '[i]italic[/i]',
    expected: '_italic_'
  },
  {
    name: 'Nested bold and italic',
    bbcode: '[b][i]both[/i][/b]',
    expected: '**_both_**'
  },
  {
    name: 'Strikethrough',
    bbcode: '[s]deleted[/s]',
    expected: '~~deleted~~'
  },
  {
    name: 'Underline (preserved as HTML)',
    bbcode: '[u]underline[/u]',
    expected: '<u>underline</u>' // Kept as HTML since turndown.keep(['u'])
  },

  // Complex real-world cases
  {
    name: 'Release note item with paragraph',
    bbcode: '[list][*][p]Fixed crash when using console command.[/p][/*][/list]',
    expected: '-   Fixed crash when using console command.'
  },
  {
    name: 'Heading with nested formatting',
    bbcode: '[h3][b]Important Section[/b][/h3]',
    expected: '### **Important Section**'
  },

  // Table support (from agent findings)
  {
    name: 'Table tags converted to HTML (preserved in markdown)',
    bbcode: '[table][tr][th]Header[/th][/tr][tr][td]Cell[/td][/tr][/table]',
    expected: '| Header |\n| --- |\n| Cell |' // Tables render as markdown tables with [th] support
  },

  // Agent-found issues - add comprehensive tests
  {
    name: 'YouTube embed strips ;full BBCode parameter',
    bbcode: '[previewyoutube=abc123;full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=abc123>]_' // ;full is BBCode display param, not video ID
  },
  {
    name: 'Escaped brackets in table cells preserved',
    bbcode: '[table][tr][td][i]\\[REDACTED][/i][/td][/tr][/table]',
    expected: '| _\\[REDACTED]_ |\n| --- |' // Tables convert to markdown format with escaped brackets preserved
  },
  {
    name: 'Links spanning multiple lines in lists',
    bbcode: '[list][*][url=https://example.com]Link[/url] - [b]50% off[/b][/*][/list]',
    expected: '-   [Link](https://example.com) - **50% off**'
  },
  {
    name: 'Bold text without space before colon',
    bbcode: '[b]Important:[/b]Text',
    expected: '**Important:**Text' // Space handling
  },
  {
    name: 'Multiple consecutive images separated by newlines',
    bbcode: '[img]url1.png[/img][img]url2.png[/img][img]url3.png[/img]',
    expected: '![](url1.png)\n\n\n![](url2.png)\n\n\n![](url3.png)' // Each image on own line
  },
  {
    name: 'Image followed by italic caption',
    bbcode: '[img]test.png[/img][i]Caption text[/i]',
    expected: '![](test.png)\n\n_Caption text_' // Image on its own paragraph
  },
  {
    name: 'Link around heading creates clickable heading',
    bbcode: '[url=https://example.com][h2]Title[/h2][/url]',
    expected: '## [Title](https://example.com)'
  },
  {
    name: 'Empty heading preserved',
    bbcode: '[h3][/h3]',
    expected: '###' // Faithful conversion - preserve structure even if empty
  },
  {
    name: 'Bold spanning line break',
    bbcode: '[b]Text line 1\nLine 2[/b]',
    expected: '**Text line 1 Line 2**' // Newline becomes space in inline element
  },
  {
    name: 'List item with paragraph tags',
    bbcode: '[list][*][p]Item text[/p][/*][/list]',
    expected: '-   Item text'
  },
  {
    name: 'Nested lists 3 levels deep',
    bbcode: '[list][*]L1[list][*]L2[list][*]L3[/*][/list][/*][/list][/*][/list]',
    expected: '-   L1\n    -   L2\n        -   L3'
  },
  {
    name: 'Table with attributes stripped',
    bbcode: '[table equalcells="1"][tr][th colspan="2"]Header[/th][/tr][/table]',
    expected: '| Header |\n| --- |' // Attributes stripped, table converted to markdown
  },
  {
    name: 'Multiple paragraph tags with blank lines',
    bbcode: '[p]Para 1[/p]\n\n[p]Para 2[/p]\n\n[p]Para 3[/p]',
    expected: 'Para 1\n\n\nPara 2\n\n\nPara 3' // Each [/p] adds \n\n, plus existing blank lines
  },
  {
    name: 'Link with underline wrapper',
    bbcode: '[u][url=https://example.com]text[/url][/u]',
    expected: '<u>[text](https://example.com)</u>' // Parser converts to markdown link, not HTML anchor
  },
  {
    name: 'Code block with URLs inside',
    bbcode: '[code]Visit https://example.com for more[/code]',
    expected: '```\nVisit https://example.com for more\n```'
  },

  // Regression tests for batch 1 validation issues
  {
    name: 'Issue #1: YouTube ;full parameter stripped from URL',
    bbcode: '[previewyoutube=stUWIQB__Ac;full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=stUWIQB__Ac>]_' // ;full is BBCode display param, not part of video ID
  },
  {
    name: 'Issue #2: {STEAM_CLAN_IMAGE} replaced with CDN URL',
    bbcode: '[img]{STEAM_CLAN_IMAGE}/36033026/test.png[/img]',
    expected: '![](https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/clans/36033026/test.png)'
  },
  {
    name: 'Issue #3: Escaped brackets in captions',
    bbcode: '[i]\\[Iceland before-and-after][/i]',
    expected: '_\\[Iceland before-and-after]_'
  },
  {
    name: 'Issue #4: Bold with trailing space creates valid markdown',
    bbcode: '[b]Treasury: [/b]A new resource',
    expected: '**Treasury:** A new resource'
  },
  {
    name: 'Issue #4: Italic with trailing space',
    bbcode: 'text [i]is [/i]here',
    expected: 'text _is_ here'
  },
  {
    name: 'Issue #5: Bold without trailing space',
    bbcode: '[b]not[/b] a problem',
    expected: '**not** a problem'
  },
  {
    name: 'Issue #7: Image [img]url[/img] format with CDN',
    bbcode: '[img]{STEAM_CLAN_IMAGE}/test.png[/img]',
    expected: '![](https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/clans/test.png)'
  },
  {
    name: 'Issue #8: Link with quotes - no URL encoding',
    bbcode: '[url="https://forum.example.com/test"]Link text[/url]',
    expected: '[Link text](https://forum.example.com/test)'
  },
  {
    name: 'Issue #8: Link with single quotes',
    bbcode: "[url='https://example.com/test']Link[/url]",
    expected: '[Link](https://example.com/test)'
  },
  {
    name: 'Heading with newline after',
    bbcode: '[h2]Lighting[/h2][p]Text after[/p]',
    expected: '## Lighting\n\nText after'
  },
  {
    name: 'Multiple list items on same line in BBCode',
    bbcode: '[list][*]Item 1[/*][*]Item 2[/*][*]Item 3[/*][/list]',
    expected: '-   Item 1\n-   Item 2\n-   Item 3'
  },
  {
    name: 'List inline with text',
    bbcode: '**China**[list][*]Feature[/*][/list]',
    expected: '**China**\n-   Feature'
  },
  {
    name: 'Nested list - first item structure',
    bbcode: '[list][*][b]Ministers[/b][list][*]Personnel[/*][*]Revenue[/*][/list][/*][/list]',
    expected: '-   **Ministers**\n    -   Personnel\n    -   Revenue'
  },

  // ==================== VALIDATION BATCH 1 & 2 ISSUES ====================

  // Issue: Trailing spaces in italic tags
  {
    name: 'Validation Issue: Italic with trailing space preserved',
    bbcode: '[i]Sōryō[/i],[i] [/i]and',
    expected: '_Sōryō_, and'  // Whitespace-only formatting removed, space preserved
  },
  {
    name: 'Validation Issue: Italic with trailing punctuation and space',
    bbcode: 'tribes[i]. [/i]Famed',
    expected: 'tribes_._ Famed'
  },
  {
    name: 'Validation Issue: Italic with leading space',
    bbcode: 'government[i] [/i]bureaucracy',
    expected: 'government bureaucracy'  // Whitespace-only formatting removed, space preserved
  },
  {
    name: 'Validation Issue: Italic with space before closing tag',
    bbcode: '[i]Comparable [/i]means',
    expected: '_Comparable_ means'
  },
  {
    name: 'Validation Issue: Italic space only',
    bbcode: '[i] [/i]',
    expected: ' '  // Whitespace-only formatting removed, space preserved
  },

  // Issue: Bold with trailing space
  {
    name: 'Validation Issue: Bold with trailing space preserved',
    bbcode: '[i]Bóhǎi[/i],[b] [/b]straddles',
    expected: '_Bóhǎi_, straddles'  // Whitespace-only formatting removed, space preserved
  },
  {
    name: 'Validation Issue: Nested bold in italic with trailing space',
    bbcode: '[i][b]Unified Kingdom of Goryeo[/b][/i][b] [/b]based',
    expected: '_**Unified Kingdom of Goryeo**_ based'  // Whitespace-only formatting removed, space preserved
  },
  {
    name: 'Validation Issue: Bold space only',
    bbcode: '[b] [/b]',
    expected: ' '  // Whitespace-only formatting removed, space preserved
  },

  // Issue: HTML escaping
  {
    name: 'Validation Issue: Angle brackets must be preserved in markdown',
    bbcode: "[p]'<Name>'s Moment'[/p]",
    expected: "'<Name>'s Moment'"
  },
  {
    name: 'Validation Issue: Generic type syntax with angle brackets',
    bbcode: '[p]Function<T>(param)[/p]',
    expected: 'Function<T>(param)'
  },

  // Issue: Nested formatting creating literal markdown
  {
    name: 'Validation Issue: Bold wrapping heading',
    bbcode: '[b][h1]Cookie Taxer[/h1][/b]',
    expected: '# Cookie Taxer' // Headings are inherently bold, don't add extra **
  },
  {
    name: 'Validation Issue: Underline wrapping heading',
    bbcode: '[u][h2]The Awards[/h2][/u]',
    expected: '## <u>The Awards</u>' // Inline underline in heading
  },
  {
    name: 'Validation Issue: Heading wrapping bold (correct way)',
    bbcode: '[h1][b]Outro[/b][/h1]',
    expected: '# **Outro**\n\n'
  },

  // Issue: Malformed link tags
  {
    name: 'Validation Issue: Link with empty URL parameter',
    bbcode: '[url=]https://discord.gg/test[/url]',
    expected: '[https://discord.gg/test](https://discord.gg/test)'
  },
  {
    name: 'Validation Issue: Link wrapping heading',
    bbcode: '[url=https://example.com][h3][b]Click Here[/b][/h3][/url]',
    expected: '### [**Click Here**](https://example.com)'
  },

  // Issue: Numbered lists
  {
    name: 'Validation Issue: Numbered list basic',
    bbcode: '[list=1][*]First[/*][*]Second[/*][*]Third[/*][/list]',
    expected: '1.  First\n2.  Second\n3.  Third'
  },
  {
    name: 'Validation Issue: Numbered list with paragraphs',
    bbcode: '[list=1][*][p]Item one[/p][/*][*][p]Item two[/p][/*][/list]',
    expected: '1.  Item one\n2.  Item two' // Paragraph-wrapped items stay tight (no blank-line loosening)
  },
  {
    // Regression for issue #1 (1_18_1_0 release notes): every changelog bullet
    // is wrapped in [p]...[/p]. These must render as one tight bullet list, not
    // a loose list with blank lines between every item.
    name: 'Regression: Multi-item list with paragraph-wrapped items stays tight',
    bbcode: '[list][*][p]First[/p][/*][*][p]Second[/p][/*][*][p]Third[/p][/*][/list]',
    expected: '-   First\n-   Second\n-   Third'
  },
  {
    name: 'Regression: Nested list with paragraph-wrapped items stays tight',
    bbcode: '[list][*][p]Parent[/p][list][*][p]Child A[/p][/*][*][p]Child B[/p][/*][/list][/*][/list]',
    expected: '-   Parent\n    -   Child A\n    -   Child B'
  },

  // Issue: Expand/collapse tags
  {
    name: 'Validation Issue: Expand tag basic',
    bbcode: '[expand type=details]Hidden content[/expand]',
    expected: '<details>\n<summary>Show Details</summary>\n\nHidden content\n</details>'
  },
  {
    name: 'Validation Issue: Expand tag with title',
    bbcode: '[expand type=details title="FAQ"]Questions here[/expand]',
    expected: '<details>\n<summary>FAQ</summary>\n\nQuestions here\n</details>'
  },

  // Issue: Heading with newline after opening tag
  {
    name: 'Validation Issue: Heading with newline after opening tag',
    bbcode: '[h2]\nUpdate 1.18.2[/h2]',
    expected: '## Update 1.18.2\n\n'
  },

  // Issue: Multiple consecutive lists should stay separate
  {
    name: 'Validation Issue: Three separate lists should not merge',
    bbcode: '[list][*]Item A[/*][/list][list][*]Item B[/*][*]Item C[/*][/list][list][*]Item D[/*][/list]',
    expected: '-   Item A\n\n-   Item B\n-   Item C\n\n-   Item D'
  },

  // Issue: Empty paragraph after HR
  {
    name: 'Validation Issue: Empty paragraph after horizontal rule',
    bbcode: '[hr][/hr][p][/p][h2]Heading[/h2]',
    expected: '---\n\n\n## Heading'  // Empty paragraph becomes blank lines
  },

  // Issue: Trailing newline in paragraph
  {
    name: 'Validation Issue: Paragraph with trailing newlines',
    bbcode: '[p]Text here\n\n[/p]',
    expected: 'Text here  \n'
  },
  {
    name: 'Validation Issue: Paragraph with newline after opening tag',
    bbcode: '[p]\nText here[/p]',
    expected: '  \nText here'
  },

  // Issue: Bare URLs should auto-link
  {
    name: 'Validation Issue: Bare URL auto-link',
    bbcode: 'Visit https://store.steampowered.com/app/123 for more',
    expected: 'Visit <https://store.steampowered.com/app/123> for more'
  },
  {
    name: 'Validation Issue: Bare URL on own line',
    bbcode: '[p]Check it out:[/p][p]https://example.com/test[/p]',
    expected: 'Check it out:\n\n<https://example.com/test>'
  },

  // Issue: List items with trailing spaces and breaks
  {
    name: 'Validation Issue: List item with trailing space',
    bbcode: '[*] Fixed a crash. [/*]',
    expected: '-   Fixed a crash.'  // Leading space trimmed from content
  },
  {
    name: 'Validation Issue: List item with leading space',
    bbcode: '[*] Item text[/*]',
    expected: '-   Item text'  // Leading space trimmed from content
  },

  // ==================== CROSS-GAME VALIDATION BUGS (Batch 5) ====================

  // Bug 4: Escaped <u> tags in links
  {
    name: 'Bug 4: Underline inside link should not escape HTML',
    bbcode: '[url=https://example.com][u]Click here[/u][/url]',
    expected: '[<u>Click here</u>](https://example.com)' // NOT [&lt;u&gt;Click here&lt;/u&gt;]
  },
  {
    name: 'Bug 4: Bold and underline inside link',
    bbcode: '[url=https://example.com][b][u]Important[/u][/b][/url]',
    expected: '[**<u>Important</u>**](https://example.com)'
  },
  {
    name: 'Bug 4: Multiple underlines in link text',
    bbcode: '[url=https://example.com]Text with <u>multiple</u> <u>underlines</u>[/url]',
    expected: '[Text with <u>multiple</u> <u>underlines</u>](https://example.com)'
  },

  // Bug 5: YouTube video annotations
  {
    name: 'Bug 5: YouTube ;full stripped, brackets italicized',
    bbcode: '[previewyoutube=dQw4w9WgXcQ;full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=dQw4w9WgXcQ>]_' // ;full is BBCode display param
  },
  {
    name: 'Bug 5: YouTube annotation with quote syntax',
    bbcode: '[previewyoutube="abc123";full][/previewyoutube]',
    expected: '_[YouTube Video: <https://www.youtube.com/watch?v=abc123>]_'
  },

  // Bug 6: Complex table BBCode attributes (already partially tested at line 348)
  {
    name: 'Bug 6: Table with equalcells attribute should be stripped',
    bbcode: '[table equalcells="1"][tr][td]Cell[/td][/tr][/table]',
    expected: '| Cell |\n| --- |' // Attributes stripped, table converted
  },
  {
    name: 'Bug 6: Table with multiple attributes',
    bbcode: '[table equalcells="1" colwidth="50,50"][tr][th]Header[/th][/tr][/table]',
    expected: '| Header |\n| --- |' // All attributes stripped
  },
  {
    name: 'Bug 6: Table cell with colspan attribute',
    bbcode: '[table][tr][th colspan="2"]Wide Header[/th][/tr][/table]',
    expected: '| Wide Header |\n| --- |' // Cell attributes stripped
  },

  // Bug 7: Unconverted [p] tags
  {
    name: 'Bug 7: Paragraph tags should convert properly',
    bbcode: '[p]First paragraph[/p][p]Second paragraph[/p]',
    expected: 'First paragraph\n\nSecond paragraph'
  },
  {
    name: 'Bug 7: Paragraph with bold inside',
    bbcode: '[p][b]Bold paragraph[/b][/p]',
    expected: '**Bold paragraph**'
  },

  // Bug 8: Double-nested emphasis regression
  {
    name: 'Bug 8: Pattern *_text_* should not double-nest',
    bbcode: '*[i]italic[/i]*',
    expected: '\\*_italic_\\*' // Outer * escaped to prevent <em><em>
  },
  {
    name: 'Bug 8: Literal asterisk with italic',
    bbcode: 'Price: *[i]$10[/i]* only',
    expected: 'Price: \\*_$10_\\* only'
  },

  // Bug 9: Unconverted markdown in specific cases
  {
    name: 'Bug 9: Bold at start of line should convert',
    bbcode: '**Previous Patchnotes**',
    expected: '**Previous Patchnotes**' // This is already markdown, should pass through
  },
  {
    name: 'Bug 9: Bold in paragraph should convert',
    bbcode: '[p]See **bold text** here[/p]',
    expected: 'See **bold text** here' // Markdown inside BBCode paragraph
  },

  // Note: Bug 10 (HTML nesting) was a Markdown→HTML issue, not BBCode→Markdown
  // The markdown-renderer.js already has Fix 6 to prevent <p></p> inline tags

  // Bug 11: URL with style=button attribute not converted
  {
    name: 'Bug 11: URL with style=button attribute',
    bbcode: '[url=https://example.com style=button]Click me[/url]',
    expected: '[Click me](https://example.com)'
  },
  {
    name: 'Bug 11: URL with style=button attribute and other attrs',
    bbcode: '[url=https://forum.paradoxplaza.com/ style=button class=foo]Forums[/url]',
    expected: '[Forums](https://forum.paradoxplaza.com/)'
  },
  {
    name: 'Bug 11: URL missing protocol should add https',
    bbcode: '[url=discord.gg/ck3]Discord[/url]',
    expected: '[Discord](https://discord.gg/ck3)'
  },
  {
    name: 'Bug 11: URL with http protocol should preserve it',
    bbcode: '[url=http://example.com]Link[/url]',
    expected: '[Link](http://example.com)'
  },

  // Bug 12: Social media footer in code block should be converted
  {
    name: 'Bug 12: Social media footer in code block - not preserved as code',
    bbcode: '[code]Join the conversation!\n[url=https://twitter.com style=button]Twitter[/url][/code]',
    expected: 'Join the conversation!\n[Twitter](https://twitter.com)'
  },
  {
    name: 'Bug 12: Actual code block should still be preserved',
    bbcode: '[code]function foo() { return bar; }[/code]',
    expected: '```\nfunction foo() { return bar; }\n```'
  },
];
