///|
test "fifth audit command nested i32 shl 31 1 -1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 1 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(-1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}

///|
test "fifth audit command nested i32 shl 31 1 1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 1 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}

///|
test "fifth audit command nested i32 shl 16 16 -1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shl i32.const 16 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(-1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}

///|
test "fifth audit command nested i32 shl 16 16 1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shl i32.const 16 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}

///|
test "fifth audit command nested i32 shl 31 31 -1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 31 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(-1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}

///|
test "fifth audit command nested i32 shl 31 31 1" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 31 i32.shl))",
  )
  let optimized = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) {
    if i is @lib.LocalGet(@lib.LocalIdx(0U)) {
      @lib.Instruction::i32_const(@lib.I32(1))
    } else {
      i
    }
  })
  let substituted = optimized.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  let output = optimize_module_with_pass_flags(
    substituted,
    ["precompute"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(cmd_deep_audit_body(output), [
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
}
