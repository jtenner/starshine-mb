import { expect, test } from "bun:test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { assertComparisonInputPreserved } from "./self-optimize-compare-task";

test("comparison protects inputs physically aliased to outputs and intermediate artifacts", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "compare-input-"));
  try {
    const out = path.join(dir, "out"); fs.mkdirSync(out);
    const backing = path.join(out, "starshine.raw.wasm"); fs.writeFileSync(backing, "original");
    const alias = path.join(dir, "source.wasm"); fs.symlinkSync(backing, alias);
    expect(() => assertComparisonInputPreserved(alias, out)).toThrow("overlaps");
    for (const name of ["binaryen.nop1.wasm", "result.json", "starshine.stdout.txt", "func-diff.starshine.wat"]) {
      const filename = path.join(out, name); fs.writeFileSync(filename, "input");
      expect(() => assertComparisonInputPreserved(filename, out)).toThrow("overlaps");
    }
    const hardlink = path.join(dir, "hardlink-source.wasm"); fs.linkSync(backing, hardlink);
    expect(() => assertComparisonInputPreserved(hardlink, out)).toThrow("overlaps");
    const different = path.join(dir, "different.wasm"); fs.writeFileSync(different, "different");
    expect(() => assertComparisonInputPreserved(different, out)).not.toThrow();
    expect(() => assertComparisonInputPreserved(different, path.join(dir, "fresh", "out"))).not.toThrow();
    expect(fs.readFileSync(backing, "utf8")).toBe("original");
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
