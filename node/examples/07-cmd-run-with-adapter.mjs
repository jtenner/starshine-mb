import * as cmd from '../cmd.js';
import { expectOk } from './_shared.mjs';

const stdout = [];
const io = cmd.CmdIO.new(
  () => null,
  () => false,
  () => ({ ok: false, error: 'unexpected read' }),
  undefined,
  () => ({ ok: false, error: 'unexpected write_file' }),
  (bytes) => {
    stdout.push(new TextDecoder().decode(bytes));
    return { ok: true, value: undefined };
  },
  () => ({ ok: true, value: undefined }),
  () => [],
  () => ({ ok: false, error: 'unexpected lower_text_module' }),
);

expectOk(cmd.runCmdWithAdapter(['--help'], io), 'cmd.runCmdWithAdapter');
console.log(stdout.join('').split('\n').slice(0, 3).join('\n'));
