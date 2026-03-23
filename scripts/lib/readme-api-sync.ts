import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { fail, resolveRepoPath, resolveWorkspaceRoot } from "./task-runtime";

type VerifyBlock = {
  interfacePath: string;
  signatures: string[];
};

export type ReadmeApiSyncOptions = {
  readmePath: string;
  interfacePaths: string[];
};

export function parseReadmeApiSyncArgs(argv: string[]): ReadmeApiSyncOptions {
  const options: ReadmeApiSyncOptions = {
    readmePath: "README.mbt.md",
    interfacePaths: [],
  };

  for (let i = 0; i < argv.length; ) {
    const token = argv[i];
    switch (token) {
      case "--readme":
        options.readmePath = argv[i + 1] ?? fail("missing value for --readme");
        i += 2;
        break;
      case "--interface":
        options.interfacePaths.push(argv[i + 1] ?? fail("missing value for --interface"));
        i += 2;
        break;
      default:
        fail(`unknown option: ${token}`);
    }
  }

  return options;
}

function collectDefaultInterfacePaths(repoRoot: string): string[] {
  const out: string[] = [];

  function walk(current: string): void {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (entry.isFile() && entry.name === "pkg.generated.mbti") {
        out.push(path.relative(repoRoot, full).split(path.sep).join("/"));
      }
    }
  }

  walk(path.join(repoRoot, "src"));
  out.sort();
  return out;
}

// README sync blocks are intentionally explicit and strict:
// each marker points at one interface path and is followed by a non-empty mbti block,
// so drift is surfaced exactly where the marker declares expected signatures.
function parseVerifyBlocks(readmeText: string): VerifyBlock[] {
  const lines = readmeText.split(/\r?\n/);
  const blocks: VerifyBlock[] = [];

  for (let i = 0; i < lines.length; i += 1) {
    const marker = lines[i].trim();
    const match = marker.match(/^<!-- README_API_VERIFY (.+) -->$/);
    if (!match) {
      continue;
    }

    const interfacePath = match[1].trim();
    i += 1;
    while (i < lines.length && lines[i].trim().length === 0) {
      i += 1;
    }
    if (i >= lines.length || lines[i].trim() !== "```mbti") {
      fail(`README_API_VERIFY marker for ${interfacePath} must be followed by a \`\`\`mbti code block`);
    }

    const signatures: string[] = [];
    i += 1;
    while (i < lines.length && lines[i].trim() !== "```") {
      const line = lines[i].trim();
      if (line.length > 0) {
        signatures.push(line);
      }
      i += 1;
    }
    if (i >= lines.length) {
      fail(`README_API_VERIFY marker for ${interfacePath} has an unterminated code block`);
    }
    if (signatures.length === 0) {
      fail(`README_API_VERIFY marker for ${interfacePath} has no signatures`);
    }
    blocks.push({ interfacePath, signatures });
  }

  return blocks;
}

export function verifyReadmeApiSync(options: ReadmeApiSyncOptions): void {
  const repoRoot = resolveWorkspaceRoot();
  const readmePath = resolveRepoPath(repoRoot, options.readmePath);
  if (!fs.existsSync(readmePath)) {
    fail(`README not found: ${readmePath}`);
  }

  const readmeText = fs.readFileSync(readmePath, "utf8");
  const blocks = parseVerifyBlocks(readmeText);
  if (blocks.length === 0) {
    process.stdout.write("README API sync skipped: no README_API_VERIFY blocks.\n");
    return;
  }

  const interfacePaths = options.interfacePaths.length > 0
    ? options.interfacePaths
    : collectDefaultInterfacePaths(repoRoot);
  const interfaceTextByPath = new Map<string, string>();
  for (const relativePath of interfacePaths) {
    const absolutePath = resolveRepoPath(repoRoot, relativePath);
    if (!fs.existsSync(absolutePath)) {
      continue;
    }
    interfaceTextByPath.set(relativePath, fs.readFileSync(absolutePath, "utf8"));
  }

  const diagnostics: string[] = [];
  for (const block of blocks) {
    const interfaceText = interfaceTextByPath.get(block.interfacePath);
    if (interfaceText === undefined) {
      diagnostics.push(`missing interface file for README_API_VERIFY block: ${block.interfacePath}`);
      continue;
    }
    for (const signature of block.signatures) {
      if (!interfaceText.includes(signature)) {
        diagnostics.push(`missing signature in ${block.interfacePath}: ${signature}`);
      }
    }
  }

  if (diagnostics.length > 0) {
    fail(diagnostics.join("\n"));
  }

  process.stdout.write("README API sync check passed.\n");
}
