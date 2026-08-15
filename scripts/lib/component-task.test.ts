import { describe, expect, test } from "bun:test";

import {
  buildComponentCommandPlan,
  internalizeMoonBitRuntimeImports,
  normalizeGeneratedText,
  parseComponentArgs,
  patchGeneratedMoonModule,
  validateComponentVersionSources,
} from "./component-task";

describe("component task", () => {
  test("defaults build output and pinned tools", () => {
    expect(parseComponentArgs(["build"])).toEqual({
      command: "build",
      moonBin: "moon",
      wasmToolsBin: "wasm-tools",
      witBindgenBin: null,
      outDir: "dist/component",
      release: true,
    });
  });

  test("parses generation and build overrides", () => {
    expect(parseComponentArgs([
      "build",
      "--moon",
      "moon-test",
      "--wasm-tools",
      "wasm-tools-test",
      "--wit-bindgen",
      "/tmp/wit-bindgen",
      "--out-dir",
      "artifacts/component",
      "--debug",
    ])).toEqual({
      command: "build",
      moonBin: "moon-test",
      wasmToolsBin: "wasm-tools-test",
      witBindgenBin: "/tmp/wit-bindgen",
      outDir: "artifacts/component",
      release: false,
    });
  });

  test("requires the Moon module, WIT package, and metadata API versions to match", () => {
    expect(validateComponentVersionSources(
      'name = "jtenner/starshine"\nversion = "0.1.1"\n',
      "package jtenner:starshine-component@0.1.1;",
      'pub fn version() -> String { "0.1.1" }',
    )).toBe("0.1.1");

    expect(() => validateComponentVersionSources(
      'version = "0.1.2"',
      "package jtenner:starshine-component@0.1.1;",
      'pub fn version() -> String { "0.1.1" }',
    )).toThrow("component version mismatch");
  });

  test("normalizes generated text for clean checked-in diffs", () => {
    expect(normalizeGeneratedText("first  \r\nsecond\t\r\n\r\n")).toBe("first\nsecond\n");
  });

  test("patches generated module metadata to consume the local Starshine checkout", () => {
    const patched = patchGeneratedMoonModule({
      name: "jtenner/starshine-component",
      preferredTarget: "wasm",
    });

    expect(patched).toEqual({
      name: "jtenner/starshine-component",
      preferredTarget: "wasm",
      deps: {
        "jtenner/starshine": "0.1.1",
      },
    });
  });

  test("internalizes known MoonBit runtime imports after every retained component import", () => {
    const input = [
      "(module",
      "  (type $#type0 (func (result i64)))",
      "  (type $#type1 (func (param externref) (result externref)))",
      "  (import \"__moonbit_time_unstable\" \"now\" (func $#func0 (;0;) (type $#type0)))",
      "  (import \"__moonbit_fs_unstable\" \"finish_create_byte_array\" (func $#func1 (;1;) (type $#type1)))",
      "  (import \"[export]probe:core-ir/api\" \"[resource-rep]module\" (func $#func2 (;2;) (type $#type1)))",
      ")",
    ].join("\n");

    expect(internalizeMoonBitRuntimeImports(input, ["now", "finish_create_byte_array"])).toContain(
      "(func $#func0 (;0;) (type $#type0) i64.const 0)",
    );
    const output = internalizeMoonBitRuntimeImports(input, ["now", "finish_create_byte_array"]);
    expect(output).toContain("(func $#func1 (;1;) (type $#type1) local.get 0)");
    expect(output.indexOf("[resource-rep]module")).toBeLessThan(output.indexOf("(func $#func0"));
  });

  test("build plan generates bindings, builds linear wasm, internalizes runtime imports, embeds WIT, creates the component, and validates it", () => {
    const plan = buildComponentCommandPlan({
      repoRoot: "/repo",
      moonBin: "moon",
      wasmToolsBin: "wasm-tools",
      witBindgenBin: "/repo/.tmp/component-tools/bin/wit-bindgen",
      outDir: "/repo/dist/component",
      release: true,
    });

    expect(plan.map((step) => [step.command, step.args])).toEqual([
      [
        "/repo/.tmp/component-tools/bin/wit-bindgen",
        [
          "moonbit",
          "--out-dir",
          "/repo/.tmp/component-generation",
          "/repo/component/wit",
          "--derive-debug",
          "--derive-eq",
        ],
      ],
      ["moon", ["-C", "/repo/component", "update"]],
      [
        "moon",
        [
          "-C",
          "/repo/component",
          "test",
          "--target",
          "wasm",
          "--package",
          "jtenner/starshine-component/gen/interface/jtenner/starshine-component/modules",
        ],
      ],
      [
        "moon",
        [
          "-C",
          "/repo/component",
          "check",
          "--target",
          "wasm",
          "--package-path",
          "gen/interface/jtenner/starshine-component/core-ir",
        ],
      ],
      ["moon", ["-C", "/repo/component", "build", "--target", "wasm", "--release"]],
      [
        "wasm-tools",
        [
          "print",
          "--name-unnamed",
          "/repo/component/_build/wasm/release/build/jtenner/starshine-component/gen/gen.wasm",
          "-o",
          "/repo/dist/component/starshine.runtime-internalized.wat",
        ],
      ],
      [
        "wasm-tools",
        [
          "parse",
          "/repo/dist/component/starshine.runtime-internalized.wat",
          "-o",
          "/repo/dist/component/starshine.runtime-internalized.wasm",
        ],
      ],
      [
        "wasm-tools",
        [
          "validate",
          "--features",
          "all",
          "/repo/dist/component/starshine.runtime-internalized.wasm",
        ],
      ],
      [
        "wasm-tools",
        [
          "component",
          "embed",
          "--world",
          "starshine",
          "--encoding",
          "utf16",
          "/repo/component/wit",
          "/repo/dist/component/starshine.runtime-internalized.wasm",
          "-o",
          "/repo/dist/component/starshine.embedded.wasm",
        ],
      ],
      [
        "wasm-tools",
        [
          "component",
          "new",
          "/repo/dist/component/starshine.embedded.wasm",
          "-o",
          "/repo/dist/component/starshine.component.wasm",
        ],
      ],
      ["wasm-tools", ["validate", "--features", "all", "/repo/dist/component/starshine.component.wasm"]],
      [
        "wasm-tools",
        ["component", "wit", "/repo/dist/component/starshine.component.wasm"],
      ],
    ]);
  });
});
