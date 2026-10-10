import { expect, test } from 'bun:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { npmTimeoutMs, runNpmCommand } from './npm-process.mjs';

test('cold CI compiler work fits the build budget without extending optimizer work', () => {
  // The baseline successful native CI build took 328,583 ms. The old npm
  // deadline killed the same required source compilation after 180,000 ms.
  expect(npmTimeoutMs('compiler', {})).toBeGreaterThan(328_583);
  expect(npmTimeoutMs('optimizer', {})).toBe(180_000);
  expect(npmTimeoutMs('pack', {})).toBeGreaterThan(
    npmTimeoutMs('compiler', {}) + 2 * npmTimeoutMs('optimizer', {}) + npmTimeoutMs('consumer', {}),
  );
});

test('compiler completion and optimizer timeout use independent bounded deadlines', async () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-process-test-'));
  const env = { ...process.env, NPM_COMPILER_TIMEOUT_MS: '2000', NPM_SELF_OPT_TIMEOUT_MS: '80' };
  try {
    const args = ['-e', 'console.log("started"); setTimeout(() => console.log("completed"), 250)'];
    expect(await runNpmCommand(process.execPath, args, { cwd: scratch, env, stage: 'compiler' })).toContain('completed');
    const logFile = path.join(scratch, 'optimizer.log');
    await expect(runNpmCommand(process.execPath, args, { cwd: scratch, env, stage: 'optimizer', logFile })).rejects.toThrow(/optimizer.*ETIMEDOUT/);
    expect(fs.readFileSync(logFile, 'utf8')).toContain('started');
    expect(fs.readFileSync(logFile, 'utf8')).not.toContain('completed');
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});

test('a failed build command preserves its full diagnostics', async () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-process-test-'));
  try {
    const logFile = path.join(scratch, 'compile.log');
    const args = ['-e', 'console.error("first diagnostic"); console.error("x".repeat(10000)); console.error("last diagnostic"); process.exit(7)'];
    await expect(runNpmCommand(process.execPath, args, { cwd: scratch, stage: 'compiler', logFile })).rejects.toThrow(/status 7/);
    const log = fs.readFileSync(logFile, 'utf8');
    expect(log).toContain('first diagnostic');
    expect(log).toContain('last diagnostic');
    expect(log.length).toBeGreaterThan(10000);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});

test('invalid timeout configuration cannot silently disable a required deadline', () => {
  for (const value of ['0', '-1', 'NaN', 'Infinity', '1.5', '2147483648', '']) {
    expect(() => npmTimeoutMs('compiler', { NPM_COMPILER_TIMEOUT_MS: value })).toThrow(/positive integer/);
  }
});

test('a timed-out build terminates compiler descendants that ignore SIGTERM', async () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-process-tree-test-'));
  let grandchild: number | undefined;
  try {
    const logFile = path.join(scratch, 'tree.log');
    const code = `const {spawn}=require('node:child_process'); const child=spawn(process.execPath,['-e','process.on("SIGTERM",()=>{}); setInterval(()=>{},1000)'],{stdio:'ignore',detached:true}); console.log(child.pid); setInterval(()=>{},1000);`;
    try {
      await runNpmCommand(process.execPath, ['-e', code], { cwd: scratch, env: { ...process.env, NPM_COMPILER_TIMEOUT_MS: '300' }, stage: 'compiler', logFile });
      throw new Error('expected timeout');
    } catch (error) {
      expect(String(error)).toContain('ETIMEDOUT');
    }
    grandchild = Number(fs.readFileSync(logFile, 'utf8').trim());
    expect(grandchild).toBeGreaterThan(0);
    let running = false;
    try {
      process.kill(grandchild, 0);
      // Orphan zombies await host init's reap, but can no longer execute.
      running = process.platform === 'linux' ? !/^State:\s+Z/m.test(fs.readFileSync(`/proc/${grandchild}/status`, 'utf8')) : true;
    } catch { /* no live descendant */ }
    expect(running).toBe(false);
  } finally {
    if (grandchild) { try { process.kill(grandchild, 'SIGKILL'); } catch { /* already terminated */ } }
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});

test('a departed build parent cannot leave an inherited-output descendant running or hold the deadline open', async () => {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-process-orphan-test-'));
  let grandchild: number | undefined;
  let pending: Promise<unknown> | undefined;
  try {
    const pidFile = path.join(scratch, 'pid');
    const code = `const fs=require('node:fs'); const {spawn}=require('node:child_process'); const child=spawn(process.execPath,['-e','process.on("SIGTERM",()=>{}); setInterval(()=>{},1000)'],{stdio:'inherit',detached:true}); fs.writeFileSync(process.argv[1],String(child.pid)); process.exit(0);`;
    pending = runNpmCommand(process.execPath, ['-e', code, pidFile], { cwd: scratch, env: { ...process.env, NPM_COMPILER_TIMEOUT_MS: '250' }, stage: 'compiler' }).catch(error => String(error));
    const result = await Promise.race([pending, new Promise(resolve => setTimeout(() => resolve('still pending'), 800))]);
    grandchild = Number(fs.readFileSync(pidFile, 'utf8'));
    expect(result).not.toBe('still pending');
    expect(String(result)).toContain('ETIMEDOUT');
    let running = false;
    try {
      process.kill(grandchild, 0);
      running = process.platform === 'linux' ? !/^State:\s+Z/m.test(fs.readFileSync(`/proc/${grandchild}/status`, 'utf8')) : true;
    } catch { /* no live descendant */ }
    expect(running).toBe(false);
  } finally {
    if (grandchild) { try { process.kill(grandchild, 'SIGKILL'); } catch { /* already terminated */ } }
    await pending;
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
