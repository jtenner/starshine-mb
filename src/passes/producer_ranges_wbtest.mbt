///|
test "producer ranges preserve pure and effectful rewrites across barriers" {
  for type_ in ["i32", "i64", "externref"] {
    for
      body in [
        "call $produce local.set 0 nop local.get 0 call $consume", "call $produce local.set 0 call $tick local.get 0 call $consume",
        "call $produce local.set 0 local.get 0 call $consume local.get 0 call $consume",
        "call $produce local.set 0 block local.get 0 call $consume end", "call $produce local.set 0 i32.const 1 i32.const 0 i32.div_s drop local.get 0 call $consume",
        "call $produce call $consume nop",
      ] {
      let (input, env, instrs) = sl_balanced_range_fixture(body, type_)
      let saved = @binary.encode_module(input).unwrap()
      let actual = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
        instrs, env,
      )
      assert_eq(
        actual,
        sl_producer_reference_effectful_suffix_local_gets_flat(instrs, env),
      )
      let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
        ),
      ).unwrap()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
  for
    body in [
      "i32.const 7 local.set 0 nop local.get 0 call $consume", "i32.const 3 i32.const 4 i32.add local.set 0 nop local.get 0 call $consume",
      "i32.const 7 local.set 0 call $tick local.get 0 call $consume local.get 0 call $consume",
      "i32.const 7 local.set 0 block local.get 0 call $consume end", "i32.const 7 local.set 0 i32.const 1 i32.const 0 i32.div_s drop local.get 0 call $consume",
      "call $produce call $consume nop",
    ] {
    let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
    let saved = @binary.encode_module(input).unwrap()
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
      instrs, env,
    )
    assert_eq(
      actual,
      sl_producer_reference_pure_suffix_local_sets_flat(instrs, env),
    )
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
