import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

export type TextAdapterName = "local" | "wabt" | "wasm-tools" | (string & {});

export type TextAdapterClassification =
  | "accepted"
  | "parse-error"
  | "unsupported-syntax"
  | "adapter-unavailable"
  | "adapter-error";

export type FakeTextAdapterInput = {
  adapter: TextAdapterName;
  ok: boolean;
  text?: string;
  diagnostic?: string;
  unsupported?: boolean;
  unavailable?: boolean;
};

export type TextAdapterResult = {
  adapter: TextAdapterName;
  classification: TextAdapterClassification;
  diagnostic?: string;
};

export type TextAdapterComparison = {
  schema: "starshine.fuzz.text-adapters.v1";
  inputHash: string;
  adapters: TextAdapterResult[];
  summary: Partial<Record<TextAdapterClassification, number>>;
};

function sha256Hex(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

function classifyFakeTextAdapter(input: FakeTextAdapterInput): TextAdapterResult {
  let classification: TextAdapterClassification;
  if (input.unavailable) classification = "adapter-unavailable";
  else if (input.unsupported) classification = "unsupported-syntax";
  else if (input.ok) classification = "accepted";
  else classification = "parse-error";
  return {
    adapter: input.adapter,
    classification,
    diagnostic: input.diagnostic,
  };
}

export function runOptionalWabtTextAdapter(
  sourceText: string,
  command = process.env.WABT_WAT2WASM_BIN || "wat2wasm",
): TextAdapterResult {
  const tmpdir = fs.mkdtempSync(path.join(os.tmpdir(), "starshine-wabt-text-adapter-"));
  const inputPath = path.join(tmpdir, "case.wat");
  const outputPath = path.join(tmpdir, "case.wasm");
  fs.writeFileSync(inputPath, sourceText);
  const result = spawnSync(command, [inputPath, "-o", outputPath], { encoding: "utf8" });
  if (result.error) {
    const err = result.error as NodeJS.ErrnoException;
    if (err.code === "ENOENT") {
      return {
        adapter: "wabt",
        classification: "adapter-unavailable",
        diagnostic: `WABT wat2wasm unavailable: ${command}`,
      };
    }
    return {
      adapter: "wabt",
      classification: "adapter-error",
      diagnostic: err.message,
    };
  }
  if (result.status === 0) {
    return { adapter: "wabt", classification: "accepted", diagnostic: undefined };
  }
  return {
    adapter: "wabt",
    classification: "parse-error",
    diagnostic: (result.stderr || result.stdout || `wat2wasm exited ${result.status}`).trim(),
  };
}

export function classifyFakeTextAdapters(
  sourceText: string,
  inputs: FakeTextAdapterInput[],
): TextAdapterComparison {
  const adapters = inputs.map(classifyFakeTextAdapter);
  const summary: Partial<Record<TextAdapterClassification, number>> = {};
  for (const result of adapters) {
    summary[result.classification] = (summary[result.classification] ?? 0) + 1;
  }
  return {
    schema: "starshine.fuzz.text-adapters.v1",
    inputHash: sha256Hex(sourceText),
    adapters,
    summary,
  };
}
