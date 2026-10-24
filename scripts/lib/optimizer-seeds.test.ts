import { describe, expect, test } from "bun:test";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  checkExternalReplayEvidence,
  externalReplayObservationHash,
  loadOptimizerSeedCorpus,
  parseOptimizerSeedRunArgs,
  type OptimizerExternalReplay,
} from "./optimizer-seeds";
import { type RuntimeObservationV2 } from "./optimizer-runtime";

function externalReplayEvidenceFixture(): {
  replay: OptimizerExternalReplay;
  report: Parameters<typeof checkExternalReplayEvidence>[1];
} {
  const state = { globals: [], memories: [], tables: [] };
  const original: RuntimeObservationV2 = {
    schema: "starshine.optimizer-runtime-observation.v2",
    runtime: { identity: "node-test", timeoutMs: 1000 },
    mode: "independent",
    compilation: { status: "succeeded" },
    instantiation: { status: "succeeded" },
    completeness: "complete",
    blockedReasons: [],
    steps: [{
      stepIndex: 0,
      exportName: "main",
      phase: "exported-call",
      arguments: [],
      importTraceStart: 0,
      importTraceEnd: 0,
      stateBefore: state,
      outcome: { kind: "returned", values: [] },
      stateAfter: state,
      stateDelta: [{ path: "memories[0]", before: "before", after: "after" }],
      firstChangedResource: { kind: "memory", index: 0, offset: 0 },
    }],
    resources: state,
  };
  return {
    replay: {
      sha256: "0".repeat(64),
      provenance: {
        url: "https://zenodo.org/records/1",
        artifact: "artifact.zip:input.wasm",
        artifactHash: "md5:00000000000000000000000000000000",
        license: "CC-BY-4.0",
        licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
        attribution: "Example Authors",
      },
      observation: {
        entrypoint: "main",
        expectedObservationHash: externalReplayObservationHash(original),
        requiredFeatures: [],
        requiredExports: ["main", "memory"],
        timeoutMs: 1000,
        memoryCapBytes: 8388608,
        tableEntryCap: 1024,
        minimumStateChanges: 1,
        requireTransform: true,
      },
    },
    report: {
      runtimeInterface: {
        schema: "starshine.optimizer-runtime-interface.v1",
        moduleHash: "sha256:module",
        interfaceHash: "sha256:interface",
        features: [],
        hasStart: false,
        imports: { functions: [], globals: [], memories: [], tables: [] },
        exports: [
          { name: "main", kind: "function", index: 0, signature: { params: [], results: [] }, support: "directly-constructible" },
          { name: "memory", kind: "memory", index: 0, support: "directly-constructible" },
        ],
      },
      plan: {
        schema: "starshine.optimizer-invocation-plan.v2",
        seed: "0x28",
        interfaceHash: "sha256:interface",
        hash: "sha256:plan",
        steps: [{ stepIndex: 0, exportName: "main", signature: { params: [], results: [] }, arguments: [], source: "default" }],
        blockedExports: [],
      },
      original,
    },
  };
}

describe("optimizer seed corpus", () => {
  test("loads unique small checked-in seed entries", () => {
    const root = path.resolve(import.meta.dir, "..", "..", "tests", "optimizer", "seeds");
    const corpus = loadOptimizerSeedCorpus(root);
    expect(corpus.schema).toBe("starshine.optimizer-seed-corpus.v1");
    expect(corpus.seeds.length).toBeGreaterThanOrEqual(9);
    expect(new Set(corpus.seeds.map((seed) => seed.id)).size).toBe(corpus.seeds.length);
    expect(corpus.seeds.every((seed) => seed.surfaces.length > 0)).toBe(true);
    const surfaces = new Set(corpus.seeds.flatMap((seed) => seed.surfaces));
    for (const required of [
      "import-event",
      "start-function",
      "trap-frontier",
      "memory-beyond-64k",
      "imported-global",
      "imported-memory",
      "imported-table",
    ]) {
      expect(surfaces.has(required)).toBe(true);
    }
  });

  test("loads a licensed external replay with an exact artifact and observation contract", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-external-replay-"));
    const bytes = Buffer.from([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]);
    fs.writeFileSync(path.join(root, "input.wasm"), bytes);
    const sha256 = crypto.createHash("sha256").update(bytes).digest("hex");
    fs.writeFileSync(path.join(root, "manifest.json"), JSON.stringify({
      schema: "starshine.optimizer-seed-corpus.v2",
      seeds: [{
        id: "licensed-replay",
        file: "input.wasm",
        surfaces: ["external-replay"],
        replay: {
          sha256,
          provenance: {
            url: "https://zenodo.org/records/1",
            artifact: "artifact.zip:benchmarks/input.wasm",
            artifactHash: "md5:00000000000000000000000000000000",
            license: "CC-BY-4.0",
            licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
            attribution: "Example Authors",
          },
          observation: {
            entrypoint: "main",
            expectedObservationHash: `sha256:${"1".repeat(64)}`,
            requiredFeatures: [],
            requiredExports: ["main", "memory"],
            timeoutMs: 1000,
            memoryCapBytes: 8388608,
            tableEntryCap: 1024,
            minimumStateChanges: 1,
            requireTransform: true,
          },
        },
      }],
    }));

    const corpus = loadOptimizerSeedCorpus(root);
    expect(corpus.schema).toBe("starshine.optimizer-seed-corpus.v2");
    expect(corpus.seeds[0].replay).toMatchObject({
      sha256,
      provenance: { license: "CC-BY-4.0", attribution: "Example Authors" },
      observation: { entrypoint: "main", minimumStateChanges: 1, requireTransform: true },
    });
  });

  test("rejects an external replay whose loaded bytes do not match provenance", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-external-replay-"));
    fs.writeFileSync(path.join(root, "input.wasm"), Buffer.from([0x00, 0x61, 0x73, 0x6d]));
    fs.writeFileSync(path.join(root, "manifest.json"), JSON.stringify({
      schema: "starshine.optimizer-seed-corpus.v2",
      seeds: [{
        id: "wrong-hash",
        file: "input.wasm",
        surfaces: ["external-replay"],
        replay: {
          sha256: "0".repeat(64),
          provenance: {
            url: "https://zenodo.org/records/1",
            artifact: "artifact.zip:benchmarks/input.wasm",
            artifactHash: "md5:00000000000000000000000000000000",
            license: "CC-BY-4.0",
            licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
            attribution: "Example Authors",
          },
          observation: {
            entrypoint: "main",
            expectedObservationHash: `sha256:${"1".repeat(64)}`,
            requiredFeatures: [],
            requiredExports: ["main"],
            timeoutMs: 1000,
            memoryCapBytes: 8388608,
            tableEntryCap: 1024,
            minimumStateChanges: 1,
            requireTransform: true,
          },
        },
      }],
    }));

    expect(() => loadOptimizerSeedCorpus(root)).toThrow("artifact hash mismatch");
  });

  test("rejects changed results, missing features, silent work, and unchanged optimizer output", () => {
    const fixture = externalReplayEvidenceFixture();
    expect(checkExternalReplayEvidence(fixture.replay, fixture.report, true)).toMatchObject({ status: "passed" });

    const changedResult = structuredClone(fixture.replay);
    changedResult.observation.expectedObservationHash = `sha256:${"f".repeat(64)}`;
    expect(checkExternalReplayEvidence(changedResult, fixture.report, true)).toMatchObject({
      status: "failed",
      detail: expect.stringContaining("observation mismatch"),
    });

    const missingFeature = structuredClone(fixture.replay);
    missingFeature.observation.requiredFeatures = ["simd"];
    expect(checkExternalReplayEvidence(missingFeature, fixture.report, true)).toEqual({
      status: "failed",
      detail: "external replay missing required feature simd",
    });

    const missingExport = structuredClone(fixture.replay);
    missingExport.observation.requiredExports = ["main", "missing-memory"];
    expect(checkExternalReplayEvidence(missingExport, fixture.report, true)).toEqual({
      status: "failed",
      detail: "external replay missing required export missing-memory",
    });

    const unavailableEntrypoint = structuredClone(fixture.replay);
    unavailableEntrypoint.observation.entrypoint = "missing-main";
    expect(checkExternalReplayEvidence(unavailableEntrypoint, fixture.report, true)).toEqual({
      status: "failed",
      detail: "external replay entrypoint missing-main is unavailable",
    });

    const silent = structuredClone(fixture.replay);
    silent.observation.minimumStateChanges = 2;
    expect(checkExternalReplayEvidence(silent, fixture.report, true)).toMatchObject({
      status: "failed",
      detail: expect.stringContaining("silently did insufficient work"),
    });

    expect(checkExternalReplayEvidence(fixture.replay, fixture.report, false)).toEqual({
      status: "failed",
      detail: "external replay optimizer output is byte-identical",
    });
  });

  test("keeps replay observation contracts stable across Node patch releases", () => {
    const fixture = externalReplayEvidenceFixture();
    const otherRuntime = structuredClone(fixture.report.original);
    otherRuntime.runtime.identity = "node:v26.10.0";
    expect(externalReplayObservationHash(otherRuntime)).toBe(
      fixture.replay.observation.expectedObservationHash,
    );
  });

  test("parses direct replay options with stable pass order", () => {
    expect(
      parseOptimizerSeedRunArgs([
        "--pass",
        "vacuum",
        "--pass",
        "merge-blocks",
        "--self-semantic",
        "--semantic-oracle", "node-v2",
        "--observation-mode", "stateful",
        "--debug-serial-passes",
      ]),
    ).toMatchObject({
      passFlags: ["--vacuum", "--merge-blocks"],
      selfSemantic: true,
      semanticOracle: "node-v2",
      observationMode: "stateful",
      serialPasses: true,
    });
  });
});
