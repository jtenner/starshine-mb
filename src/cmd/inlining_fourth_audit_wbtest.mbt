///|
test "fourth audit command optimizing inlining preserves unrelated infinite loop" {
  let output = cmd_deep_audit_run(
    "(module (func $h (result i32) i32.const 7) (func (export \"trigger\") (result i32) call $h) (func (export \"victim\") (loop br 0) unreachable))",
    "inlining-optimizing",
  )
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  let @lib.Func(_, @lib.Expr(body)) = funcs[funcs.length() - 1]
  @debug.assert_eq(
    cmd_deep_audit_count(body, fn(i) { i is @lib.Loop(_, _) }),
    1,
  )
}

///|
test "fourth audit command optimizing inlining preserves unrelated br return" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func $h (result i32) i32.const 7) (func (export \"trigger\") (result i32) call $h) (func (export \"victim\") (param i32) (result i32) i32.const 7))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let output = cmd_deep_audit_run_module(
    input.with_code_sec(@lib.CodeSec::new(funcs)),
    "inlining-optimizing",
  )
  let out_funcs = output.code_sec.unwrap().0
  @debug.assert_eq(
    cmd_deep_audit_count(
      cmd_deep_audit_body(output, index=out_funcs.length() - 1),
      fn(i) { i is @lib.I32Const(@lib.I32(7)) },
    ),
    1,
  )
}

///|
test "fourth audit command optimizing inlining preserves unrelated br_if return" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func $h (result i32) i32.const 7) (func (export \"trigger\") (result i32) call $h) (func (export \"victim\") (param i32) (result i32) i32.const 7))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::unreachable_(),
    ]),
  )
  let output = cmd_deep_audit_run_module(
    input.with_code_sec(@lib.CodeSec::new(funcs)),
    "inlining-optimizing",
  )
  let out_funcs = output.code_sec.unwrap().0
  @debug.assert_eq(
    cmd_deep_audit_count(
      cmd_deep_audit_body(output, index=out_funcs.length() - 1),
      fn(i) { i is @lib.I32Const(@lib.I32(7)) },
    ),
    1,
  )
}
