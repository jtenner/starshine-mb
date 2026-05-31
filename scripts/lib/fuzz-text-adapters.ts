import { createHash } from "node:crypto";

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
