import { describe, expect, test } from "bun:test";

import { buildNamedTwoModuleWast } from "./fuzz-wast-linking";

describe("fuzz WAST linking fixtures", () => {
  test("generates a named two-module script with register wiring", () => {
    const script = buildNamedTwoModuleWast();

    expect(script).toContain('(module $provider');
    expect(script).toContain('(register "provider" $provider)');
    expect(script).toContain('(module $consumer');
    expect(script).toContain('(import "provider" "value" (func $value (result i32)))');
  });
});
