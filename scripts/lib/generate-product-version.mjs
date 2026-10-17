import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { repoRootFromScript } from './self-optimized-artifacts.mjs';

const rootDefault = repoRootFromScript(import.meta.url);
const numeric = '(?:0|[1-9][0-9]*)';
const prerelease = '(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)';
const semver = new RegExp(`^${numeric}\\.${numeric}\\.${numeric}(?:-${prerelease}(?:\\.${prerelease})*)?(?:\\+[0-9A-Za-z-]+(?:\\.[0-9A-Za-z-]+)*)?$`);

export function validateProductVersion(version) {
  if (typeof version !== 'string' || version.length > 256 || !semver.test(version) || version.split(/[+-]/, 1)[0].split('.').some(part => !Number.isSafeInteger(Number(part)))) {
    throw new Error(`Invalid npm-compatible product semver: ${version}`);
  }
  return version;
}

export function readMoonProductVersion(moduleText) {
  const assignments = [...moduleText.matchAll(/^\s*version\s*=/gm)];
  const matches = [...moduleText.matchAll(/^\s*version\s*=\s*"([^"\n]+)"\s*$/gm)];
  if (assignments.length !== 1 || matches.length !== 1) throw new Error('Product metadata must contain exactly one canonical quoted MoonBit version');
  return validateProductVersion(matches[0][1]);
}

export function readProductVersion(root = rootDefault) {
  const version = readMoonProductVersion(fs.readFileSync(path.join(root, 'moon.mod'), 'utf8'));
  const npmVersion = JSON.parse(fs.readFileSync(path.join(root, 'node/package.json'), 'utf8')).version;
  if (npmVersion !== version) throw new Error(`Product version mismatch: MoonBit ${version}, npm ${npmVersion}`);
  return version;
}

export function generateProductVersion({ root = rootDefault, check = false } = {}) {
  const version = readProductVersion(root);
  const source = `// Generated from moon.mod; npm metadata must match. DO NOT EDIT.\n\n///|\nconst CMD_VERSION : String = ${JSON.stringify('v' + version)}\n`;
  const ffiTarget = path.join(root, 'ffi/moon.mod');
  const ffiModule = fs.readFileSync(ffiTarget, 'utf8');
  if ([...ffiModule.matchAll(/"jtenner\/starshine@[^"\n]+"/g)].length !== 1) {
    throw new Error('FFI metadata must contain exactly one root product dependency');
  }
  const outputs = [
    [path.join(root, 'src/cmd/version.generated.mbt'), source],
    [ffiTarget, ffiModule.replace(/"jtenner\/starshine@[^"\n]+"/, JSON.stringify('jtenner/starshine@' + version))],
  ];
  for (const [target, text] of outputs) {
    if (check) {
      if (!fs.existsSync(target) || fs.readFileSync(target, 'utf8') !== text) {
        throw new Error(`Product version source is stale: ${path.relative(root, target)}; run bun scripts/lib/generate-product-version.mjs`);
      }
    } else {
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, text);
    }
  }
  return version;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  generateProductVersion({ check: process.argv.includes('--check') });
}
