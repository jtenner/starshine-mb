///|
fn dae2_loop_effect_call_count(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(0U)) => count += 1
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        count += dae2_loop_effect_call_count(child)
      @lib.If(_, yes, no) => {
        count += dae2_loop_effect_call_count(yes)
        if no is Some(child) {
          count += dae2_loop_effect_call_count(child)
        }
      }
      @lib.Try(_, @lib.Expr(child), catches, _) => {
        count += dae2_loop_effect_call_count(child)
        for catch_ in catches {
          let @lib.Expr(child) = match catch_ {
            @lib.LegacyCatch(_, child) | @lib.LegacyCatchAll(child) => child
          }
          count += dae2_loop_effect_call_count(child)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "simplify-locals loop result promotion retains one evaluation of an effectful tail" {
  for suffix in ["local.get 0", "local.get 0 local.get 0 i32.add"] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (func (export \"run\") (result i32) (local i32) loop call $produce local.set 0 end \{suffix}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let func = @ir.hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(1U),
      @ir.hot_module_context_from_module(input),
    ).unwrap()
    let counts = simplify_locals_count_local_gets(func)
    let loop_id = @ir.hot_root_get(func, 0)
    assert_true(
      simplify_locals_try_rewrite_loop_return(
        func,
        @ir.HotRegionRef::root(),
        0,
        loop_id,
        counts,
        [],
      ),
    )
    @ir.hot_verify_all(func).unwrap()
    let lowered = @ir.hot_lower_func(func)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    assert_eq(
      dae2_loop_effect_call_count(body),
      1,
      msg="\{suffix}: \{@lib.Expr::new(body)}",
    )
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 optimizing cleanup executes a call stored by a void loop exactly once at every stage" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (global $effects (mut i32) (i32.const 0)) (func $h (param i32 i32 i32 i64) (result i32) global.get $effects i32.const 1 i32.add global.set $effects local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) loop local.get 0 local.get 1 i32.load local.get 2 i64.const 9 call $h local.set 3 end local.get 3))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let mut current = dae2_run_module_pass(input, false).unwrap()
  for stage in ["dae2", "simplify-locals", "vacuum", "capture-cleanup"] {
    if stage == "capture-cleanup" {
      current = dae2_cleanup_captures(current)
    } else if stage != "dae2" {
      current = run_hot_pipeline(current, HotPipelineOptions::new(), [stage]).unwrap()
    }
    @validate.validate_module(current).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = current.code_sec.unwrap().0[1]
    assert_eq(
      dae2_loop_effect_call_count(body),
      1,
      msg="\{stage}: \{@lib.Expr::new(body)}",
    )
    assert_eq(current.mem_sec, input.mem_sec)
    assert_eq(current.global_sec, input.global_sec)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
