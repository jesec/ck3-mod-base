# Usage Instructions - BBCode Parsing Fix

## For Repository Maintainers

### Step 1: Review the Fix
The BBCode parsing fix has been implemented in `base/scripts/automation/index.js` (lines 500-510).

**What was fixed**:
- Backslash-escaped BBCode markers (`\[list\]\[\*\]`)
- HTML-like list markers (`<*>` and `<\*>`)
- Unclosed lists (missing `[/list]` tags)

**Test the fix**:
```bash
cd base/scripts/automation
npm install  # If not already done

# Run test suite
node test-bbcode.js
node test-list-formats.js
node test-unclosed-lists.js

# Analyze current state
node analyze-release-notes.js
```

### Step 2: Regenerate Affected Files

**Identify affected files**:
```bash
node analyze-release-notes.js
```

Expected output shows 4 files with issues:
- 1_18_1_0_2025-11-12.md
- 1_18_0_0_2025-10-28.md
- 1_17_0_0_2025-09-09.md
- 1_13_0_0_2024-09-24.md

**Regenerate from Steam** (requires internet access):
```bash
node regenerate-release-notes.js 1.18.1 1.18.0 1.17.0 1.13.0
```

This will:
1. Fetch original BBCode from Steam API
2. Apply the fixed normalization logic
3. Convert to proper markdown
4. Overwrite the existing files

### Step 3: Verify the Fix

**Check that issues are resolved**:
```bash
node analyze-release-notes.js
```

Expected output:
```
📊 Summary:
   Total files analyzed: 36
   Files with escaped BBCode: 0
   Files with HTML-like markers: 0
   Clean files: 36

✅ All release notes are clean!
```

**Review a sample file**:
```bash
head -50 ../release-notes/1_18_1_0_2025-11-12.md
```

Should now show proper markdown lists:
```markdown
## Bugfixes

-   Customized Title names will once again be properly displayed
-   Women who serve as governors...
-   Empire titles not part of a Hegemony...
```

### Step 4: Commit & Merge

**Commit the regenerated files**:
```bash
cd ../..  # Back to repo root
git add base/release-notes/*.md
git commit -m "Regenerate release notes with fixed BBCode parser"
git push
```

**Merge the PR**: The fix is now ready to merge into main.

## For Future Maintenance

### When New Versions Are Released

The fix is **automatically applied** to new versions by the GitHub Actions workflow.

No manual action needed - the `update-base.yml` workflow:
1. Downloads new CK3 files
2. Parses release notes using the fixed parser
3. Commits properly formatted markdown files

### If You Find More Parsing Issues

**Report the issue**:
1. Note the specific BBCode pattern causing problems
2. Create a test case in a new test file
3. Update the normalization logic in `index.js` (lines 500-510)
4. Run all tests to ensure no regressions

**Example - Adding a new transformation**:
```javascript
// In index.js, add to the normalization chain:
.replace(/\[new_problematic_pattern\]/g, 'fixed_version')
```

### Manually Regenerating a Single Version

If a specific version has issues:
```bash
cd base/scripts/automation
node regenerate-release-notes.js 1.19.0  # Or any version
```

### Testing Against Other Paradox Games

The fix should work for other Paradox games. To test:

1. Modify `CK3_APP_ID` in `regenerate-release-notes.js` temporarily
2. Run regeneration for a test version
3. Check the output format

Example app IDs:
- Europa Universalis IV: `236850`
- Hearts of Iron IV: `394360`
- Stellaris: `281990`

## Troubleshooting

### Error: "Steam API blocked" or "ENOTFOUND"

The sandbox environment blocks Steam access. Solutions:
1. Run on a machine with internet access
2. Use GitHub Actions (has internet access)
3. Wait for the next automated update

### Error: "Invalid version format"

Version must be in format `x.x` or `x.x.x` or `x.x.x.x`:
- ✅ Valid: `1.18.1`, `1.18.0.2`, `1.13`
- ❌ Invalid: `v1.18.1`, `1.18.x`, `latest`

### Regeneration finds no events

The version might be too old or use a different naming:
1. Check Steam manually for the exact version format
2. Try alternate formats (e.g., `1.18` instead of `1.18.0`)
3. Increase `maxPages` in the script if very old

### Output still has escaped markers

1. Verify you're using the updated `index.js`
2. Check if it's a new BBCode pattern not covered
3. Run `node analyze-release-notes.js` to confirm
4. Add a new test case and update the normalization logic

## Documentation

- **BBCODE_FIX_README.md** - Detailed technical documentation
- **SECURITY_SUMMARY.md** - Security analysis and vulnerabilities
- **This file** - Practical usage instructions

## Support

For issues or questions:
1. Check existing GitHub issues
2. Review test scripts for examples
3. Create a new issue with:
   - Version number
   - Sample BBCode that's failing
   - Expected vs actual output
