#!/usr/bin/env node
// Script to download original BBCode fixtures from Steam for backtesting
// This fetches the raw BBCode from Steam API and saves it for testing purposes

import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

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

function validateVersion(version) {
  if (!version || typeof version !== 'string') {
    return false;
  }
  const versionPattern = /^[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$/;
  return versionPattern.test(version);
}

async function downloadFixture(version, outputDir) {
  console.log(`\n📥 Downloading BBCode fixture for version ${version}...`);
  
  // Validate version format
  if (!validateVersion(version)) {
    console.error(`   ❌ Invalid version format: ${version}`);
    console.error(`      Version must match: x.x or x.x.x or x.x.x.x (e.g., 1.18.1)`);
    return false;
  }
  
  // Search for this version in Steam announcements
  let releaseEvent = null;
  let offset = 0;
  const pageSize = 100;
  const maxPages = 20;
  
  // Escape special regex characters for safe regex construction
  const escapedVersion = version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const versionPattern = new RegExp(`\\b${escapedVersion}(?!\\.[0-9])(?:[^0-9]|$)`, 'i');
  
  while (!releaseEvent && offset < maxPages * pageSize) {
    const eventsUrl = `https://store.steampowered.com/events/ajaxgetpartnereventspageable?` +
      `clan_accountid=0&appid=${CK3_APP_ID}&offset=${offset}&count=${pageSize}&l=english`;
    
    let eventsData;
    try {
      eventsData = JSON.parse(await fetch(eventsUrl));
    } catch (err) {
      console.error(`   ❌ Failed to fetch Steam events: ${err.message}`);
      return false;
    }
    
    if (!eventsData.events || eventsData.events.length === 0) {
      break;
    }
    
    // Search for exact version match
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
      await new Promise(resolve => setTimeout(resolve, 100)); // Rate limiting
    }
  }
  
  if (!releaseEvent) {
    console.error(`   ❌ Could not find release notes for version ${version}`);
    console.error(`      Searched ${offset} announcements on Steam`);
    return false;
  }
  
  console.log(`   ✅ Found: "${releaseEvent.event_name}"`);
  
  const title = releaseEvent.event_name;
  const date = new Date(releaseEvent.announcement_body.posttime * 1000)
    .toISOString().split('T')[0];
  const url = `https://store.steampowered.com/news/app/${CK3_APP_ID}/view/${releaseEvent.gid}`;
  const originalBBCode = releaseEvent.announcement_body.body;
  
  console.log(`   📅 Date: ${date}`);
  console.log(`   🔗 URL: ${url}`);
  console.log(`   📝 BBCode length: ${originalBBCode.length} characters`);
  
  // Count issues in original BBCode
  const escapedBrackets = (originalBBCode.match(/\\(\[|\])/g) || []).length;
  const htmlMarkers = (originalBBCode.match(/<\\?\*>/g) || []).length;
  const listTags = (originalBBCode.match(/\[list\]/g) || []).length;
  const listCloseTags = (originalBBCode.match(/\[\/list\]/g) || []).length;
  const unclosedLists = listTags - listCloseTags;
  
  console.log(`   📊 Analysis:`);
  console.log(`      - Escaped brackets: ${escapedBrackets}`);
  console.log(`      - HTML-like markers: ${htmlMarkers}`);
  console.log(`      - Unclosed lists: ${unclosedLists > 0 ? unclosedLists : 0}`);
  
  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  // Normalize version to 4 parts for filename
  const normalizedVersion = version.split('.').concat(['0', '0', '0', '0']).slice(0, 4).join('_');
  const fixtureFile = `${normalizedVersion}_${date}.bbcode`;
  const fixtureMetaFile = `${normalizedVersion}_${date}.json`;
  const fixturePath = path.join(outputDir, fixtureFile);
  const fixtureMetaPath = path.join(outputDir, fixtureMetaFile);
  
  // Save BBCode fixture
  fs.writeFileSync(fixturePath, originalBBCode);
  
  // Save metadata
  const metadata = {
    version,
    title,
    date,
    url,
    bbcode_length: originalBBCode.length,
    analysis: {
      escaped_brackets: escapedBrackets,
      html_markers: htmlMarkers,
      list_tags: listTags,
      list_close_tags: listCloseTags,
      unclosed_lists: Math.max(0, unclosedLists)
    }
  };
  fs.writeFileSync(fixtureMetaPath, JSON.stringify(metadata, null, 2));
  
  console.log(`   💾 Saved fixture: ${fixtureFile}`);
  console.log(`   💾 Saved metadata: ${fixtureMetaFile}`);
  
  return true;
}

async function downloadAllFixtures(outputDir) {
  console.log('📥 Downloading BBCode fixtures for all CK3 releases...\n');
  
  // Get list of versions from existing release notes
  const releaseNotesDir = path.join(__dirname, '../../release-notes');
  const existingFiles = fs.readdirSync(releaseNotesDir)
    .filter(f => f.endsWith('.md'))
    .map(f => {
      const match = f.match(/^(\d+)_(\d+)_(\d+)_(\d+)_/);
      if (match) {
        // Convert to version format (remove trailing zeros)
        let version = `${match[1]}.${match[2]}.${match[3]}`;
        if (match[4] !== '0') {
          version += `.${match[4]}`;
        } else if (match[3] === '0') {
          version = `${match[1]}.${match[2]}`;
        }
        return version;
      }
      return null;
    })
    .filter(v => v !== null)
    .sort();
  
  console.log(`Found ${existingFiles.length} release notes to download fixtures for\n`);
  
  let successCount = 0;
  let failCount = 0;
  
  for (const version of existingFiles) {
    const success = await downloadFixture(version, outputDir);
    if (success) {
      successCount++;
    } else {
      failCount++;
    }
    
    // Rate limit between requests
    if (existingFiles.indexOf(version) < existingFiles.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
  
  console.log(`\n${'='.repeat(70)}`);
  console.log(`\n📊 Download Summary:`);
  console.log(`   ✅ Successful: ${successCount}`);
  console.log(`   ❌ Failed: ${failCount}`);
  console.log(`   📁 Output directory: ${outputDir}`);
  
  return successCount > 0;
}

// Main
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  
  if (command === 'all') {
    const outputDir = args[1] || path.join(__dirname, '../../fixtures');
    await downloadAllFixtures(outputDir);
  } else if (command && command !== '--help' && command !== '-h') {
    // Treat as version number(s)
    const versions = args.slice(0, -1);
    const outputDir = args[args.length - 1];
    
    // Check if last arg is a directory or version
    const lastArgIsDir = outputDir && (outputDir.includes('/') || outputDir.includes('\\'));
    
    if (!lastArgIsDir) {
      console.error(`❌ Error: Last argument must be output directory path`);
      console.error(`   Example: node download-fixtures.js 1.18.1 1.18.0 ./fixtures`);
      process.exit(1);
    }
    
    console.log(`📥 Downloading ${versions.length} BBCode fixture(s)...\n`);
    
    let successCount = 0;
    for (const version of versions) {
      const success = await downloadFixture(version, outputDir);
      if (success) successCount++;
      
      if (versions.indexOf(version) < versions.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    console.log(`\n${'='.repeat(70)}`);
    console.log(`\n✅ Downloaded ${successCount}/${versions.length} fixtures`);
  } else {
    console.log(`
Download BBCode Fixtures from Steam

Usage:
  node download-fixtures.js all [output-dir]
      Download fixtures for all existing release notes
      Default output: base/fixtures/

  node download-fixtures.js <version1> [version2] ... <output-dir>
      Download fixtures for specific versions
      Example: node download-fixtures.js 1.18.1 1.18.0 ./fixtures

  node download-fixtures.js --help
      Show this help message

Examples:
  # Download all fixtures to default directory
  node download-fixtures.js all

  # Download all fixtures to custom directory
  node download-fixtures.js all /tmp/ck3-fixtures

  # Download specific versions
  node download-fixtures.js 1.18.1 1.18.0 1.17.0 ./fixtures

What are fixtures?
  Fixtures are the original BBCode from Steam before conversion.
  They're used to backtest the BBCode parsing logic to ensure
  the fix handles all edge cases correctly.

Output:
  - *.bbcode files: Original BBCode content from Steam
  - *.json files: Metadata (version, URL, analysis stats)
`);
    process.exit(command ? 0 : 1);
  }
}

main().catch(err => {
  console.error('\n❌ Error:', err.message);
  if (process.env.DEBUG) console.error(err.stack);
  process.exit(1);
});
