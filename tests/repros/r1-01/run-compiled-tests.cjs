// Run after serialized moon test <package> --target js -j 1 --build-only.
// Direct Moon JS drivers can exit zero on assertion failures; inspect records.
const fs = require('fs');
const cp = require('child_process');
if (process.argv.length < 3) throw new Error('Expected package names, e.g. rume cmd');
let total = 0, failed = 0, skipped = 0;
for (const pkg of process.argv.slice(2)) {
  for (const kind of ['internal', 'whitebox', 'blackbox']) {
    const base = `_build/js/debug/test/${pkg}`;
    const info = JSON.parse(fs.readFileSync(`${base}/__${kind}_test_info.json`, 'utf8'));
    const entries = Object.entries(info.tests).map(([file, tests]) => [
      file,
      tests.filter(t => !(t.attrs || []).some(a => JSON.stringify(a).includes('skip')))
        .map(t => ({ start: t.index, end: t.index + 1 })),
    ]).filter(e => e[1].length);
    if (!entries.length) continue;
    const result = cp.spawnSync('bun', [
      `${base}/${pkg}.${kind}_test.js`,
      JSON.stringify({ package: `jtenner/starshine/${pkg}`, file_and_index: entries }),
    ], { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
    fs.writeFileSync(`/tmp/r1-01-${pkg}-${kind}-results.log`,
      (result.stdout || '') + (result.stderr || ''));
    const records = (result.stdout || '').split('\n').filter(l => l.startsWith('{'))
      .map(l => JSON.parse(l)).filter(r => r.type === 'result');
    const bad = records.filter(r => r.message && r.message !== 'skipped test');
    total += records.length;
    failed += bad.length;
    skipped += records.filter(r => r.message === 'skipped test').length;
    console.log(`${pkg}/${kind}: ${records.length} results, ${bad.length} failures, process ${result.status}`);
    for (const r of bad) console.log(JSON.stringify(r));
    if (result.status !== 0 || records.length !== entries.reduce((n, e) => n + e[1].length, 0)) {
      console.error('Missing results or runner failure', result.error);
      process.exit(1);
    }
  }
}
console.log(JSON.stringify({ total, failed, skipped }));
process.exit(failed ? 1 : 0);
