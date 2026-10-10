import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { runNpmCommand } from './npm-process.mjs';

export const npmLicenseFiles = ['LICENSE', 'NOTICE', 'licenses/Apache-2.0.txt', 'licenses/Binaryen-LICENSE.txt', 'licenses/moonbit-core-NOTICE.txt'];

// Byte copies preserve upstream text and avoid a hand-maintained second notice.
export function syncNpmLicenses(root, { check = false } = {}) {
  for (const file of npmLicenseFiles) {
    const source = fs.readFileSync(path.join(root, file));
    const target = path.join(root, 'node', file);
    if (fs.existsSync(target) && fs.readFileSync(target).equals(source)) continue;
    if (check) throw new Error(`npm license drift: ${file}; run npm generation`);
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, source);
  }
}

function assertModule(root, name, version) {
  const mod = fs.readFileSync(path.join(root, 'moon.mod'), 'utf8');
  const actualVersion = mod.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
  const license = mod.match(/^license\s*=\s*"([^"]+)"/m)?.[1];
  if (actualVersion !== version || license !== 'Apache-2.0') {
    throw new Error(`${name} version/license changed; review provenance and packaged notices before building`);
  }
}

// Dependency upgrades must not silently ship yesterday's notices. Check the
// installed build inputs, rather than fetching a mutable upstream main branch.
export function assertNpmDependencyLicenses(root, coreRoot) {
  assertModule(coreRoot, 'MoonBit Core', '0.10.14+7d59c7ec9');
  for (const prefix of ['', 'ffi']) {
    const xRoot = path.join(root, prefix, '.mooncakes/moonbitlang/x');
    assertModule(xRoot, 'moonbitlang/x', '0.5.1');
    if (fs.existsSync(path.join(xRoot, 'NOTICE'))) {
      throw new Error('moonbitlang/x NOTICE appeared; review and package its attribution before building');
    }
  }
  const hashes = {};
  for (const [name, reviewed] of [['LICENSE', 'licenses/Apache-2.0.txt'], ['NOTICE', 'licenses/moonbit-core-NOTICE.txt']]) {
    const actual = fs.readFileSync(path.join(coreRoot, name));
    if (!actual.equals(fs.readFileSync(path.join(root, reviewed)))) {
      throw new Error(`MoonBit Core ${name} changed; review and regenerate packaged dependency notices`);
    }
    hashes[name] = createHash('sha256').update(actual).digest('hex');
  }
  return { core: '0.10.14+7d59c7ec9', x: '0.5.1', hashes };
}

// The dry-run resolves a clean workspace's registry tree without compiling.
// `moon update` does not materialize this FFI tree in the tested toolchain.
// Check those actual resolved inputs before executing any artifact build.
export async function prepareNpmDependencyLicenses(root, coreRoot, { moonBin = 'moon', run = runNpmCommand, logFile } = {}) {
  await run(moonBin, ['-C', 'ffi', 'build', '--target', 'wasm-gc', '--release', 'src/npm', '--dry-run'], { cwd: root, stage: 'compiler', logFile });
  return assertNpmDependencyLicenses(root, coreRoot);
}
