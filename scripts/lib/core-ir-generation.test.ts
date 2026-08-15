import { describe, expect, test } from "bun:test";
import fs from "node:fs";

import { generateCoreIrBindings } from "./core-ir-generation";

const fixture = `
pub(all) struct I32(Int) derive(Eq)
pub fn I32::new(Int) -> Self

pub enum Instruction {
  Nop
  I32Const(I32)
  Block(BlockType, Expr)
}
pub fn Instruction::nop() -> Self
pub fn Instruction::i32_const(I32) -> Self
pub fn Instruction::block(BlockType, Expr) -> Self
pub fn Instruction::drop() -> Self

pub enum Expr {
  Expr(Array[Instruction])
}
pub fn Expr::new(Array[Instruction]) -> Self

pub enum BlockType {
  VoidBlockType
}
pub fn BlockType::void() -> Self

pub struct TypeSec(Array[RecType])
pub fn TypeSec::new(Array[RecType]) -> Self

pub struct RecType(SubType)
pub fn RecType::new(SubType) -> Self

pub struct SubType(CompType)
pub fn SubType::comp_type(CompType) -> Self

pub enum CompType {
  FuncCompType(Array[ValType], Array[ValType])
}
pub fn CompType::func(Array[ValType], Array[ValType]) -> Self

pub enum ValType { I32ValType }
pub fn ValType::i32() -> Self

pub struct Module { type_sec : TypeSec?; body : Expr? }
pub fn Module::new(type_sec? : TypeSec?, body? : Expr?) -> Self
pub fn Module::with_type_sec(Self, TypeSec) -> Self
`;

describe("core IR binding generation", () => {
  test("covers the current public module-construction graph", () => {
    const generated = generateCoreIrBindings(
      fs.readFileSync("src/lib/pkg.generated.mbti", "utf8"),
    );

    expect(generated.resourceCount).toBe(88);
    expect(generated.constructorCount).toBe(851);
    expect(generated.wit).toContain("resource module {");
    expect(generated.wit).toContain("resource instruction {");
    expect(generated.wit).toContain("i32-add: static func() -> instruction;");
    expect(generated.wit).toContain("try-table: static func(");
    expect(generated.wit).toContain("array-new-fixed: static func(");
  });

  test("generates recursive IR as resources with typed constructor methods", () => {
    const generated = generateCoreIrBindings(fixture);

    expect(generated.resourceCount).toBe(10);
    expect(generated.constructorCount).toBe(14);
    expect(generated.wit).toContain("resource instruction {");
    expect(generated.wit).toContain(
      "block: static func(p0: borrow<block-type>, p1: borrow<expr>) -> instruction;",
    );
    expect(generated.wit).toContain(
      "create: static func(p0: list<borrow<instruction>>) -> expr;",
    );
    expect(generated.wit).toContain("drop-op: static func() -> instruction;");
    expect(generated.wit).toContain(
      "with-type-sec: static func(p0: borrow<module>, p1: borrow<type-sec>) -> module;",
    );
    expect(generated.wit).toContain("empty-module: func() -> module;");
    expect(generated.wit).toContain(
      "encode-module: func(value: borrow<module>) -> result<list<u8>, diagnostic>;",
    );
  });

  test("generates MoonBit resource storage and constructor conversion", () => {
    const generated = generateCoreIrBindings(fixture);

    expect(generated.implementation).toContain(
      "let core_ir_instruction_values : Array[@lib.Instruction?] = []",
    );
    expect(generated.implementation).toContain("Instruction::new(rep)");
    expect(generated.implementation).toContain(
      "let core_ir_instruction_free_reps : Array[Int] = []",
    );
    expect(generated.implementation).toContain("let Instruction(rep) = value");
    expect(generated.implementation).not.toContain("value.rep()");
    expect(generated.implementation.split("\n").some((line) => /\s+$/.test(line))).toBeFalse();
    expect(generated.implementation).toContain(
      "pub fn Expr::create(\n  p0 : Array[Instruction]\n) -> Expr",
    );
    expect(generated.implementation).toContain(
      "@lib.Expr::new(core_ir_instruction_array(p0))",
    );
    expect(generated.implementation).toContain(
      "@lib.Module::new(type_sec=core_ir_type_sec_option(type_sec), body=core_ir_expr_option(body))",
    );
    expect(generated.implementation).toContain(
      "@lib.Module::with_type_sec(core_ir_module_get(p0), core_ir_type_sec_get(p1))",
    );
  });

  test("rejects constructor parameter shapes that cannot be represented", () => {
    expect(() => generateCoreIrBindings(`${fixture}\npub fn Expr::bad((Int, Int)) -> Self\n`)).toThrow(
      "unsupported Core IR constructor parameter",
    );
  });
});
