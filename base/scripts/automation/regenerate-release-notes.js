#!/usr/bin/env node
// Script to re-fetch and regenerate specific release notes from Steam
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import bbobHTML from '@bbob/html';
import presetHTML5 from '@bbob/preset-html5';
import TurndownService from 'turndown';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CK3_APP_ID = '1158310';

function fetch(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

// Fetch and regenerate a specific version's release notes
async function regenerateReleaseNotes(version, outputDir) {
  // Validate version format to prevent injection attacks
  // Version must be in format: x.x or x.x.x or x.x.x.x where x is a number
  const versionPattern = /^[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$/;
  if (!versionPattern.test(version)) {
    console.error(`   ❌ Invalid version format: ${version}`);
    console.error(`      Version must match pattern: x.x or x.x.x or x.x.x.x (e.g., 1.18.1)`);
    return false;
  }
  
  console.log(`\n🔍 Fetching release notes for version ${version} from Steam...`);
  
  // Search for this version in Steam announcements
  let releaseEvent = null;
  let offset = 0;
  const pageSize = 100;
  const maxPages = 20;
  
  while (!releaseEvent && offset < maxPages * pageSize) {
    const eventsUrl = `https://store.steampowered.com/events/ajaxgetpartnereventspageable?` +
      `clan_accountid=0&appid=${CK3_APP_ID}&offset=${offset}&count=${pageSize}&l=english`;
    
    let eventsData;
    try {
      eventsData = JSON.parse(await fetch(eventsUrl));
    } catch (err) {
      console.error(`   ❌ Failed to parse Steam events API: ${err.message}`);
      return false;
    }
    
    if (!eventsData.events || eventsData.events.length === 0) {
      break;
    }
    
    // Search for exact version match
    // Escape special regex characters in version string to prevent regex injection
    const escapedVersion = version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const versionPattern = new RegExp(`\\b${escapedVersion}(?!\\.[0-9])(?:[^0-9]|$)`, 'i');
    
    releaseEvent = eventsData.events.find(event => {
      if (!event.event_name || !event.announcement_body?.body) return false;
      
      const eventName = event.event_name.toLowerCase();
      
      // Exclude dev diaries
      if (eventName.includes('dev diary') || eventName.includes('developer diary') ||
          eventName.includes('dev update') || eventName.includes('upcoming') ||
          eventName.includes('preview')) {
        return false;
      }
      
      return versionPattern.test(eventName);
    });
    
    if (!releaseEvent) {
      offset += pageSize;
    }
  }
  
  if (!releaseEvent) {
    console.error(`   ❌ Could not find release notes for version ${version}`);
    return false;
  }
  
  console.log(`   ✅ Found: "${releaseEvent.event_name}"`);
  
  const title = releaseEvent.event_name;
  const date = new Date(releaseEvent.announcement_body.posttime * 1000)
    .toISOString().split('T')[0];
  const url = `https://store.steampowered.com/news/app/${CK3_APP_ID}/view/${releaseEvent.gid}`;
  
  console.log(`   📅 Date: ${date}`);
  console.log(`   🔗 URL: ${url}`);
  
  // Get original BBCode
  const originalBBCode = releaseEvent.announcement_body.body;
  console.log(`   📝 Original BBCode length: ${originalBBCode.length} characters`);
  
  // Count issues in original
  const originalEscaped = (originalBBCode.match(/\\(\[|\])/g) || []).length;
  const originalHtml = (originalBBCode.match(/<\\?\*>/g) || []).length;
  console.log(`   ⚠️  Original issues: ${originalEscaped} escaped BBCode, ${originalHtml} HTML markers`);
  
  // Apply the FIXED normalization
  console.log(`\n🔧 Applying BBCode normalization fixes...`);
  let normalizedBBCode = originalBBCode
    // Unescape backslash-escaped BBCode markers (Steam escapes these)
    .replace(/\\(\[|\])/g, '$1')
    // Convert <\*> (backslash-escaped) markers to [*]
    .replace(/<\\\*>/g, '[*]')
    // Convert <*> markers to [*] (alternative BBCode list format)
    .replace(/<\*>/g, '[*]')
    // Fix unclosed [list] tags by adding [/list] before next heading or [list]
    .replace(/(\[list\](?:(?!\[\/list\]|\[list\]).)*?)(\n##?\s|\[list\]|$)/gs, '$1[/list]$2')
    // Fix list items with closing tags [*]...[/*] -> [*]...
    .replace(/\[\*\](.*?)\[\/\*\]/gs, '[*]$1')
    // Fix URL attributes: [url=link style=button] -> [url=link]
    .replace(/\[url=([^\s\]]+)\s+[^\]]*\]/gi, '[url=$1]')
    // Add https:// to URLs that are missing protocol
    .replace(/\[url=(?!https?:\/\/)([^\]]+)\]/gi, '[url=https://$1]');
  
  console.log(`   ✅ Normalized BBCode length: ${normalizedBBCode.length} characters`);
  
  // Convert BBCode to HTML
  console.log(`   🔄 Converting BBCode → HTML...`);
  const html = bbobHTML(normalizedBBCode, presetHTML5());
  
  // Convert HTML to Markdown
  console.log(`   🔄 Converting HTML → Markdown...`);
  const turndownService = new TurndownService({
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    bulletListMarker: '-'
  });
  const markdown = turndownService.turndown(html);
  
  // Build final content
  const versionSlug = version.split('.').concat(['0', '0', '0', '0']).slice(0, 4).join('_');
  const releaseNotesFile = `${versionSlug}_${date}.md`;
  const releaseNotesPath = path.join(outputDir, releaseNotesFile);
  
  const releaseNotesContent = `# ${title.replace(/^(Update|Hotfix|Rollback for Update) /, '')}

**Release Date:** ${date}
**Official Announcement:** ${url}

---

${markdown}
`;
  
  // Write file
  fs.writeFileSync(releaseNotesPath, releaseNotesContent);
  console.log(`\n✅ Regenerated: ${releaseNotesFile}`);
  
  // Verify improvements
  const finalEscaped = (releaseNotesContent.match(/\\(\[|\])/g) || []).length;
  const finalHtml = (releaseNotesContent.match(/<\\?\*>/g) || []).length;
  console.log(`   📊 Final result: ${finalEscaped} escaped BBCode, ${finalHtml} HTML markers`);
  console.log(`   📈 Improvement: ${originalEscaped - finalEscaped} escaped fixed, ${originalHtml - finalHtml} HTML markers fixed`);
  
  return true;
}

// Main
async function main() {
  const versions = process.argv.slice(2);
  
  if (versions.length === 0) {
    console.log(`
Usage: node regenerate-release-notes.js <version1> [version2] ...

Examples:
  node regenerate-release-notes.js 1.18.1
  node regenerate-release-notes.js 1.18.0 1.18.1 1.17.0 1.13.0
`);
    process.exit(1);
  }
  
  const outputDir = path.join(__dirname, '../../release-notes');
  
  console.log('🚀 Starting release notes regeneration...');
  console.log(`   Output directory: ${outputDir}`);
  
  let successCount = 0;
  
  for (const version of versions) {
    const success = await regenerateReleaseNotes(version, outputDir);
    if (success) successCount++;
    
    // Rate limit between requests
    if (versions.indexOf(version) < versions.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
  
  console.log(`\n${'='.repeat(70)}`);
  console.log(`\n✅ Regeneration complete: ${successCount}/${versions.length} successful`);
}

main().catch(err => {
  console.error('\n❌ Error:', err.message);
  if (process.env.DEBUG) console.error(err.stack);
  process.exit(1);
});
