///|
test "fifth audit DAE NaN complement f32 lt 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const nan f32.const 0 f32.lt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 lt 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const 0 f32.const nan f32.lt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 gt 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const nan f32.const 0 f32.gt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 gt 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const 0 f32.const nan f32.gt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 le 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const nan f32.const 0 f32.le i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 le 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const 0 f32.const nan f32.le i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 ge 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const nan f32.const 0 f32.ge i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f32 ge 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f32.const 0 f32.const nan f32.ge i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 lt 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const nan f64.const 0 f64.lt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 lt 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const 0 f64.const nan f64.lt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 gt 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const nan f64.const 0 f64.gt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 gt 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const 0 f64.const nan f64.gt i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 le 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const nan f64.const 0 f64.le i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 le 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const 0 f64.const nan f64.le i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 ge 0" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const nan f64.const 0 f64.ge i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

///|
test "fifth audit DAE NaN complement f64 ge 1" {
  let input = pass_test_module_from_wat("(module (func (result i32) f64.const 0 f64.const nan f64.ge i32.eqz))")
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let body = dae_simplify_rewritten_control_instrs(body, false)
  let rewritten = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]))
  let output = run_hot_pipeline(rewritten, HotPipelineOptions::new(), ["precompute"]).unwrap()
  let @lib.Func(_, @lib.Expr(result)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(result, [@lib.Instruction::i32_const(@lib.I32(1))])
}

