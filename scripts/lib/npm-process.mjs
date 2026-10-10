import fs from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';

const deadlines = {
  compiler: ['NPM_COMPILER_TIMEOUT_MS', 900_000],
  pack: ['NPM_PACK_TIMEOUT_MS', 1_800_000],
  optimizer: ['NPM_SELF_OPT_TIMEOUT_MS', 180_000],
  consumer: ['NPM_CONSUMER_TIMEOUT_MS', 240_000],
};

export function npmTimeoutMs(stage, env = process.env) {
  const config = deadlines[stage];
  if (!config) throw new Error(`Unknown npm command stage: ${stage}`);
  const [key, fallback] = config;
  const value = env[key] === undefined ? fallback : Number(env[key]);
  if (!Number.isSafeInteger(value) || value <= 0 || value > 2_147_483_647) {
    throw new Error(`${key} must be a positive integer no larger than 2147483647`);
  }
  return value;
}

function terminateTree(pid, inheritedPipes) {
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { timeout: 2000, stdio: 'ignore' });
    return new Set([pid]);
  }
  // Every command starts its own session. npm/prepack commands can start more
  // sessions, so collect descendant groups before terminating the live root.
  try { process.kill(-pid, 'SIGSTOP'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
  const inventory = spawnSync('ps', ['-eo', 'pid=,ppid=,pgid='], { encoding: 'utf8', timeout: 2000, maxBuffer: 8 * 1024 * 1024 });
  if (inventory.error || inventory.status !== 0) {
    try { process.kill(-pid, 'SIGKILL'); } catch { /* already exited */ }
    throw new Error(`Unable to inventory descendants for process ${pid}; root group terminated`);
  }
  const rows = inventory.stdout.trim().split('\n').map(row => row.trim().split(/\s+/).map(Number));
  const descendants = new Set([pid]);
  const groups = new Set([pid]);
  // Linux keeps anonymous output-pipe identities stable after a parent exits.
  // Recover reparented pipe holders as well as still-attached descendants.
  if (process.platform === 'linux' && inheritedPipes.size) {
    for (const [child, , group] of rows) {
      for (const fd of [1, 2]) {
        try {
          if (inheritedPipes.has(fs.readlinkSync(`/proc/${child}/fd/${fd}`))) {
            descendants.add(child);
            groups.add(group);
          }
        } catch { /* unrelated, inaccessible or already exited */ }
      }
    }
  }
  let changed = true;
  while (changed) {
    changed = false;
    for (const [child, parent, group] of rows) {
      if (descendants.has(parent) && !descendants.has(child)) {
        descendants.add(child);
        groups.add(group);
        changed = true;
      }
    }
  }
  for (const group of [...groups].reverse()) {
    try { process.kill(-group, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
  }
  return descendants;
}

function processRunning(pid) {
  try {
    process.kill(pid, 0);
    if (process.platform === 'linux') return !/^State:\s+Z/m.test(fs.readFileSync(`/proc/${pid}/status`, 'utf8'));
    return true;
  } catch (error) {
    if (error.code === 'ESRCH' || error.code === 'ENOENT') return false;
    throw error;
  }
}

async function awaitTermination(pids) {
  const until = performance.now() + 2000;
  while ([...pids].some(processRunning)) {
    if (performance.now() >= until) throw new Error('Process-tree termination did not complete within 2000 ms');
    await new Promise(resolve => setTimeout(resolve, 10));
  }
}

export async function runNpmCommand(command, args, { cwd, env = process.env, stage = 'consumer', logFile, expectFailure = false } = {}) {
  const timeout = npmTimeoutMs(stage, env);
  const started = performance.now();
  const result = await new Promise(resolve => {
    const child = spawn(command, args, { cwd, env, stdio: ['ignore', 'pipe', 'pipe'], detached: process.platform !== 'win32' });
    const stdout = [], stderr = [];
    const inheritedPipes = new Set();
    if (process.platform === 'linux' && child.pid) {
      for (const fd of [1, 2]) {
        try {
          const pipe = fs.readlinkSync(`/proc/${child.pid}/fd/${fd}`);
          if (/^(pipe|socket):\[\d+\]$/.test(pipe)) inheritedPipes.add(pipe);
        } catch { /* root already exited; still terminate its original group */ }
      }
    }
    let bytes = 0, error, settled = false, stopping = false, exitStatus = null, exitSignal = null;
    const finish = (status, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ stdout: Buffer.concat(stdout).toString('utf8'), stderr: Buffer.concat(stderr).toString('utf8'), status, signal, error });
    };
    const stop = async reason => {
      if (settled || stopping) return;
      stopping = true;
      error = new Error(reason);
      try {
        if (child.pid) await awaitTermination(terminateTree(child.pid, inheritedPipes));
      } catch (cleanup) { error = new Error(`${reason}; ${cleanup.message}`); }
      // A leaked inherited pipe must never turn a deadline into an unbounded
      // wait for close. Settle explicitly after bounded cleanup and close reads.
      child.stdout.destroy();
      child.stderr.destroy();
      finish(exitStatus, exitSignal);
    };
    const timer = setTimeout(() => stop('ETIMEDOUT'), timeout);
    for (const [stream, output] of [[child.stdout, stdout], [child.stderr, stderr]]) {
      stream.on('data', chunk => {
        if (settled) return;
        bytes += chunk.length;
        if (bytes <= 64 * 1024 * 1024) output.push(chunk);
        else stop('command output exceeded 64 MiB');
      });
    }
    child.on('error', cause => { error = cause; if (!stopping) finish(null, null); });
    child.on('exit', (status, signal) => { exitStatus = status; exitSignal = signal; });
    child.on('close', (status, signal) => {
      if (!stopping) finish(status, signal);
    });
  });
  const output = result.stdout + result.stderr;
  if (logFile) fs.writeFileSync(logFile, output);
  const expectedExit = Number.isInteger(result.status) && (expectFailure ? result.status !== 0 : result.status === 0);
  if (result.error || !expectedExit) {
    const detail = result.error?.message ?? output.slice(-8000);
    throw new Error(`${stage} command ${command} ${args.join(' ')} failed after ${Math.round(performance.now() - started)} ms (deadline ${timeout} ms, status ${result.status}, signal ${result.signal})${logFile ? `; full log: ${logFile}` : ''}: ${detail}`);
  }
  return result.stdout;
}
