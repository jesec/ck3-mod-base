# BBCode Parsing Fix for CK3 Release Notes

## Problem
Steam's CK3 release notes contain BBCode with parsing issues that weren't properly handled:
1. **Backslash-escaped markers**: `\[list\]\[\*\]` - Steam escapes BBCode special characters
2. **HTML-like markers**: `<*>` and `<\*>` - Alternative list item format used by Steam
3. **Unclosed lists**: Lists start with `[list]` but never close with `[/list]`

These issues resulted in release notes files with literal escaped text instead of proper markdown lists.

## Solution
Enhanced the BBCode normalization logic in `index.js` (lines 499-510) with:

### 1. Unescape Backslash-Escaped BBCode
```javascript
.replace(/\\(\[|\])/g, '$1')
```
Converts `\[list\]\[\*\]` → `[list][*]`

### 2. Convert HTML-like Markers
```javascript
.replace(/<\\\*>/g, '[*]')  // <\*> → [*]
.replace(/<\*>/g, '[*]')     // <*> → [*]
```

### 3. Auto-Close Unclosed Lists
```javascript
.replace(/(\[list\](?:(?!\[\/list\]|\[list\]).)*?)(\n##?\s|\[list\]|$)/gs, '$1[/list]$2')
```
Adds `[/list]` before next heading, next list, or end of content.

## Testing

### Test Scripts Created
- `test-bbcode.js` - Tests basic BBCode formats
- `test-list-formats.js` - Tests various list structures
- `test-unclosed-lists.js` - Tests the unclosed list fix
- `analyze-release-notes.js` - Scans all release notes for issues

### Results
```bash
$ node analyze-release-notes.js
```
- **Total files**: 36 release notes
- **Files with issues**: 4 (versions 1.13.0, 1.17.0, 1.18.0, 1.18.1)
- **Clean files**: 32 (no changes needed)

## Regenerating Release Notes

### Affected Versions
The following versions have parsing issues and should be regenerated:
- **1.18.1** (976 escaped markers, 10 HTML markers)
- **1.18.0** (986 escaped markers, 158 HTML markers)  
- **1.17.0** (128 escaped markers, 5 HTML markers)
- **1.13.0** (2 escaped markers, 14 HTML markers)

### Manual Regeneration
Use the `regenerate-release-notes.js` script to fetch fresh content from Steam:

```bash
cd base/scripts/automation
node regenerate-release-notes.js 1.18.1 1.18.0 1.17.0 1.13.0
```

This will:
1. Fetch original BBCode from Steam API
2. Apply the fixed normalization logic
3. Convert to proper markdown
4. Overwrite the existing files

### Automatic Regeneration
The GitHub Actions workflow (`update-base.yml`) will automatically apply this fix when:
- New CK3 versions are released
- The workflow downloads and parses game files

The fix is now integrated into the `parse` command (line 500-510 in index.js), so all future release notes will be generated correctly.

## Validation

### Before Fix
```markdown
\[list\]\[\*\]

Customized Title names will once again be properly displayed

\[\*\]

Women who serve as governors...

<\*>

Empire titles not part of a Hegemony...
```

### After Fix
```markdown
-   Customized Title names will once again be properly displayed
-   Women who serve as governors...
-   Empire titles not part of a Hegemony...
```

## Durability Testing

### Tested Scenarios
1. ✅ Normal BBCode lists
2. ✅ Backslash-escaped markers
3. ✅ Mixed closing tags `[/*]`
4. ✅ HTML-like markers `<*>` and `<\*>`
5. ✅ Unclosed lists before headings
6. ✅ Multiple lists in one document
7. ✅ Lists at end of document

### Cross-Game Compatibility
The fix handles generic BBCode parsing issues that could affect:
- Other Paradox game release notes (if they use similar BBCode)
- Any Steam game using the same event/announcement system
- Various BBCode flavors used across Steam platform

The regex patterns are generic and don't rely on CK3-specific content.

## Notes for Future Maintenance

### When to Regenerate
Regenerate release notes when:
1. **After deploying this fix**: To clean up existing problematic files
2. **Backfilling old versions**: If adding historical release notes
3. **User reports formatting issues**: Spot-check and regenerate if needed

### Verification
After regeneration, verify with:
```bash
node analyze-release-notes.js
```
Should show 0 files with issues.

### Limitations
- **Requires Steam API access**: Regeneration needs internet access to store.steampowered.com
- **Rate limiting**: Script includes 1-second delays between requests
- **Manual trigger needed**: Existing files won't auto-regenerate, only new versions

## Implementation Details

### Code Changes
- **File**: `base/scripts/automation/index.js`
- **Function**: `fetchAndSaveReleaseNotes()` 
- **Lines**: 500-510 (normalization logic)

### Dependencies
- `@bbob/html` - BBCode to HTML parser
- `@bbob/preset-html5` - HTML5 preset for bbob
- `turndown` - HTML to Markdown converter

No new dependencies added; uses existing packages.
