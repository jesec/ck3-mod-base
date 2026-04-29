#!/usr/bin/env node
// CK3 Mod Base Utility
// Consolidated utility for managing CK3 mod base repository

import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync, execFileSync } from 'child_process';
import { createHash } from 'crypto';
import SteamTotp from 'steam-totp';
import protobuf from 'protobufjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Constants
const CK3_APP_ID = '1158310';
const PROTOBUF_PAYLOAD_MAGIC = 0x71F617D0;
const PROTOBUF_METADATA_MAGIC = 0x1F4812BE;

// Protobuf definition
const PROTO_DEF = `
syntax = "proto2";

message ContentManifestMetadata {
  optional uint32 depot_id = 1;
  optional uint64 gid_manifest = 2;
  optional uint32 creation_time = 3;
  optional bool filenames_encrypted = 4;
  optional uint64 cb_disk_original = 5;
  optional uint64 cb_disk_compressed = 6;
  optional uint32 unique_chunks = 7;
  optional uint32 crc_encrypted = 8;
  optional uint32 crc_clear = 9;
}
`;

let protoRoot = null;

// Utility functions
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
  // Version must be in format: x.x or x.x.x or x.x.x.x where x is a number
  const versionPattern = /^[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$/;
  return versionPattern.test(version);
}

function parseManifest(manifestPath) {
  try {
    if (!protoRoot) {
      protoRoot = protobuf.parse(PROTO_DEF).root;
    }

    const ContentManifestMetadata = protoRoot.lookupType('ContentManifestMetadata');
    const buffer = fs.readFileSync(manifestPath);

    let offset = 0;

    // Skip payload section
    const payloadMagic = buffer.readUInt32LE(offset);
    if (payloadMagic !== PROTOBUF_PAYLOAD_MAGIC) {
      throw new Error(`Invalid payload magic: 0x${payloadMagic.toString(16)}`);
    }
    offset += 4;

    const payloadSize = buffer.readUInt32LE(offset);
    offset += 4;
    offset += payloadSize;

    // Read metadata section
    const metadataMagic = buffer.readUInt32LE(offset);
    if (metadataMagic !== PROTOBUF_METADATA_MAGIC) {
      throw new Error(`Invalid metadata magic: 0x${metadataMagic.toString(16)}`);
    }
    offset += 4;

    const metadataSize = buffer.readUInt32LE(offset);
    offset += 4;

    const metadataBytes = buffer.slice(offset, offset + metadataSize);
    const message = ContentManifestMetadata.decode(metadataBytes);
    const obj = ContentManifestMetadata.toObject(message);

    if (obj.creationTime) {
      const timestamp = Number(obj.creationTime);
      const date = new Date(timestamp * 1000);
      return date.toISOString();
    }

    return null;
  } catch (err) {
    console.error(`  Warning: Failed to parse ${path.basename(manifestPath)}: ${err.message}`);
    return null;
  }
}

// Compare two "X.Y[.Z[.W]]" version strings numerically. Missing segments = 0.
function compareSemver(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const x = pa[i] || 0;
    const y = pb[i] || 0;
    if (x !== y) return x - y;
  }
  return 0;
}

// Write key=value lines to $GITHUB_OUTPUT if the env var is set (no-op otherwise).
function emitGithubOutput(pairs) {
  const file = process.env.GITHUB_OUTPUT;
  if (!file) return;
  const lines = Object.entries(pairs).map(([k, v]) => `${k}=${v}`).join('\n') + '\n';
  fs.appendFileSync(file, lines);
}

// Query Steam PICS anonymously and return the app's depots + branches dicts.
async function fetchPicsAppInfo(appId) {
  const SteamUser = (await import('steam-user')).default;
  const client = new SteamUser();

  const LOGIN_TIMEOUT_MS = 30000;
  const PICS_TIMEOUT_MS = 30000;

  await new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error(`Steam login timed out after ${LOGIN_TIMEOUT_MS}ms`)), LOGIN_TIMEOUT_MS);
    client.once('loggedOn', () => { clearTimeout(t); resolve(); });
    client.once('error', (err) => { clearTimeout(t); reject(err); });
    client.logOn({ anonymous: true });
  });

  try {
    const result = await Promise.race([
      client.getProductInfo([appId], [], true),
      new Promise((_, rej) => setTimeout(() => rej(new Error(`PICS query timed out after ${PICS_TIMEOUT_MS}ms`)), PICS_TIMEOUT_MS)),
    ]);
    const app = result?.apps?.[appId];
    if (!app) throw new Error(`App ${appId} not in PICS response`);
    return app.appinfo || {};
  } finally {
    try { client.logOff(); } catch { /* best effort */ }
  }
}

// Command: check
// Compares Steam PICS public-branch manifest GIDs against a stored .ck3-version.json.
// Additionally enumerates Paradox-published historical branches that are newer than
// our current version (for CI backfill).
//
// Exits 0 when the comparison completed (needs_update written to $GITHUB_OUTPUT).
// Exits 1 when the check itself failed (network error, missing app, etc.). Never
// silently reports "up to date" on error — the workflow must see the failure.
async function checkUpdate(storedFilePath) {
  const versionFile = path.resolve(storedFilePath || 'base/.ck3-version.json');
  let stored = { version: null, depots: {} };
  if (fs.existsSync(versionFile)) {
    try {
      stored = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
    } catch (err) {
      console.error(`⚠️  Could not parse ${versionFile}: ${err.message}`);
      stored = { version: null, depots: {} };
    }
  }
  const storedDepots = stored.depots || {};
  const storedVersion = stored.version || '0.0.0';

  console.log(`🔍 Querying Steam PICS for app ${CK3_APP_ID}...`);
  const appinfo = await fetchPicsAppInfo(Number(CK3_APP_ID));
  const depots = appinfo.depots || {};
  const branches = depots.branches || {};

  // Public branch manifest GIDs keyed by depot id.
  const liveDepots = {};
  for (const [key, value] of Object.entries(depots)) {
    if (!/^\d+$/.test(key)) continue;
    const gid = value?.manifests?.public?.gid;
    if (gid) liveDepots[key] = String(gid);
  }

  // Depot-level diff. Three buckets per live depot:
  //   - in stored with matching manifest  → no-op
  //   - in stored with different manifest → changed (patch landed)
  //   - in stored only (live removed it)  → changed (deprecated)
  //   - live-only AND in known_unowned    → ignored (filtered/unowned, stable)
  //   - live-only AND NOT in known_unowned → changed (possible ownership gain)
  //
  // known_unowned_depots is populated by parse() after each download: any
  // depot PICS reports for the app but DepotDownloader didn't produce a
  // manifest for (unowned DLC, filtered by -os/-language, etc.). This breaks
  // the retrigger loop: depots we can't download get recorded once; only
  // genuinely new depots (e.g. a DLC you just bought) trigger an update.
  //
  // Exception: on a first run (empty stored), treat every live depot as
  // "changed" so the repo gets seeded. parse() then populates both stored
  // and known_unowned from the download result.
  const firstRun = Object.keys(storedDepots).length === 0;
  const knownUnowned = new Set(
    Array.isArray(stored.known_unowned_depots) ? stored.known_unowned_depots.map(String) : []
  );
  const changed = [];
  const liveOnlyIgnored = [];

  for (const id of Object.keys(storedDepots)) {
    const s = storedDepots[id]?.manifest != null ? String(storedDepots[id].manifest) : null;
    const l = liveDepots[id] || null;
    if (s !== l) changed.push({ id, stored: s, live: l });
  }
  for (const id of Object.keys(liveDepots)) {
    if (id in storedDepots) continue;
    if (firstRun) {
      changed.push({ id, stored: null, live: liveDepots[id] });
    } else if (knownUnowned.has(id)) {
      liveOnlyIgnored.push({ id, live: liveDepots[id] });
    } else {
      // New depot, never-before-seen. Could be: (a) DLC we just purchased,
      // (b) new Paradox content depot, (c) DLC PICS exposed before the
      // workflow's Steam account gained access. Trigger — parse() will
      // classify it correctly on the next run.
      changed.push({ id, stored: null, live: liveDepots[id] });
    }
  }

  // Paradox-published historical branches newer than our stored version.
  // Branch names look like "1.18.3", "1.18.1.1", "open_beta", "avx_issue_hotfix", …
  // We only want versioned stable branches, ordered ascending so the workflow can
  // replay missed updates in release order. On a first run (no stored depots)
  // we skip backfill entirely — downloading every CK3 version ever is absurd;
  // seeding the repo from public is the right default.
  const intermediateVersions = firstRun
    ? []
    : Object.keys(branches)
        .filter(name => /^\d+\.\d+(\.\d+){0,2}$/.test(name))
        .filter(name => compareSemver(name, storedVersion) > 0)
        .sort(compareSemver);

  const publicBuildid = branches.public?.buildid ?? null;

  if (changed.length === 0) {
    console.log(`✅ Up to date (stored ${storedVersion}, public buildid ${publicBuildid})`);
    emitGithubOutput({ needs_update: 'false' });
    return;
  }

  console.log(`🆕 Update available`);
  console.log(`   stored version: ${storedVersion}`);
  console.log(`   public buildid: ${publicBuildid}`);
  console.log(`   changed depots: ${changed.length}`);
  for (const { id, stored: s, live: l } of changed) {
    console.log(`     depot ${id}: ${s ?? '(new)'} → ${l ?? '(removed)'}`);
  }
  if (liveOnlyIgnored.length > 0) {
    const list = liveOnlyIgnored.map(d => d.id).join(', ');
    console.log(`   live-only depots in known_unowned (ignored): ${list}`);
  }
  if (intermediateVersions.length > 0) {
    console.log(`   intermediate branches to backfill: ${intermediateVersions.join(', ')}`);
  } else {
    console.log(`   intermediate branches to backfill: (none — public is the only missing state)`);
  }

  emitGithubOutput({
    needs_update: 'true',
    current_version: storedVersion,
    public_buildid: String(publicBuildid ?? ''),
    changed_depots: changed.map(c => c.id).join(','),
    intermediate_versions: intermediateVersions.join(','),
  });
}

// Command: download
// Fetches a CK3 depot into outputDir via DepotDownloader. When `branch` is
// provided, downloads Paradox's named branch (e.g. "1.18.3") rather than the
// public/latest build — used for backfilling missed CI runs.
async function download(version, outputDir, branch) {
  if (version && version !== 'latest' && !validateVersion(version)) {
    console.error(`❌ Invalid version format: ${version}`);
    console.error('   Version must be in format: x.x or x.x.x or x.x.x.x (e.g., 1.18.0.2), or "latest"');
    process.exit(1);
  }

  const label = branch ? `branch ${branch}` : version ? `CK3 ${version}` : 'CK3 (public)';
  console.log(`📥 Downloading ${label}...\n`);

  const downloadDir = outputDir || '/tmp/ck3-download';
  console.log(`   Output directory: ${downloadDir}\n`);

  // Create output directory
  if (!fs.existsSync(downloadDir)) {
    fs.mkdirSync(downloadDir, { recursive: true });
  }

  console.log('🔄 Running DepotDownloader...\n');

  // Build environment variables
  const env = { ...process.env };
  if (process.env.STEAM_TOTP_SECRET) {
    // Generate TOTP code (valid for ~30 seconds)
    // DepotDownloader should use it immediately to avoid expiration
    env.STEAM_2FA_CODE = SteamTotp.generateAuthCode(process.env.STEAM_TOTP_SECRET);
    console.log('   Using TOTP-generated 2FA code for authentication');
  }

  try {
    const ddArgs = [
      '-no-mobile',
      '-app', CK3_APP_ID,
      '-os', 'windows',
      '-dir', downloadDir,
    ];
    if (branch) {
      ddArgs.push('-beta', branch);
    }
    execFileSync('DepotDownloader', ddArgs, {
      stdio: 'inherit',
      env,
    });
    console.log('\n✅ Download complete!');
  } catch (err) {
    console.error('\n❌ Download failed:', err.message);
    if (process.env.STEAM_TOTP_SECRET) {
      console.error('   Note: TOTP codes expire after 30 seconds. If authentication failed,');
      console.error('   the code may have expired. Try running the command again.');
    }
    if (err.stderr) console.error(err.stderr);
    process.exit(1);
  }
}

// Command: parse
async function parse(inputDir, outputDir, releaseNotesDir) {
  console.log(`📊 Parsing CK3 installation...\n`);

  const manifestDir = path.join(inputDir, '.DepotDownloader');

  if (!fs.existsSync(manifestDir)) {
    console.error(`❌ Error: Manifest directory not found: ${manifestDir}`);
    process.exit(1);
  }

  // 1. Extract depot information
  console.log('📦 Extracting depot information...');

  const manifestFiles = fs.readdirSync(manifestDir)
    .filter(f => f.endsWith('.manifest'))
    .map(f => {
      const match = f.match(/^(\d+)_(\d+)\.manifest$/);
      if (!match) return null;
      return {
        depot_id: match[1],
        manifest_id: match[2],
        file_path: path.join(manifestDir, f)
      };
    })
    .filter(x => x !== null)
    .sort((a, b) => parseInt(a.depot_id) - parseInt(b.depot_id));

  console.log(`   Found ${manifestFiles.length} depot manifests\n`);

  // Fetch DLC list
  console.log('🔍 Fetching DLC list from Steam...');
  let appDetails;
  try {
    appDetails = JSON.parse(
      await fetch(`https://store.steampowered.com/api/appdetails?appids=${CK3_APP_ID}`)
    );
  } catch (err) {
    console.error(`❌ Failed to parse Steam app details: ${err.message}`);
    process.exit(1);
  }

  const dlcIds = new Set(
    (appDetails[CK3_APP_ID]?.data?.dlc || []).map(id => id.toString())
  );

  console.log(`   Found ${dlcIds.size} DLCs in catalog\n`);

  // Build depot object
  const depots = {};
  let mostRecentTimestamp = null;

  for (const { depot_id, manifest_id, file_path } of manifestFiles) {
    const depotInfo = { manifest: manifest_id };

    // Parse manifest to get updated timestamp
    const updated = parseManifest(file_path);
    if (updated) {
      depotInfo.updated = updated;

      if (!mostRecentTimestamp || updated > mostRecentTimestamp) {
        mostRecentTimestamp = updated;
      }
    }

    // If this depot is a DLC, fetch its name
    if (dlcIds.has(depot_id)) {
      try {
        const dlcDetailsJson = await fetch(`https://store.steampowered.com/api/appdetails?appids=${depot_id}`);
        const dlcDetails = JSON.parse(dlcDetailsJson);

        const dlcName = dlcDetails[depot_id]?.data?.name;
        if (dlcName) {
          depotInfo.name = dlcName
            .replace(/^Crusader Kings III:\s*/, '')
            .replace(/^Crusader Kings III\s+/, '');
          console.log(`   ${depot_id}: ${depotInfo.name}`);
        }

        await new Promise(resolve => setTimeout(resolve, 200));
      } catch (e) {
        console.error(`   ${depot_id}: Failed to fetch/parse DLC details (${e.message})`);
      }
    }

    depots[depot_id] = depotInfo;
  }

  console.log(`\n✅ Processed ${Object.keys(depots).length} depots`);
  console.log(`📅 Most recent depot: ${mostRecentTimestamp}\n`);

  // 2. Read version from launcher-settings.json
  console.log('🔍 Reading version from launcher config...');

  const launcherSettingsPath = path.join(inputDir, 'launcher', 'launcher-settings.json');

  if (!fs.existsSync(launcherSettingsPath)) {
    console.error(`❌ Error: launcher-settings.json not found at: ${launcherSettingsPath}`);
    console.error('   This file should be in the downloaded game directory');
    process.exit(1);
  }

  let launcherSettings;
  try {
    launcherSettings = JSON.parse(fs.readFileSync(launcherSettingsPath, 'utf8'));
  } catch (err) {
    console.error(`❌ Failed to parse launcher-settings.json: ${err.message}`);
    process.exit(1);
  }

  const version = launcherSettings.rawVersion;
  const fullVersion = launcherSettings.version;

  if (!validateVersion(version)) {
    console.error(`❌ Invalid version format in launcher-settings.json: ${version}`);
    process.exit(1);
  }

  console.log(`   Version: ${version}`);
  console.log(`   Full version: ${fullVersion}`);

  // Extract version name from full version string (e.g., "1.18.0.2 (Crane)")
  let versionName = null;
  const nameMatch = fullVersion.match(/\(([^)]+)\)/);
  if (nameMatch) {
    versionName = nameMatch[1];
    console.log(`   Version name: ${versionName}`);
  }
  console.log('');

  // 3. Fetch and ensure all required release notes are present
  console.log('📝 Fetching release notes...');

  // Build list of required versions for this release
  // For 1.11.3: need [1.11.3, 1.11.2, 1.11.1, 1.11.0]
  // For 1.10.1.2: need [1.10.1.2, 1.10.1, 1.10.0]
  // For 1.10.1: need [1.10.1, 1.10.0]
  // For 1.10.0: need [1.10.0]
  const versionParts = version.split('.').map(v => parseInt(v));
  const requiredVersions = [];

  // Add current version
  requiredVersions.push(version);

  // If hotfix (x.y.z.w where w > 0), add the minor version (x.y.z.0)
  if (versionParts.length === 4 && versionParts[3] > 0) {
    requiredVersions.push(`${versionParts[0]}.${versionParts[1]}.${versionParts[2]}`);
  }

  // If minor or hotfix (x.y.z where z > 0), enumerate all intermediate patch versions back to x.y.0
  if (versionParts.length >= 3 && versionParts[2] > 0) {
    const patchVersion = versionParts.length === 4 ? versionParts[2] : versionParts[2];
    // Add all intermediate versions: x.y.(z-1), x.y.(z-2), ..., x.y.1, x.y.0
    for (let z = patchVersion - 1; z >= 0; z--) {
      requiredVersions.push(`${versionParts[0]}.${versionParts[1]}.${z}`);
    }
  }

  if (!fs.existsSync(releaseNotesDir)) {
    fs.mkdirSync(releaseNotesDir, { recursive: true });
  }

  // Load BBCode/Markdown converter (our custom direct conversion)
  const BBCodeParser = await import('./lib/bbcode-parser.js');

  // Helper function to fetch and save release notes for a version
  async function fetchAndSaveReleaseNotes(targetVersion) {
    // Normalize version to 4 parts for proper sorting (1.10 -> 1.10.0.0, 1.10.1 -> 1.10.1.0)
    const normalizedVersion = targetVersion.split('.').concat(['0', '0', '0', '0']).slice(0, 4).join('.');
    const versionSlug = normalizedVersion.replace(/\./g, '_');

    // Check if already exists - must match exactly version_date.md pattern
    const existingFiles = fs.readdirSync(releaseNotesDir);
    const existingFile = existingFiles.find(f => {
      const match = f.match(/^(.+)_(\d{4}-\d{2}-\d{2})\.md$/);
      return match && match[1] === versionSlug;
    });

    if (existingFile) {
      console.log(`   ${targetVersion}: already exists (${existingFile})`);
      return existingFile;
    }

    console.log(`   ${targetVersion}: searching...`);

    // Build search variants for this version
    // For "1.10.0": try ["1.10.0", "1.10"]
    // For "1.10.1": try ["1.10.1"]
    const searchVersions = [targetVersion];
    if (targetVersion.endsWith('.0')) {
      const shortened = targetVersion.replace(/\.0$/, '');
      searchVersions.push(shortened);
    }

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
        console.error(`   ${targetVersion}: Failed to parse Steam events API response: ${err.message}`);
        break;
      }

      if (!eventsData.events || eventsData.events.length === 0) {
        break;
      }

      // Try all search variants - search for exact matches first, then broader
      // For "1.11.0": first look for exactly "1.11.0" (not "1.11.0.1"), then "1.11"
      const isMajorRelease = targetVersion.endsWith('.0');

      for (const searchVersion of searchVersions) {
        releaseEvent = eventsData.events.find(event => {
          if (!event.event_name || !event.announcement_body?.body) return false;

          const eventName = event.event_name.toLowerCase();
          const eventBody = event.announcement_body.body.toLowerCase();
          const searchLower = searchVersion.toLowerCase();

          // Exclude dev diaries - check title first as it's most reliable
          if (eventName.includes('dev diary') ||
              eventName.includes('developer diary') ||
              eventName.includes('dev update') ||
              eventName.includes('upcoming') ||
              eventName.includes('preview')) {
            return false;
          }

          // Check if version appears in the event name
          // Pattern ensures version is not a substring (e.g., "1.12.1" shouldn't match "1.12.2.1")
          // Must be followed by a non-digit, or end of string, and NOT followed by a dot+digit
          const versionPattern = new RegExp(`\\b${searchLower.replace(/\./g, '\\.')}(?!\\.[0-9])(?:[^0-9]|$)`, 'i');
          const inTitle = versionPattern.test(eventName);

          // If version is in title, we found it
          if (inTitle) {
            // For major releases (.0 versions), exclude hotfix announcements
            if (isMajorRelease && (eventName.includes('hotfix') || eventBody.includes('hotfix'))) return false;
            return true;
          }

          // Title doesn't have version - check if this looks like a release announcement
          // that just has a marketing title (e.g., "Coronations - Available Now!")
          const hasReleaseTitle = eventName.includes('available now') ||
                                  eventName.includes('out now') ||
                                  eventName.includes('released');

          if (!hasReleaseTitle) return false;

          // Title looks like a release announcement - check body for version
          const inBody = versionPattern.test(eventBody);
          if (!inBody) return false;

          // Found version in body with release-like title - verify it's the main subject
          // Check that version appears near the beginning (first 500 chars)
          const bodyStart = eventBody.substring(0, 500);
          if (!versionPattern.test(bodyStart)) return false;

          // For major releases, exclude hotfixes
          if (isMajorRelease && (eventName.includes('hotfix') || eventBody.includes('hotfix'))) return false;

          return true;
        });
        if (releaseEvent) break;
      }

      if (!releaseEvent) {
        offset += pageSize;
      }
    }

    if (!releaseEvent) {
      console.error(`   ${targetVersion}: ❌ not found after checking ${offset} announcements`);
      return null;
    }

    // Convert and save
    const title = releaseEvent.event_name;
    const date = new Date(releaseEvent.announcement_body.posttime * 1000)
      .toISOString().split('T')[0];
    const url = `https://store.steampowered.com/news/app/${CK3_APP_ID}/view/${releaseEvent.gid}`;

    // Convert BBCode to Markdown using our custom parser
    const markdown = BBCodeParser.bbcodeToMarkdown(releaseEvent.announcement_body.body);

    const releaseNotesFile = `${versionSlug}_${date}.md`;
    const releaseNotesPath = path.join(releaseNotesDir, releaseNotesFile);
    const releaseNotesContent = `# ${title.replace(/^(Update|Hotfix|Rollback for Update) /, '')}

**Release Date:** ${date}
**Official Announcement:** ${url}

---

${markdown}
`;

    fs.writeFileSync(releaseNotesPath, releaseNotesContent);
    console.log(`   ${targetVersion}: ✅ saved as ${releaseNotesFile}`);

    return releaseNotesFile;
  }

  // Fetch all required release notes (best-effort)
  // Process in reverse order (oldest first) so parent versions are available
  const releaseNotesFiles = {};
  for (const reqVersion of requiredVersions.slice().reverse()) {
    const filename = await fetchAndSaveReleaseNotes(reqVersion);
    if (filename) {
      releaseNotesFiles[reqVersion] = filename;
    } else {
      // Just warn for versions we can't find
      console.log(`   ${reqVersion}: ⚠️  skipping (not found)`);
    }
  }

  // Ensure we have at least ONE release note file
  if (Object.keys(releaseNotesFiles).length === 0) {
    console.error(`\n❌ Failed to find any release notes for version ${version} or its parent versions`);
    process.exit(1);
  }

  console.log('');

  // 3. Create version metadata
  console.log('📄 Creating version metadata...');

  // Use the most appropriate release notes file (prefer current version, fall back to parent)
  let currentReleaseNotesFile = releaseNotesFiles[version];
  if (!currentReleaseNotesFile) {
    // Use the most recent parent version's release notes
    const availableVersions = Object.keys(releaseNotesFiles).sort().reverse();
    currentReleaseNotesFile = releaseNotesFiles[availableVersions[0]];
    console.log(`   Using ${availableVersions[0]} release notes (current version not found)`);
  }
  const currentReleaseNotesPath = path.join(releaseNotesDir, currentReleaseNotesFile);
  const currentReleaseNotesContent = fs.readFileSync(currentReleaseNotesPath, 'utf8');

  // Extract title, date, and URL from the markdown file
  const titleMatch = currentReleaseNotesContent.match(/^# (.+)$/m);
  const dateMatch = currentReleaseNotesContent.match(/\*\*Release Date:\*\* (.+)$/m);
  const urlMatch = currentReleaseNotesContent.match(/\*\*Official Announcement:\*\* (.+)$/m);

  const title = titleMatch ? titleMatch[1] : version;
  const date = dateMatch ? dateMatch[1] : new Date().toISOString().split('T')[0];
  const url = urlMatch ? urlMatch[1] : '';

  // Reconcile the downloaded depot set against Steam's PICS public-branch
  // depot declaration for this app. Two things happen here:
  //   1. Drop any downloaded depot that PICS doesn't list with a public
  //      manifest. DepotDownloader pulls shared Steamworks redist depots
  //      (e.g. 228981, 228988) alongside the app's own depots; these aren't
  //      CK3 content, they're Steam-SDK runtime data. PICS may keep stub
  //      entries for them (key present, no `.manifests.public.gid`) — the
  //      filter must require an actual public manifest, not just the key.
  //   2. Compute known_unowned_depots = PICS live set − downloaded set. These
  //      are CK3 depots the workflow's Steam account doesn't own, or that
  //      DepotDownloader's -os/-language filters exclude. Recording them
  //      prevents the check() loop from re-flagging them as "new" each run.
  let knownUnowned = [];
  try {
    console.log('🔍 Reconciling live depot list against what was downloaded...');
    const appinfo = await fetchPicsAppInfo(Number(CK3_APP_ID));
    const liveDepotIds = new Set(
      Object.entries(appinfo.depots || {})
        .filter(([k, v]) => /^\d+$/.test(k) && v?.manifests?.public?.gid)
        .map(([k]) => k)
    );

    // Filter downloaded depots against PICS-with-public-manifest
    const dropped = [];
    for (const id of Object.keys(depots)) {
      if (!liveDepotIds.has(id)) {
        dropped.push(id);
        delete depots[id];
      }
    }
    if (dropped.length > 0) {
      console.log(`   Dropped ${dropped.length} downloaded depot(s) not in PICS public set: ${dropped.join(', ')}`);
    }

    knownUnowned = Array.from(liveDepotIds)
      .filter(id => !(id in depots))
      .sort((a, b) => Number(a) - Number(b));
    if (knownUnowned.length > 0) {
      console.log(`   ${knownUnowned.length} live depot(s) recorded as known_unowned: ${knownUnowned.join(', ')}`);
    } else {
      console.log('   No live depots outside the downloaded set.');
    }
  } catch (err) {
    console.error(`⚠️  Could not fetch PICS to reconcile depots: ${err.message}`);
    console.error('   .ck3-version.json will omit known_unowned_depots and keep DD\'s full depot set.');
  }

  const metadata = {
    version: version,
    ...(versionName && { version_name: versionName }),
    updated: mostRecentTimestamp || new Date().toISOString(),
    release_notes: {
      title: title,
      date: date,
      file: `release-notes/${currentReleaseNotesFile}`,
      url: url
    },
    depots: depots,
    ...(knownUnowned.length > 0 && { known_unowned_depots: knownUnowned })
  };

  const metadataPath = path.join(outputDir, '.ck3-version.json');
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2) + '\n');

  console.log(`   Saved to: ${metadataPath}\n`);

  console.log('✅ Parse complete!');
  console.log(`   Version: ${version}${versionName ? ' (' + versionName + ')' : ''}`);
  console.log(`   Updated: ${mostRecentTimestamp}`);
  console.log(`   Depots: ${Object.keys(depots).length}`);
  console.log(`   Release notes: ${Object.values(releaseNotesFiles).length} file(s) - ${Object.values(releaseNotesFiles).join(', ')}`);
}

// Command: extract
async function extract(inputDir, outputDir, excludeExtensions) {
  console.log(`📂 Extracting files from CK3 installation...\n`);

  // Files to skip entirely (no placeholder) - engine binaries that can't be modded
  const skipExtensions = [
    '.dll', '.dylib', '.exe', '.so', '.a', '.lib', '.pyd', '.node'
  ];

  // Binary file extensions to replace with metadata placeholders
  const binaryExtensions = excludeExtensions ? excludeExtensions.split(',') : [
    // Image Files
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tga', '.dds', '.ico', '.svg',
    '.webp', '.tiff', '.tif', '.psd', '.xcf',
    // Audio Files
    '.mp3', '.wav', '.ogg', '.flac', '.m4a', '.aac', '.wma', '.opus', '.ape', '.bank',
    // Video Files
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.mpg', '.mpeg', '.bk2',
    // Font Files
    '.ttf', '.otf', '.woff', '.woff2', '.eot', '.font', '.fnt',
    // Archive Files
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.tgz', '.tbz2',
    // Document Files
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    // Database Files
    '.db', '.sqlite', '.sqlite3', '.mdb', '.accdb',
    // Compiled Code
    '.o', '.obj', '.pyc', '.pyo', '.class', '.jar', '.war', '.ear', '.dex', '.apk',
    // Binary Data Files
    '.bin', '.dat', '.data', '.pak', '.cache',
    // Game/3D Assets
    '.anim', '.mesh', '.asset', '.fbx', '.3ds', '.blend', '.obj', '.gfx', '.shader', '.sav', '.cur',
    // Certificate & Key Files
    '.pfx', '.p12', '.jks', '.keystore', '.cer', '.crt', '.der', '.pem', '.key',
    // Log Files
    '.log',
    // Temporary Files
    '.tmp', '.temp', '.bak', '.backup'
  ];

  console.log(`   Input: ${inputDir}`);
  console.log(`   Output: ${outputDir}`);
  console.log(`   Excluding binary extensions: ${binaryExtensions.length} types\n`);

  if (!fs.existsSync(inputDir)) {
    console.error(`❌ Error: Input directory not found: ${inputDir}`);
    process.exit(1);
  }

  // Require output directory to be empty or non-existent
  if (fs.existsSync(outputDir)) {
    const files = fs.readdirSync(outputDir);
    if (files.length > 0) {
      console.error(`❌ Error: Output directory must be empty: ${outputDir}`);
      console.error(`   Please remove it first with: rm -rf ${outputDir}`);
      process.exit(1);
    }
  } else {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  let copiedFiles = 0;
  let placeholderFiles = 0;
  let skippedFiles = 0;
  let totalSize = 0;
  let skippedSize = 0;

  function calculateHash(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    const hash = createHash('sha256');
    hash.update(fileBuffer);
    return hash.digest('hex');
  }

  function walkDir(dir, baseDir) {
    const files = fs.readdirSync(dir);

    for (const file of files) {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);

      if (stat.isDirectory()) {
        if (file !== '.DepotDownloader') {
          walkDir(filePath, baseDir);
        }
      } else {
        const ext = path.extname(file).toLowerCase();

        // Skip engine binaries entirely (no placeholder)
        if (skipExtensions.includes(ext)) {
          skippedFiles++;
          skippedSize += stat.size;
          continue;
        }

        const relativePath = path.relative(baseDir, filePath);
        const targetPath = path.join(outputDir, relativePath);
        const targetDir = path.dirname(targetPath);

        if (!fs.existsSync(targetDir)) {
          fs.mkdirSync(targetDir, { recursive: true });
        }

        // Check if this is a binary file (create placeholder)
        if (binaryExtensions.includes(ext)) {
          // Create placeholder with same filename, but JSON metadata as content
          const hash = calculateHash(filePath);
          const metadata = {
            size: stat.size,
            sha256: hash,
            note: 'Binary file excluded from repository. Metadata only.'
          };

          fs.writeFileSync(targetPath, JSON.stringify(metadata, null, 2) + '\n');
          placeholderFiles++;
          skippedSize += stat.size;
        } else {
          // Copy text/script file
          fs.copyFileSync(filePath, targetPath);
          copiedFiles++;
          totalSize += stat.size;
        }
      }
    }
  }

  console.log('🔄 Extracting files...\n');
  walkDir(inputDir, inputDir);

  console.log(`\n✅ Extraction complete!`);
  console.log(`   Text files copied: ${copiedFiles}`);
  console.log(`   Binary placeholders: ${placeholderFiles}`);
  console.log(`   Engine files skipped: ${skippedFiles}`);
  console.log(`   Copied size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`   Skipped size: ${(skippedSize / 1024 / 1024).toFixed(2)} MB`);
}

// Main CLI
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command) {
    console.log(`
CK3 Mod Base Utility

Usage:
  node index.js <command> [options]

  check [stored-file]
      Query Steam PICS for CK3 depot state and compare against a stored
      .ck3-version.json (default: ./base/.ck3-version.json). Anonymous
      login; no Steam credentials needed. Writes needs_update,
      current_version, public_buildid, changed_depots, intermediate_versions
      to $GITHUB_OUTPUT when set. Exits 0 when the query succeeded
      (regardless of outcome); exits 1 when the query itself failed.

  download <version|"latest"> <output-dir> [branch]
      Download CK3 files using DepotDownloader (Windows version).
      Pass a Paradox branch name (e.g. "1.18.3") to fetch a specific
      historical build, or omit to fetch the public/latest branch.
      Requires environment variables:
        - STEAM_USERNAME: Steam account username
        - STEAM_PASSWORD: Steam account password
        - STEAM_TOTP_SECRET: (optional) Shared secret for automatic 2FA code generation
      Example: STEAM_USERNAME=x STEAM_PASSWORD=y node index.js download latest /tmp/ck3
      Example: STEAM_USERNAME=x STEAM_PASSWORD=y node index.js download 1.18.3 /tmp/ck3 1.18.3

  parse <input-dir> <output-dir> <release-notes-dir>
      Parse downloaded files, auto-detect version from depot timestamps,
      extract depot info, fetch release notes, create metadata
      Example: parse /tmp/ck3-download .. ../release-notes

  extract <input-dir> <output-dir> [exclude-extensions]
      Extract files from CK3 installation (blacklist approach)
      Copies all files except binary formats, creating .meta placeholders with hash/size
      Exclude extensions: comma-separated list (default: images, audio, video, etc.)
      Note: Input should be the game/ subdirectory, not the full download (to exclude launcher/)
      Example: extract /tmp/ck3-download/game ../game
      Example: extract /tmp/ck3-download/game ../game .dds,.wav  # Custom exclusions

Examples:
  node index.js check                           # Print latest version
  node index.js check 1.18.0.2                  # Compare against version

  # Download example:
  STEAM_USERNAME=myuser STEAM_PASSWORD=mypass STEAM_TOTP_SECRET=mysecret \\
    node index.js download 1.18.0.2 /tmp/ck3-download

  node index.js parse /tmp/ck3-download .. ../release-notes
  node index.js extract /tmp/ck3-download/game ../game
`);
    process.exit(0);
  }

  try {
    switch (command) {
      case 'check':
        await checkUpdate(args[1]);
        break;

      case 'download':
        await download(args[1], args[2], args[3]);
        break;

      case 'parse':
        await parse(args[1], args[2], args[3]);
        break;

      case 'extract':
        await extract(args[1], args[2], args[3]);
        break;

      default:
        console.error(`❌ Unknown command: ${command}`);
        console.error('Run without arguments to see usage');
        process.exit(1);
    }
  } catch (err) {
    console.error(`\n❌ Error: ${err.message}`);
    if (process.env.DEBUG) {
      console.error(err.stack);
    }
    process.exit(1);
  }
}

main();
