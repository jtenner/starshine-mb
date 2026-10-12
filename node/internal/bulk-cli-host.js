import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export class BulkCliExit extends Error {
  constructor(code) { super(`Starshine exit ${code}`); this.code = code; }
}

// Synchronous, instance-local protocol. Each response is [status, ...payload].
// Status 0 is success, 1 is a UTF-8 error, 2 is a missing environment variable.
// No callback re-enters Wasm or retains a view into guest memory.
export function createBulkCliHost({ memory, cwd = process.cwd(), args = [], env = process.env, stdoutFd = 1, stderrFd = 2 } = {}) {
  let pending = null;
  const calls = { request: 0, response: 0, exit: 0 };
  const encoder = new TextEncoder();
  const decoder = new TextDecoder('utf-8', { fatal: true });
  const text = bytes => decoder.decode(bytes);
  const resolve = bytes => path.resolve(cwd, text(bytes));
  function view(ptr, len) {
    const buffer = memory().buffer;
    if (!Number.isInteger(ptr) || !Number.isInteger(len) || ptr < 0 || len < 0 || ptr > buffer.byteLength || len > buffer.byteLength - ptr) throw new RangeError('bulk CLI memory bounds');
    return new Uint8Array(buffer, ptr, len);
  }
  function candidates(root = cwd) {
    const result = [];
    for (const item of fs.readdirSync(root, { withFileTypes: true })) {
      const full = path.join(root, item.name);
      if (item.isDirectory()) result.push(...candidates(full));
      else if (item.isFile()) result.push(path.relative(cwd, full));
    }
    return result.sort();
  }
  function request(op, ptr, len) {
    calls.request++;
    if (pending !== null) throw new Error('bulk CLI response is still pending');
    const bytes = view(ptr, len);
    let status = 0, payload = new Uint8Array();
    try {
      switch (op) {
        case 1: payload = encoder.encode(JSON.stringify(args)); break;
        case 2: { const value = env[text(bytes)]; if (value === undefined) status = 2; else payload = encoder.encode(value); break; }
        case 3: { let exists = false; try { exists = fs.statSync(resolve(bytes)).isFile(); } catch (error) { if (!['ENOENT', 'ENOTDIR'].includes(error.code)) throw error; } payload = new Uint8Array([exists ? 1 : 0]); break; }
        case 4: payload = fs.readFileSync(resolve(bytes)); break;
        case 5: {
          if (bytes.length < 4) throw new Error('bulk CLI write packet is truncated');
          const size = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength).getUint32(0, true);
          if (size > bytes.length - 4) throw new Error('bulk CLI write path is truncated');
          fs.writeFileSync(resolve(bytes.subarray(4, 4 + size)), bytes.subarray(4 + size)); break;
        }
        case 6: payload = encoder.encode(JSON.stringify(candidates())); break;
        case 7: fs.writeFileSync(stdoutFd, bytes); break;
        case 8: fs.writeFileSync(stderrFd, bytes); break;
        default: throw new Error(`Unknown bulk CLI operation ${op}`);
      }
    } catch (error) { status = 1; payload = encoder.encode(String(error)); }
    if (payload.length >= 0x7fffffff) throw new RangeError('bulk CLI response is too large');
    pending = new Uint8Array(payload.length + 1);
    pending[0] = status;
    pending.set(payload, 1);
    return pending.length;
  }
  function response(ptr, capacity) {
    calls.response++;
    if (pending === null) throw new Error('bulk CLI has no pending response');
    if (capacity < pending.length) throw new RangeError('bulk CLI response capacity is too small');
    view(ptr, pending.length).set(pending);
    const length = pending.length;
    pending = null;
    return length;
  }
  return { calls, imports: { __starshine_cli_v1: { request, response, exit(code) { calls.exit++; throw new BulkCliExit(code); } }, __moonbit_time_unstable: { now: () => BigInt(Date.now()) } } };
}
