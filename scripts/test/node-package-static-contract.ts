import fs from "node:fs";
import path from "node:path";

function fail(message: string): never {
  throw new Error(message);
}

export function runNodePackageStaticContractTest(): void {
  const repoRoot = path.resolve(import.meta.dir, "..", "..");
  const nodeRoot = path.join(repoRoot, "node");
  const packageJson = JSON.parse(
    fs.readFileSync(path.join(nodeRoot, "package.json"), "utf8"),
  ) as {
    exports?: Record<string, { import?: string; types?: string }>;
    bin?: Record<string, string>;
  };

  const exports = packageJson.exports ?? {};
  if (Object.keys(exports).length === 0) fail("node/package.json has no exports");
  for (const [name, entry] of Object.entries(exports)) {
    for (const field of ["import", "types"] as const) {
      const relative = entry[field];
      if (!relative) fail(`node export ${name} is missing ${field}`);
      const target = path.resolve(nodeRoot, relative);
      if (!target.startsWith(`${nodeRoot}${path.sep}`)) {
        fail(`node export ${name} ${field} escapes node/: ${relative}`);
      }
      if (!fs.existsSync(target)) {
        fail(`node export ${name} ${field} is missing: ${relative}`);
      }
    }
  }

  for (const [name, relative] of Object.entries(packageJson.bin ?? {})) {
    const target = path.resolve(nodeRoot, relative);
    if (!fs.existsSync(target)) fail(`node bin ${name} is missing: ${relative}`);
  }

  const ignoredArtifacts = fs.readFileSync(
    path.join(nodeRoot, "internal", ".gitignore"),
    "utf8",
  );
  for (const artifact of ["starshine.wasm-gc.wasm", "starshine.wasm-wasi.wasm"]) {
    if (!ignoredArtifacts.split(/\r?\n/).includes(artifact)) {
      fail(`node/internal/.gitignore must name local runtime artifact ${artifact}`);
    }
  }

  const buildScript = fs.readFileSync(
    path.join(repoRoot, "scripts", "lib", "build-node-package.mjs"),
    "utf8",
  );
  if (!buildScript.includes("Missing checked-in node/internal/starshine.wasm-gc.wasm")) {
    fail("Node build script must fail explicitly when the local-only wasm-gc adapter is absent");
  }
}

if (import.meta.main) {
  runNodePackageStaticContractTest();
  process.stdout.write("node package static contract: ok\n");
}
