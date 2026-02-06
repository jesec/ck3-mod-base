#!/usr/bin/env node
// Test script for version detection logic
// This validates the compareVersions function and announcement parsing logic

// Copy the functions directly to test them
function compareVersions(v1, v2) {
  const parts1 = v1.split('.').map(n => parseInt(n) || 0);
  const parts2 = v2.split('.').map(n => parseInt(n) || 0);

  // Pad to same length
  while (parts1.length < 4) parts1.push(0);
  while (parts2.length < 4) parts2.push(0);

  for (let i = 0; i < 4; i++) {
    if (parts1[i] > parts2[i]) return 1;
    if (parts1[i] < parts2[i]) return -1;
  }

  return 0;
}

function validateVersion(version) {
  if (!version || typeof version !== 'string') {
    return false;
  }
  // Version must be in format: x.x or x.x.x or x.x.x.x where x is a number
  const versionPattern = /^[0-9]+\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$/;
  return versionPattern.test(version);
}

console.log('═══════════════════════════════════════════════════════');
console.log('  Version Detection Test Suite');
console.log('═══════════════════════════════════════════════════════\n');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function test(description, fn) {
  totalTests++;
  try {
    fn();
    console.log(`✅ PASS: ${description}`);
    passedTests++;
  } catch (err) {
    console.log(`❌ FAIL: ${description}`);
    console.log(`   ${err.message}`);
    failedTests++;
  }
}

function assertEquals(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}. ${message || ''}`);
  }
}

console.log('Test Group 1: Version Comparison Function');
console.log('─────────────────────────────────────────────────────\n');

test('1.18.3 > 1.18.2', () => {
  assertEquals(compareVersions('1.18.3', '1.18.2'), 1, 'Should return 1');
});

test('1.18.2 < 1.18.3', () => {
  assertEquals(compareVersions('1.18.2', '1.18.3'), -1, 'Should return -1');
});

test('1.18.2 == 1.18.2', () => {
  assertEquals(compareVersions('1.18.2', '1.18.2'), 0, 'Should return 0');
});

test('1.18.2.0 == 1.18.2', () => {
  assertEquals(compareVersions('1.18.2.0', '1.18.2'), 0, 'Should normalize and compare equal');
});

test('1.18.3.1 > 1.18.3', () => {
  assertEquals(compareVersions('1.18.3.1', '1.18.3'), 1, 'Hotfix version should be greater');
});

test('2.0.0 > 1.18.3', () => {
  assertEquals(compareVersions('2.0.0', '1.18.3'), 1, 'Major version bump');
});

test('1.19.0 > 1.18.9', () => {
  assertEquals(compareVersions('1.19.0', '1.18.9'), 1, 'Minor version comparison');
});

test('1.18.10 > 1.18.9', () => {
  assertEquals(compareVersions('1.18.10', '1.18.9'), 1, 'Double digit patch versions');
});

console.log('\nTest Group 2: Version Validation');
console.log('─────────────────────────────────────────────────────\n');

test('Valid: 1.18.3', () => {
  assertEquals(validateVersion('1.18.3'), true, 'Standard version should be valid');
});

test('Valid: 1.18.3.0', () => {
  assertEquals(validateVersion('1.18.3.0'), true, 'Four-part version should be valid');
});

test('Valid: 1.18', () => {
  assertEquals(validateVersion('1.18'), true, 'Two-part version should be valid');
});

test('Invalid: null', () => {
  assertEquals(validateVersion(null), false, 'Null should be invalid');
});

test('Invalid: empty string', () => {
  assertEquals(validateVersion(''), false, 'Empty string should be invalid');
});

test('Invalid: abc', () => {
  assertEquals(validateVersion('abc'), false, 'Non-numeric should be invalid');
});

test('Invalid: 1.18.x', () => {
  assertEquals(validateVersion('1.18.x'), false, 'Non-numeric parts should be invalid');
});

console.log('\nTest Group 3: Announcement Parsing Simulation');
console.log('─────────────────────────────────────────────────────\n');

// Simulate the announcement parsing logic
function findHighestVersion(events) {
  const patchEvents = events.filter(event =>
    /^(Update|Hotfix|Rollback for Update) [0-9]+\.[0-9]+/.test(event.event_name) &&
    !event.event_name.includes('Available')
  );

  let highestVersion = null;
  for (const event of patchEvents) {
    const match = event.event_name.match(/([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)/);
    if (match && validateVersion(match[1])) {
      const eventVersion = match[1];
      if (!highestVersion || compareVersions(eventVersion, highestVersion) > 0) {
        highestVersion = eventVersion;
      }
    }
  }
  return highestVersion;
}

test('Find highest from unordered announcements', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.1' },
    { event_name: 'Hotfix 1.18.2' },
    { event_name: 'Update 1.18.0' },
    { event_name: 'Update 1.18.3' },
    { event_name: 'Update 1.17.0' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.3', 'Should find 1.18.3 as highest');
});

test('Ignore dev diaries and other non-patch announcements', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.2' },
    { event_name: 'Dev Diary: Upcoming Features' },
    { event_name: 'DLC Available Now!' },
    { event_name: 'Update 1.18.1' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.2', 'Should ignore non-patch events');
});

test('Ignore "Available" announcements', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.2' },
    { event_name: 'Update 1.18.3 Available' },
    { event_name: 'Update 1.18.1' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.2', 'Should ignore "Available" announcements');
});

test('Handle hotfix versions correctly', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.0' },
    { event_name: 'Hotfix 1.18.0.1' },
    { event_name: 'Hotfix 1.18.0.2' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.0.2', 'Should find 1.18.0.2 as highest hotfix');
});

test('Handle rollback announcements', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.2' },
    { event_name: 'Rollback for Update 1.18.1' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.2', 'Should still find 1.18.2 as highest');
});

console.log('\nTest Group 4: Edge Cases');
console.log('─────────────────────────────────────────────────────\n');

test('No valid announcements', () => {
  const mockEvents = [
    { event_name: 'Dev Diary' },
    { event_name: 'Community Event' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, null, 'Should return null when no patches found');
});

test('Empty event list', () => {
  const mockEvents = [];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, null, 'Should return null for empty list');
});

test('Mixed valid and invalid version formats', () => {
  const mockEvents = [
    { event_name: 'Update 1.18.2' },
    { event_name: 'Update invalid' },
    { event_name: 'Update 1.18.3' },
  ];
  const result = findHighestVersion(mockEvents);
  assertEquals(result, '1.18.3', 'Should skip invalid formats');
});

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Test Results');
console.log('═══════════════════════════════════════════════════════\n');

console.log(`Total tests:  ${totalTests}`);
console.log(`Passed:       ${passedTests} ✅`);
console.log(`Failed:       ${failedTests} ❌`);

if (failedTests === 0) {
  console.log('\n🎉 All tests passed!');
  console.log('\nThe version detection logic correctly:');
  console.log('  • Compares version numbers numerically (1.18.3 > 1.18.2)');
  console.log('  • Finds the highest version from unordered announcements');
  console.log('  • Handles hotfix versions (1.18.0.2)');
  console.log('  • Ignores non-patch announcements');
  console.log('  • Validates version format correctly');
  process.exit(0);
} else {
  console.log('\n⚠️  Some tests failed!');
  process.exit(1);
}
