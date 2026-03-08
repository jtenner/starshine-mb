import * as cli from '../cli.js';
import { expectOk } from './_shared.mjs';

const parsed = expectOk(
  cli.parseCliArgs(['--optimize', '--vacuum', '--trap-mode', 'never', 'input.wasm']),
  'cli.parseCliArgs',
);

console.log(cli.CliParseResult.show(parsed));
console.log(`resolved pass flags: ${cli.resolvePassFlags(parsed).join(', ')}`);
console.log(`traps never happen: ${cli.resolveTrapsNeverHappen(parsed, false)}`);
