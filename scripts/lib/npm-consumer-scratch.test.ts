import { expect, test } from 'bun:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createExternalNpmConsumerScratch } from './npm-consumer-scratch.mjs';

test('consumer scratch rejects a compiler TMPDIR inside the checkout', () => {
  const parent = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-scratch-test-'));
  try {
    const repo = path.join(parent, 'repo');
    const nested = path.join(repo, '.tmp');
    fs.mkdirSync(nested, { recursive: true });
    expect(() => createExternalNpmConsumerScratch(repo, nested)).toThrow(/outside the source checkout/);
    expect(() => createExternalNpmConsumerScratch(repo, repo)).toThrow(/outside the source checkout/);
  } finally {
    fs.rmSync(parent, { recursive: true, force: true });
  }
});

test('consumer scratch rejects a symlink into the checkout', () => {
  const parent = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-scratch-test-'));
  try {
    const repo = path.join(parent, 'repo');
    fs.mkdirSync(repo);
    const alias = path.join(parent, 'alias');
    fs.symlinkSync(repo, alias, process.platform === 'win32' ? 'junction' : 'dir');
    expect(() => createExternalNpmConsumerScratch(repo, alias)).toThrow(/outside the source checkout/);
  } finally {
    fs.rmSync(parent, { recursive: true, force: true });
  }
});

test('consumer scratch accepts a sibling with a shared path prefix', () => {
  const parent = fs.mkdtempSync(path.join(os.tmpdir(), 'npm-scratch-test-'));
  try {
    const repo = path.join(parent, 'repo');
    const base = path.join(parent, 'repo-consumers');
    fs.mkdirSync(repo);
    fs.mkdirSync(base);
    const scratch = createExternalNpmConsumerScratch(repo, base);
    expect(path.dirname(scratch)).toBe(fs.realpathSync(base));
    expect(fs.readdirSync(scratch)).toEqual([]);
  } finally {
    fs.rmSync(parent, { recursive: true, force: true });
  }
});
