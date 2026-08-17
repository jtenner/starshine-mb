import fs from "node:fs";
import path from "node:path";

import {
  generateFfiPackage,
  standardTraitInterfaces,
  type FfiInterfaceInput,
} from "./ffi-generation";
import { listWasmExportNames, rewriteWasmExportNames } from "./wasm-export-renaming";
import { fail, resolveMoonBin, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export type FfiCommand = "generate" | "check" | "build";

export function collectFfiInterfaces(repoRoot: string): FfiInterfaceInput[] {
  const sourceRoot = path.join(repoRoot, "src");
  const inputs: FfiInterfaceInput[] = [];
  for (const entry of fs.readdirSync(sourceRoot, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name === "ffi") continue;
    const packageRoot = path.join(sourceRoot, entry.name);
    const manifestPath = path.join(packageRoot, "moon.pkg");
    const interfacePath = path.join(packageRoot, "pkg.generated.mbti");
    if (!fs.existsSync(manifestPath) || !fs.existsSync(interfacePath)) continue;
    const manifest = fs.readFileSync(manifestPath, "utf8");
    if (/pkgtype\(kind:\s*"executable"\)/.test(manifest)) continue;
    inputs.push({
      alias: entry.name,
      packagePath: `jtenner/starshine/${entry.name}`,
      interfaceText: fs.readFileSync(interfacePath, "utf8"),
    });
  }
  return inputs.sort((left, right) => left.packagePath.localeCompare(right.packagePath));
}

function formatGeneratedMoonBit(
  repoRoot: string,
  source: string,
  manifest: string,
): { source: string; manifest: string } {
  const formatRoot = path.join(repoRoot, ".tmp", "ffi-format");
  const packageRoot = path.join(formatRoot, "src", "ffi");
  fs.rmSync(formatRoot, { recursive: true, force: true });
  fs.mkdirSync(packageRoot, { recursive: true });
  fs.writeFileSync(
    path.join(formatRoot, "moon.mod"),
    'name = "local/ffi-format"\nversion = "0.0.0"\nsource = "src"\n',
  );
  const manifestPath = path.join(packageRoot, "moon.pkg");
  fs.writeFileSync(manifestPath, manifest);
  const sourcePath = path.join(packageRoot, "exports.generated.mbt");
  fs.writeFileSync(sourcePath, source);
  runOrThrow(resolveMoonBin(), ["-C", formatRoot, "fmt"], { cwd: repoRoot });
  const formatted = {
    source: fs.readFileSync(sourcePath, "utf8"),
    manifest: fs.readFileSync(manifestPath, "utf8"),
  };
  fs.rmSync(formatRoot, { recursive: true, force: true });
  return formatted;
}

function writeOrCheck(filePath: string, content: string, check: boolean): void {
  if (check) {
    const current = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : null;
    if (current !== content) {
      fail(`generated FFI artifact is stale: ${path.relative(process.cwd(), filePath)}`);
    }
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

export function runFfi(command: FfiCommand, repoRoot = resolveWorkspaceRoot()): void {
  if (command !== "generate" && command !== "check" && command !== "build") {
    fail("usage: bun ffi <generate|check|build>");
  }
  const ffiRoot = path.join(repoRoot, "ffi");
  const outputRoot = path.join(ffiRoot, "src", "ffi");
  if (command === "generate" || command === "build") {
    fs.rmSync(path.join(outputRoot, "exports.generated.mbt"), { force: true });
    fs.rmSync(path.join(outputRoot, "moon.pkg"), { force: true });
  }
  runOrThrow(resolveMoonBin(), ["info"], { cwd: repoRoot });
  const generated = generateFfiPackage([
    ...collectFfiInterfaces(repoRoot),
    ...standardTraitInterfaces(),
  ]);
  const formatted = formatGeneratedMoonBit(
    repoRoot,
    generated.source,
    generated.packageManifest,
  );
  writeOrCheck(path.join(outputRoot, "exports.generated.mbt"), formatted.source, command === "check");
  writeOrCheck(path.join(outputRoot, "moon.pkg"), formatted.manifest, command === "check");
  writeOrCheck(
    path.join(outputRoot, "export-names.generated.json"),
    `${JSON.stringify(generated.exportNames, null, 2)}\n`,
    command === "check",
  );
  writeOrCheck(
    path.join(outputRoot, "unsupported.generated.json"),
    `${JSON.stringify(generated.unsupported, null, 2)}\n`,
    command === "check",
  );
  if (command === "build") {
    runOrThrow(resolveMoonBin(), ["-C", ffiRoot, "build", "--target", "wasm-gc", "--release", "src/ffi"], {
      cwd: repoRoot,
    });
    const linkedPath = path.join(
      ffiRoot,
      "_build",
      "wasm-gc",
      "release",
      "build",
      "jtenner",
      "starshine-ffi",
      "ffi",
      "ffi.wasm",
    );
    const linked = new Uint8Array(fs.readFileSync(linkedPath));
    const linkedExports = new Set(listWasmExportNames(linked));
    const missing = Object.keys(generated.exportNames).filter((name) => !linkedExports.has(name));
    if (missing.length > 0) {
      fail(`WasmGC linker dropped ${missing.length} generated FFI exports; first missing: ${missing[0]}`);
    }
    const renamed = rewriteWasmExportNames(linked, new Map(Object.entries(generated.exportNames)));
    const distPath = path.join(repoRoot, "dist", "ffi", "starshine-ffi.wasm");
    fs.mkdirSync(path.dirname(distPath), { recursive: true });
    fs.writeFileSync(distPath, renamed);
    process.stdout.write(`WasmGC FFI module: ${path.relative(repoRoot, distPath)}\n`);
  }
  process.stdout.write(
    `FFI ${command}: ${generated.exportedCount} concrete functions exported, ${generated.unsupported.length} symbols require explicit concrete wrappers.\n`,
  );
}
