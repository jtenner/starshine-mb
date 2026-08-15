import fs from "node:fs";
import path from "node:path";
import process from "node:process";

import { generateCoreIrBindings } from "./core-ir-generation";
import { fail, resolveWorkspaceRoot, runOrThrow } from "./task-runtime";

export const WIT_BINDGEN_VERSION = "0.60.0";
const STARSHINE_COMPONENT_VERSION = "0.1.1";

export function validateComponentVersionSources(
  moonModule: string,
  witSource: string,
  metadataImplementation: string,
): string {
  const moonVersion = moonModule.match(/^version\s*=\s*"([^"]+)"/m)?.[1];
  const witVersion = witSource.match(/package\s+jtenner:starshine-component@([^;]+);/)?.[1];
  const metadataVersion = metadataImplementation.match(
    /pub fn version\(\)\s*->\s*String\s*\{\s*"([^"]+)"/,
  )?.[1];
  if (!moonVersion || !witVersion || !metadataVersion) {
    fail("unable to read component version from moon.mod, WIT, or metadata implementation");
  }
  if (
    moonVersion !== witVersion ||
    moonVersion !== metadataVersion ||
    moonVersion !== STARSHINE_COMPONENT_VERSION
  ) {
    fail(
      `component version mismatch: moon=${moonVersion} wit=${witVersion} metadata=${metadataVersion} expected=${STARSHINE_COMPONENT_VERSION}`,
    );
  }
  return moonVersion;
}

export type ComponentCommand = "generate" | "build" | "check";

export interface ComponentArgs {
  command: ComponentCommand;
  moonBin: string;
  wasmToolsBin: string;
  witBindgenBin: string | null;
  outDir: string;
  release: boolean;
}

export interface ComponentCommandStep {
  command: string;
  args: string[];
  cwd: string;
  capturePath?: string;
  internalizeRuntimeImportsPath?: string;
}

const MOONBIT_RUNTIME_IMPORT_BODIES: Record<string, { module: string; body: string }> = {
  finish_create_byte_array: { module: "__moonbit_fs_unstable", body: "local.get 0" },
  now: { module: "__moonbit_time_unstable", body: "i64.const 0" },
  write_bytes_to_file_new: { module: "__moonbit_fs_unstable", body: "i32.const -1" },
  get_error_message: { module: "__moonbit_fs_unstable", body: "ref.null extern" },
  string_append_char: { module: "__moonbit_fs_unstable", body: "" },
  begin_create_string: { module: "__moonbit_fs_unstable", body: "ref.null extern" },
  begin_read_string: { module: "__moonbit_fs_unstable", body: "local.get 0" },
  finish_create_string: { module: "__moonbit_fs_unstable", body: "local.get 0" },
  begin_create_byte_array: { module: "__moonbit_fs_unstable", body: "ref.null extern" },
  byte_array_append_byte: { module: "__moonbit_fs_unstable", body: "" },
  string_read_char: { module: "__moonbit_fs_unstable", body: "i32.const -1" },
  finish_read_string: { module: "__moonbit_fs_unstable", body: "" },
};

export function internalizeMoonBitRuntimeImports(
  wat: string,
  expectedImports = Object.keys(MOONBIT_RUNTIME_IMPORT_BODIES),
): string {
  let output = wat;
  const definitions: string[] = [];
  for (const name of expectedImports) {
    const spec = MOONBIT_RUNTIME_IMPORT_BODIES[name] ?? fail(`unknown MoonBit runtime import: ${name}`);
    const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const escapedModule = spec.module.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const pattern = new RegExp(
      `^  \\(import "${escapedModule}" "${escapedName}" \\(func (\\$\\S+) \\(;(\\d+);\\) \\(type (\\$\\S+)\\)\\)\\)$`,
      "m",
    );
    const match = output.match(pattern);
    if (!match) {
      fail(`expected exactly one generated MoonBit runtime import: ${spec.module}::${name}`);
    }
    const [, functionName, functionIndex, typeName] = match;
    const body = spec.body.length > 0 ? ` ${spec.body}` : "";
    definitions.push(
      `  (func ${functionName} (;${functionIndex};) (type ${typeName})${body})`,
    );
    output = output.replace(pattern, "");
  }

  const remaining = output.match(/^  \(import "__moonbit_[^"]+_unstable" "[^"]+".*$/gm) ?? [];
  if (remaining.length > 0) {
    fail(`unhandled MoonBit runtime imports:\n${remaining.join("\n")}`);
  }

  const retainedImports = [...output.matchAll(/^  \(import .*$/gm)];
  let insertionOffset: number;
  if (retainedImports.length > 0) {
    const lastImport = retainedImports[retainedImports.length - 1];
    insertionOffset = (lastImport.index ?? 0) + lastImport[0].length;
  } else {
    const firstFunction = output.search(/^  \(func /m);
    insertionOffset = firstFunction >= 0 ? firstFunction : output.lastIndexOf("\n)");
    if (insertionOffset < 0) {
      fail("unable to locate function insertion point in generated MoonBit WAT");
    }
  }
  return `${output.slice(0, insertionOffset)}\n${definitions.join("\n")}${output.slice(insertionOffset)}`;
}

interface ComponentPlanOptions {
  repoRoot: string;
  moonBin: string;
  wasmToolsBin: string;
  witBindgenBin: string;
  outDir: string;
  release: boolean;
}

interface GeneratedMoonModule {
  name: string;
  preferredTarget: string;
}

export function parseComponentArgs(argv: string[]): ComponentArgs {
  const command = argv[0] as ComponentCommand | undefined;
  if (command !== "generate" && command !== "build" && command !== "check") {
    fail("usage: bun component <generate|build|check> [--moon <path>] [--wasm-tools <path>] [--wit-bindgen <path>] [--out-dir <path>] [--debug]");
  }

  let moonBin = process.env.MOON_BIN || "moon";
  let wasmToolsBin = process.env.WASM_TOOLS_BIN || "wasm-tools";
  let witBindgenBin = process.env.WIT_BINDGEN_BIN || null;
  let outDir = "dist/component";
  let release = true;

  for (let index = 1; index < argv.length; ) {
    const token = argv[index];
    switch (token) {
      case "--moon":
        moonBin = argv[index + 1] ?? fail("missing value for --moon");
        index += 2;
        break;
      case "--wasm-tools":
        wasmToolsBin = argv[index + 1] ?? fail("missing value for --wasm-tools");
        index += 2;
        break;
      case "--wit-bindgen":
        witBindgenBin = argv[index + 1] ?? fail("missing value for --wit-bindgen");
        index += 2;
        break;
      case "--out-dir":
        outDir = argv[index + 1] ?? fail("missing value for --out-dir");
        index += 2;
        break;
      case "--debug":
        release = false;
        index += 1;
        break;
      default:
        fail(`unknown component option: ${token}`);
    }
  }

  return { command, moonBin, wasmToolsBin, witBindgenBin, outDir, release };
}

export function patchGeneratedMoonModule(module: GeneratedMoonModule): {
  name: string;
  preferredTarget: string;
  deps: Record<string, string>;
} {
  return {
    ...module,
    deps: {
      "jtenner/starshine": "0.1.1",
    },
  };
}

export function buildComponentCommandPlan(options: ComponentPlanOptions): ComponentCommandStep[] {
  const componentRoot = path.join(options.repoRoot, "component");
  const stagingRoot = path.join(options.repoRoot, ".tmp", "component-generation");
  const profile = options.release ? "release" : "debug";
  const buildArgs = ["-C", componentRoot, "build", "--target", "wasm"];
  if (options.release) {
    buildArgs.push("--release");
  }
  const coreWasm = path.join(
    componentRoot,
    "_build",
    "wasm",
    profile,
    "build",
    "jtenner",
    "starshine-component",
    "gen",
    "gen.wasm",
  );
  const runtimeInternalizedWat = path.join(options.outDir, "starshine.runtime-internalized.wat");
  const runtimeInternalizedWasm = path.join(options.outDir, "starshine.runtime-internalized.wasm");
  const embeddedWasm = path.join(options.outDir, "starshine.embedded.wasm");
  const componentWasm = path.join(options.outDir, "starshine.component.wasm");

  return [
    {
      command: options.witBindgenBin,
      args: [
        "moonbit",
        "--out-dir",
        stagingRoot,
        path.join(componentRoot, "wit"),
        "--derive-debug",
        "--derive-eq",
      ],
      cwd: options.repoRoot,
    },
    {
      command: options.moonBin,
      args: ["-C", componentRoot, "update"],
      cwd: options.repoRoot,
    },
    {
      command: options.moonBin,
      args: [
        "-C",
        componentRoot,
        "test",
        "--target",
        "wasm",
        "--package",
        "jtenner/starshine-component/gen/interface/jtenner/starshine-component/modules",
      ],
      cwd: options.repoRoot,
    },
    {
      command: options.moonBin,
      args: [
        "-C",
        componentRoot,
        "check",
        "--target",
        "wasm",
        "--package-path",
        "gen/interface/jtenner/starshine-component/core-ir",
      ],
      cwd: options.repoRoot,
    },
    {
      command: options.moonBin,
      args: buildArgs,
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: [
        "print",
        "--name-unnamed",
        coreWasm,
        "-o",
        runtimeInternalizedWat,
      ],
      cwd: options.repoRoot,
      internalizeRuntimeImportsPath: runtimeInternalizedWat,
    },
    {
      command: options.wasmToolsBin,
      args: ["parse", runtimeInternalizedWat, "-o", runtimeInternalizedWasm],
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: ["validate", "--features", "all", runtimeInternalizedWasm],
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: [
        "component",
        "embed",
        "--world",
        "starshine",
        "--encoding",
        "utf16",
        path.join(componentRoot, "wit"),
        runtimeInternalizedWasm,
        "-o",
        embeddedWasm,
      ],
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: [
        "component",
        "new",
        embeddedWasm,
        "-o",
        componentWasm,
      ],
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: ["validate", "--features", "all", componentWasm],
      cwd: options.repoRoot,
    },
    {
      command: options.wasmToolsBin,
      args: ["component", "wit", componentWasm],
      cwd: options.repoRoot,
      capturePath: path.join(options.outDir, "starshine.wit"),
    },
  ];
}

export function normalizeGeneratedText(value: string): string {
  const lines = value.replaceAll("\r\n", "\n").split("\n").map((line) => line.trimEnd());
  while (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  return `${lines.join("\n")}\n`;
}

function normalizeGeneratedTextTree(root: string): void {
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const entryPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      normalizeGeneratedTextTree(entryPath);
    } else if (/\.(?:json|mbt|md)$/.test(entry.name)) {
      fs.writeFileSync(entryPath, normalizeGeneratedText(fs.readFileSync(entryPath, "utf8")));
    }
  }
}

function copyDirectory(source: string, destination: string): void {
  fs.rmSync(destination, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.cpSync(source, destination, { recursive: true });
}

function syncCoreIrSources(repoRoot: string): void {
  const generated = generateCoreIrBindings(
    fs.readFileSync(path.join(repoRoot, "src", "lib", "pkg.generated.mbti"), "utf8"),
  );
  fs.writeFileSync(
    path.join(repoRoot, "component", "wit", "core-ir.generated.wit"),
    normalizeGeneratedText(generated.wit),
  );
  fs.writeFileSync(
    path.join(repoRoot, "component", "implementation", "core_ir.generated.mbt"),
    normalizeGeneratedText(generated.implementation),
  );
}

function syncGeneratedBindings(repoRoot: string): void {
  const componentRoot = path.join(repoRoot, "component");
  const stagingRoot = path.join(repoRoot, ".tmp", "component-generation");
  const rawModule = JSON.parse(fs.readFileSync(path.join(stagingRoot, "moon.mod.json"), "utf8")) as {
    name: string;
    "preferred-target"?: string;
  };
  const patched = patchGeneratedMoonModule({
    name: rawModule.name,
    preferredTarget: rawModule["preferred-target"] ?? "wasm",
  });

  copyDirectory(path.join(stagingRoot, "gen"), path.join(componentRoot, "gen"));
  copyDirectory(path.join(stagingRoot, "world"), path.join(componentRoot, "world"));
  fs.writeFileSync(path.join(componentRoot, "moon.mod.json"), `${JSON.stringify({
    name: patched.name,
    "preferred-target": patched.preferredTarget,
    deps: patched.deps,
  }, null, 2)}\n`);

  const implementationRoot = path.join(componentRoot, "implementation");
  const interfaceRoot = path.join(componentRoot, "gen", "interface", "jtenner", "starshine-component");
  for (const [interfaceName, implementationFile] of [
    ["metadata", "metadata.mbt"],
    ["modules", "modules.mbt"],
    ["core-ir", "core_ir.generated.mbt"],
  ]) {
    fs.copyFileSync(
      path.join(implementationRoot, implementationFile),
      path.join(interfaceRoot, interfaceName, "implementation.mbt"),
    );
  }
  fs.copyFileSync(
    path.join(implementationRoot, "modules_test.mbt"),
    path.join(interfaceRoot, "modules", "implementation_test.mbt"),
  );
  fs.copyFileSync(
    path.join(implementationRoot, "core_ir_test.mbt"),
    path.join(interfaceRoot, "core-ir", "implementation_test.mbt"),
  );

  const modulesPackagePath = path.join(interfaceRoot, "modules", "moon.pkg.json");
  const modulesPackage = JSON.parse(fs.readFileSync(modulesPackagePath, "utf8")) as Record<string, unknown>;
  modulesPackage.import = [
    { path: "jtenner/starshine/binary", alias: "binary" },
    { path: "jtenner/starshine/lib", alias: "lib" },
    { path: "jtenner/starshine/passes", alias: "passes" },
    { path: "jtenner/starshine/validate", alias: "validate" },
    { path: "jtenner/starshine/wast", alias: "wast" },
  ];
  fs.writeFileSync(modulesPackagePath, `${JSON.stringify(modulesPackage, null, 2)}\n`);

  const coreIrPackagePath = path.join(interfaceRoot, "core-ir", "moon.pkg.json");
  const coreIrPackage = JSON.parse(fs.readFileSync(coreIrPackagePath, "utf8")) as Record<string, unknown>;
  coreIrPackage["warn-list"] = "-1-44";
  coreIrPackage.import = [
    { path: "jtenner/starshine/binary", alias: "binary" },
    { path: "jtenner/starshine/lib", alias: "lib" },
    { path: "jtenner/starshine/validate", alias: "validate" },
    { path: "jtenner/starshine/wast", alias: "wast" },
  ];
  fs.writeFileSync(coreIrPackagePath, `${JSON.stringify(coreIrPackage, null, 2)}\n`);
  normalizeGeneratedTextTree(path.join(componentRoot, "gen"));
  normalizeGeneratedTextTree(path.join(componentRoot, "world"));
}

function ensureWitBindgen(repoRoot: string, explicitPath: string | null): string {
  if (explicitPath) {
    return explicitPath;
  }
  const installed = path.join(repoRoot, ".tmp", "component-tools", "bin", "wit-bindgen");
  if (fs.existsSync(installed)) {
    return installed;
  }
  const installRoot = path.join(repoRoot, ".tmp", "component-tools");
  fs.mkdirSync(installRoot, { recursive: true });
  runOrThrow("cargo", [
    "install",
    "--locked",
    "--root",
    installRoot,
    "--version",
    WIT_BINDGEN_VERSION,
    "wit-bindgen-cli",
  ], { cwd: repoRoot });
  return installed;
}

function runGenerationStep(step: ComponentCommandStep): void {
  runOrThrow(step.command, step.args, { cwd: step.cwd });
}

export function runComponent(argv: string[]): void {
  const parsed = parseComponentArgs(argv);
  const repoRoot = resolveWorkspaceRoot();
  const outDir = path.isAbsolute(parsed.outDir) ? parsed.outDir : path.join(repoRoot, parsed.outDir);
  syncCoreIrSources(repoRoot);
  validateComponentVersionSources(
    fs.readFileSync(path.join(repoRoot, "moon.mod"), "utf8"),
    fs.readFileSync(path.join(repoRoot, "component", "wit", "starshine.wit"), "utf8"),
    fs.readFileSync(path.join(repoRoot, "component", "implementation", "metadata.mbt"), "utf8"),
  );
  const witBindgenBin = ensureWitBindgen(repoRoot, parsed.witBindgenBin);
  const plan = buildComponentCommandPlan({
    repoRoot,
    moonBin: parsed.moonBin,
    wasmToolsBin: parsed.wasmToolsBin,
    witBindgenBin,
    outDir,
    release: parsed.release,
  });

  fs.rmSync(path.join(repoRoot, ".tmp", "component-generation"), { recursive: true, force: true });
  fs.mkdirSync(outDir, { recursive: true });
  runGenerationStep(plan[0]);
  syncGeneratedBindings(repoRoot);

  if (parsed.command === "generate") {
    process.stdout.write("Generated MoonBit component bindings in component/gen.\n");
    return;
  }

  for (const step of plan.slice(1)) {
    const result = runOrThrow(step.command, step.args, {
      cwd: step.cwd,
      stdio: step.capturePath ? "pipe" : "inherit",
    });
    if (step.capturePath) {
      fs.writeFileSync(step.capturePath, result.stdout);
    }
    if (step.internalizeRuntimeImportsPath) {
      const wat = fs.readFileSync(step.internalizeRuntimeImportsPath, "utf8");
      fs.writeFileSync(
        step.internalizeRuntimeImportsPath,
        internalizeMoonBitRuntimeImports(wat),
      );
    }
  }

  if (parsed.command === "check") {
    process.stdout.write("Starshine component bindings and artifact validated.\n");
  } else {
    process.stdout.write(`Wrote ${path.join(outDir, "starshine.component.wasm")}\n`);
  }
}
