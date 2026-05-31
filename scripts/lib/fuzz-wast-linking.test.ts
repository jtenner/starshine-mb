import { describe, expect, test } from "bun:test";

import {
  buildMissingImportUnlinkableWast,
  buildNamedTwoModuleWast,
  buildTypeMismatchImportUnlinkableWast,
  buildValidImportExportWast,
} from "./fuzz-wast-linking";

describe("fuzz WAST linking fixtures", () => {
  test("generates assert_unlinkable for type-mismatched imports", () => {
    const script = buildTypeMismatchImportUnlinkableWast();

    expect(script).toContain('(module $provider');
    expect(script).toContain('(register "provider" $provider)');
    expect(script).toContain('(assert_unlinkable');
    expect(script).toContain('(import "provider" "value" (func $value (param i32) (result i32)))');
    expect(script).toContain('"incompatible import type"');
  });

  test("generates assert_unlinkable for missing imports", () => {
    const script = buildMissingImportUnlinkableWast();

    expect(script).toContain('(assert_unlinkable');
    expect(script).toContain('(import "missing" "value" (func $value (result i32)))');
    expect(script).toContain('"unknown import"');
  });

  test("generates valid import/export wiring across multiple value kinds", () => {
    const script = buildValidImportExportWast();

    expect(script).toContain('(memory $memory (export "memory") 1)');
    expect(script).toContain('(table $table (export "table") 1 funcref)');
    expect(script).toContain('(global $global (export "global") i32');
    expect(script).toContain('(import "provider" "memory" (memory $memory 1))');
    expect(script).toContain('(import "provider" "table" (table $table 1 funcref))');
    expect(script).toContain('(import "provider" "global" (global $global i32))');
  });

  test("generates a named two-module script with register wiring", () => {
    const script = buildNamedTwoModuleWast();

    expect(script).toContain('(module $provider');
    expect(script).toContain('(register "provider" $provider)');
    expect(script).toContain('(module $consumer');
    expect(script).toContain('(import "provider" "value" (func $value (result i32)))');
  });
});
