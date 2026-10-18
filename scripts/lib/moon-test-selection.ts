import fs from "node:fs";
import path from "node:path";

// Moon's package-wide selection repeats empty filename entries for each test
// class. Explicit file paths avoid that argument growth while Moon still owns
// test kinds, skip attributes, panic expectations, and result interpretation.
export function discoverMoonTestFiles(repoRoot: string): string[] {
  const files: string[] = [];
  function visit(relative: string): void {
    for (const entry of fs.readdirSync(path.join(repoRoot, relative), { withFileTypes: true })) {
      const file = `${relative}/${entry.name}`;
      if (entry.isDirectory()) {
        visit(file);
      } else if (entry.isFile() && (entry.name.endsWith(".mbt") || entry.name.endsWith(".mbt.md"))) {
        files.push(file);
      }
    }
  }
  visit("src");
  if (files.length === 0) throw new Error("no MoonBit source files under src/");
  return files.sort();
}
