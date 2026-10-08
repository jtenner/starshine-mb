///|
test "direct full SSA merges the write bypassed by a branch inside an operand" {
  let text = "(module (func (export \"f\") (param $p i32) (result i32) (local $x i32) (local.set $x (i32.const 5)) (drop (block $v (result i32) (local.set $x (if (result i32) (local.get $p) (then (br_if $v (i32.const 0) (i32.const 1))) (else (i32.const 0)))) (i32.const 0))) (local.get $x)))"
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    ssa_full_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(ssa_full_run(ctx, func))
  for output in [@ir.hot_lower_func(func)] {
    let @lib.Func(_, @lib.Expr(body)) = output
    let target = match body.last() {
      Some(@lib.LocalGet(target)) => target
      _ => abort("expected final SSA local read")
    }
    assert_eq(
      p00_flow_count(body, fn(instr) {
        match instr {
          @lib.LocalSet(local) | @lib.LocalTee(local) => local == target
          _ => false
        }
      }),
      2,
    )
  }
}
