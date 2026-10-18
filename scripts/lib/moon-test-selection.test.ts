import { afterEach, describe, expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import { discoverMoonTestFiles } from "./moon-test-selection";

const roots: string[] = [];

afterEach(() => {
  for (const root of roots.splice(0)) fs.rmSync(root, { recursive: true, force: true });
});

describe("Moon default test file selection", () => {
  test("includes ordinary sources, all test kinds and Markdown docs in stable path order", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-test-selection-"));
    roots.push(root);
    const files = [
      "src/zeta/panic_wbtest.mbt",
      "src/zeta/bench_test.mbt",
      "src/alpha/nested/guide.mbt.md",
      "src/alpha/inline.mbt",
      "src/alpha/async_test.mbt",
      "src/alpha/skipped_wbtest.mbt",
      "src/alpha/moon.pkg",
      "src/alpha/api.mbti",
      "src/alpha/script.mbtx",
      "src/alpha/notes.md",
      "outside_test.mbt",
    ];
    for (const file of files) {
      const target = path.join(root, file);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, "");
    }
    const expected = files.filter(file => file.startsWith("src/") && (file.endsWith(".mbt") || file.endsWith(".mbt.md"))).sort();

    expect(discoverMoonTestFiles(root)).toEqual(expected);
    expect(discoverMoonTestFiles(root)).toEqual(expected);
    // New packages enter the next run without a maintained package allowlist.
    fs.mkdirSync(path.join(root, "src/new-package"));
    fs.writeFileSync(path.join(root, "src/new-package/inline.mbt"), "");
    expect(discoverMoonTestFiles(root)).toEqual([...expected, "src/new-package/inline.mbt"].sort());
  });

  test("rejects an intentionally invalid empty source tree instead of selecting the whole workspace", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-test-selection-"));
    roots.push(root);
    fs.mkdirSync(path.join(root, "src"));
    expect(() => discoverMoonTestFiles(root)).toThrow("no MoonBit source files");
  });
});
