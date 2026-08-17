import { describe, expect, test } from "bun:test";

import {
  generateFfiPackage,
  standardTraitInterfaces,
  rewriteWasmExportNames,
} from "./ffi-generation";

const fixture = `
// Generated using \`moon info\`, DON'T EDIT IT
package "jtenner/starshine/example"

import {
  "moonbitlang/core/debug",
}

// Values
pub fn parse(String, filename? : String) -> Result[Module, String]

pub fn[T : Eq] generic_equals(T, T) -> Bool

// Types and methods
pub struct Module {}
pub fn Module::new(String, id? : String?) -> Self
pub fn Module::render(Self, compact? : Bool) -> String
pub fn Module::merge(Self, Self) -> Self

// Traits
pub trait Pretty {
  fn render(Self) -> String
}
pub impl Pretty for Module

pub trait Equiv {
  fn equivalent(Self, Self) -> Bool
}
pub impl Equiv for Module

pub trait Decode {
  fn decode(Self, Bytes) -> Int
}
pub impl Decode for Bool
pub impl[T : Decode] Decode for T?

pub fn consume_optional_bool(Bool?) -> Unit
`;

describe("FFI package generation", () => {
  test("exports public values and methods with stable linker names", () => {
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
    ]);

    expect(generated.source).toContain("#export_name(\"ffi_example_parse\")");
    expect(generated.source).toContain("pub fn ffi_example_parse(");
    expect(generated.source).toContain("@example.parse(value0, filename?)");
    expect(generated.source).toContain("pub fn ffi_example_Module_new(");
    expect(generated.source).toContain("@example.Module::new(value0, id?)");
    expect(generated.source).toContain("pub fn ffi_example_Module_render(");
    expect(generated.source).toContain("@example.Module::render(receiver, compact?)");
    expect(generated.source).toContain(
      "pub fn ffi_example_Module_merge(receiver : @example.Module, value1 : @example.Module) -> @example.Module",
    );
    expect(generated.source).toContain("@example.Module::merge(receiver, value1)");
    expect(generated.linkExports).toContain("ffi_example_parse:example::parse");
    expect(generated.linkExports).toContain("ffi_example_Module_new:Module::new");
    expect(generated.linkExports).toContain("ffi_example_Module_render:Module::render");
  });

  test("generates one concrete wrapper for each public trait implementer", () => {
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
    ]);

    expect(generated.source).toContain("#export_name(\"ffi_example_Pretty_Module_render\")");
    expect(generated.source).toContain(
      "pub fn ffi_example_Pretty_Module_render(receiver : @example.Module) -> String",
    );
    expect(generated.source).toContain("@example.Pretty::render(receiver)");
    expect(generated.linkExports).toContain(
      "ffi_example_Pretty_Module_render:Pretty::Module::render",
    );
    expect(generated.source).toContain("#export_name(\"ffi_example_Decode_Bool_decode\")");
    expect(generated.source).toContain(
      "pub fn ffi_example_Decode_Bool_decode(receiver : Bool, value1 : Bytes) -> Int",
    );
    expect(generated.linkExports).toContain(
      "ffi_example_Decode_Bool_decode:Decode::Bool::decode",
    );
    expect(generated.source).toContain(
      "pub fn ffi_example_Equiv_Module_equivalent(receiver : @example.Module, value1 : @example.Module) -> Bool",
    );
    expect(generated.source).toContain("@example.Equiv::equivalent(receiver, value1)");
  });

  test("instantiates generic impl patterns only for concrete public signature types", () => {
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
    ]);

    expect(generated.source).toContain("#export_name(\"ffi_example_Decode_Bool_option_decode\")");
    expect(generated.source).toContain(
      "pub fn ffi_example_Decode_Bool_option_decode(receiver : Bool?, value1 : Bytes) -> Int",
    );
    expect(generated.linkExports).toContain(
      "ffi_example_Decode_Bool_option_decode:Decode::Bool?::decode",
    );
    expect(generated.source).not.toContain("Decode_Bool_option_option_decode");
  });

  test("records generic functions but not trait methods with generated implementer wrappers", () => {
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
    ]);

    expect(generated.unsupported).toEqual([
      {
        packagePath: "jtenner/starshine/example",
        symbol: "generic_equals",
        reason: "generic functions require concrete type instantiations before they can be Wasm exports",
      },
    ]);
  });

  test("generates wrappers for public implementers of core and dependency traits", () => {
    const implementer = `
package "jtenner/starshine/example"
import {
  "moonbitlang/core/quickcheck",
}
pub struct Item {}
type Hidden
pub impl Show for Item
pub impl Show for Hidden
pub impl Eq for Item
pub impl Hash for Item
pub impl @quickcheck.Arbitrary for Item
`;
    const generated = generateFfiPackage([
      {
        alias: "example",
        packagePath: "jtenner/starshine/example",
        interfaceText: implementer,
      },
      ...standardTraitInterfaces(),
    ]);

    expect(generated.source).toContain("@builtin.Show::to_string(receiver)");
    expect(generated.linkExports).toContain(
      "ffi_builtin_Show_example_Item_to_string:Show::Item::to_string",
    );
    expect(generated.source).toContain("@builtin.Eq::equal(receiver, value1)");
    expect(generated.source).toContain("@builtin.Hash::hash(receiver)");
    expect(generated.source).toContain("@quickcheck.Arbitrary::arbitrary(value0, value1)");
    expect(generated.linkExports).toContain(
      "ffi_quickcheck_Arbitrary_example_Item_arbitrary:Arbitrary::Item::arbitrary",
    );
    expect(generated.source).not.toContain("Show_example_Hidden");
    expect(generated.unsupported).toContainEqual({
      packagePath: "jtenner/starshine/example",
      symbol: "Show::Hidden",
      reason: "public trait implementation uses a non-public implementing type",
    });
  });

  test("qualifies package-local types while preserving builtins and imported types", () => {
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
    ]);

    expect(generated.source).toContain(
      "pub fn ffi_example_parse(value0 : String, filename : (String)?) -> Result[@example.Module, String]",
    );
    expect(generated.source).toContain(
      "pub fn ffi_example_Module_render(receiver : @example.Module, compact : (Bool)?) -> String",
    );
  });

  test("rewrites valid compiler export names to linker-facing names", () => {
    const bytes = Uint8Array.from([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
      0x07, 0x0d, 0x01, 0x09,
      ...new TextEncoder().encode("ffi_value"),
      0x00, 0x00,
    ]);
    const rewritten = rewriteWasmExportNames(bytes, new Map([["ffi_value", "Module::new"]]));
    expect(new TextDecoder().decode(rewritten)).toContain("Module::new");
    expect(new TextDecoder().decode(rewritten)).not.toContain("ffi_value");
  });

  test("prefixes colliding method export names with the package alias", () => {
    const otherFixture = fixture.replaceAll("jtenner/starshine/example", "jtenner/starshine/other");
    const generated = generateFfiPackage([
      { alias: "example", packagePath: "jtenner/starshine/example", interfaceText: fixture },
      { alias: "other", packagePath: "jtenner/starshine/other", interfaceText: otherFixture },
    ]);

    expect(generated.linkExports).toContain("ffi_example_Module_new:example::Module::new");
    expect(generated.linkExports).toContain("ffi_other_Module_new:other::Module::new");
  });
});
