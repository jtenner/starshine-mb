///|
test "fifth audit nested i32 shl 31 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 1 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shl 31 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 1 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shl 16 16 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shl i32.const 16 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shl 16 16 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shl i32.const 16 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shl 31 31 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 31 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shl 31 31 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shl i32.const 31 i32.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 31 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_u i32.const 1 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 31 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_u i32.const 1 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 16 16 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shr_u i32.const 16 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 16 16 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shr_u i32.const 16 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 31 31 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_u i32.const 31 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_u 31 31 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_u i32.const 31 i32.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_s 31 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_s i32.const 1 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(-1))])
}

///|
test "fifth audit nested i32 shr_s 31 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_s i32.const 1 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_s 16 16 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shr_s i32.const 16 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(-1))])
}

///|
test "fifth audit nested i32 shr_s 16 16 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 16 i32.shr_s i32.const 16 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i32 shr_s 31 31 -1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_s i32.const 31 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(-1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(-1))])
}

///|
test "fifth audit nested i32 shr_s 31 31 1" {
  let input = pass_test_module_from_wat("(module (func (param i32) (result i32) local.get 0 i32.const 31 i32.shr_s i32.const 31 i32.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i32_const(@lib.I32(1)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i32_const(@lib.I32(0))])
}

///|
test "fifth audit nested i64 shl 63 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shl i64.const 1 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shl 63 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shl i64.const 1 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shl 32 32 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shl i64.const 32 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shl 32 32 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shl i64.const 32 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shl 63 63 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shl i64.const 63 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shl 63 63 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shl i64.const 63 i64.shl))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 63 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_u i64.const 1 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 63 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_u i64.const 1 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 32 32 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shr_u i64.const 32 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 32 32 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shr_u i64.const 32 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 63 63 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_u i64.const 63 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_u 63 63 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_u i64.const 63 i64.shr_u))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_s 63 1 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_s i64.const 1 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(-1L))])
}

///|
test "fifth audit nested i64 shr_s 63 1 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_s i64.const 1 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_s 32 32 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shr_s i64.const 32 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(-1L))])
}

///|
test "fifth audit nested i64 shr_s 32 32 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 32 i64.shr_s i64.const 32 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested i64 shr_s 63 63 -1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_s i64.const 63 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(-1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(-1L))])
}

///|
test "fifth audit nested i64 shr_s 63 63 1" {
  let input = pass_test_module_from_wat("(module (func (param i64) (result i64) local.get 0 i64.const 63 i64.shr_s i64.const 63 i64.shr_s))")
  let optimized = run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  let body = body.map(fn(i) { if i is @lib.LocalGet(@lib.LocalIdx(0U)) { @lib.Instruction::i64_const(@lib.I64(1L)) } else { i } })
  let substituted = optimized.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(substituted, HotPipelineOptions::new(), ["precompute"]).unwrap()
  @debug.assert_eq(audit_body(output), [@lib.Instruction::i64_const(@lib.I64(0L))])
}

///|
test "fifth audit nested effectful i32 shl" {
  let output = audit_run("(module (import \"m\" \"effect\" (func (result i32))) (func (result i32) call 0 i32.const 16 i32.shl i32.const 16 i32.shl))", "optimize-instructions")
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }), 1)
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32Shl }), 0)
}

///|
test "fifth audit nested effectful i32 shr_u" {
  let output = audit_run("(module (import \"m\" \"effect\" (func (result i32))) (func (result i32) call 0 i32.const 16 i32.shr_u i32.const 16 i32.shr_u))", "optimize-instructions")
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }), 1)
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I32ShrU }), 0)
}

///|
test "fifth audit nested effectful i64 shl" {
  let output = audit_run("(module (import \"m\" \"effect\" (func (result i64))) (func (result i64) call 0 i64.const 32 i64.shl i64.const 32 i64.shl))", "optimize-instructions")
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }), 1)
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I64Shl }), 0)
}

///|
test "fifth audit nested effectful i64 shr_u" {
  let output = audit_run("(module (import \"m\" \"effect\" (func (result i64))) (func (result i64) call 0 i64.const 32 i64.shr_u i64.const 32 i64.shr_u))", "optimize-instructions")
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.Call(_) }), 1)
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.I64ShrU }), 0)
}

