// Writes the 300 campaign level fingerprints (data/level_fingerprints.json)
// into the competition migration, between "-- BEGIN FINGERPRINTS" and
// "-- END FINGERPRINTS"; --check only verifies (exit 1 when they differ).
//   node tools/competition_migration.mjs [--check]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MIGRATION = path.join(repo, 'supabase/migrations/20261014120000_ce_competition_results.sql');
const manifest = JSON.parse(fs.readFileSync(path.join(repo, 'data/level_fingerprints.json'), 'utf8'));
if (manifest.version !== 1 || manifest.fingerprints.length !== 300) throw new Error('unexpected manifest');
const rows = manifest.fingerprints.map((f, i) => {
  if (!/^[0-9a-f]{64}$/.test(f)) throw new Error(`level ${i + 1}: bad fingerprint`);
  return `  (${i + 1}, '${f}')`;
});
const block = '-- BEGIN FINGERPRINTS\ninsert into public.ce_level_fingerprints (level, fingerprint) values\n' +
  rows.join(',\n') + '\non conflict (level, fingerprint) do nothing;\n-- END FINGERPRINTS';
const sql = fs.readFileSync(MIGRATION, 'utf8');
const next = sql.replace(/-- BEGIN FINGERPRINTS[\s\S]*?-- END FINGERPRINTS/, block);
if (process.argv.includes('--check')) {
  const ok = next === sql;
  console.log(`COMPETITION MIGRATION FINGERPRINTS ${ok ? 'OK' : 'STALE'} (300 levels)`);
  process.exit(ok ? 0 : 1);
}
fs.writeFileSync(MIGRATION, next);
console.log('competition migration: 300 fingerprints written');
