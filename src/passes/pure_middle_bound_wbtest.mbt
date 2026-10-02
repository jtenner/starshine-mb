///|
test "dupable suffix middle keeps only the first safe statement without narrowing admission" {
  let (input, env, body) = sl_balanced_range_fixture(
    "call $tick nop call $tick nop local.get 0 call $consume", "i32",
  )
  let saved = @binary.encode_module(input).unwrap()
  let bounded : Array[@lib.Instruction] = []
  let end = sl_collect_pure_suffix_movable_middle(
    body,
    0,
    env,
    0,
    [],
    bounded,
    true,
  )
  assert_eq(end, 1)
  assert_eq(bounded, body[0:1].to_owned())
  let complete : Array[@lib.Instruction] = []
  let complete_end = sl_collect_pure_suffix_movable_middle(
    body,
    0,
    env,
    0,
    [],
    complete,
    false,
  )
  assert_eq(complete_end, 4)
  assert_eq(complete, body[0:4].to_owned())
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "pure middle admission preserves target read write and source write barriers" {
  for
    body in [
      "local.get 0 call $consume", "i32.const 7 local.set 0", "block call $tick end",
      "i32.const 1 if call $tick end",
    ] {
    let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
    let saved = @binary.encode_module(input).unwrap()
    for dupable in [false, true] {
      let middle : Array[@lib.Instruction] = []
      assert_eq(
        sl_collect_pure_suffix_movable_middle(
          instrs,
          0,
          env,
          0,
          [],
          middle,
          dupable,
        ),
        0,
      )
      assert_eq(middle.length(), 0)
      // The same write is a barrier when it clobbers the producer's source.
      if body == "i32.const 7 local.set 0" {
        assert_eq(
          sl_collect_pure_suffix_movable_middle(
            instrs,
            0,
            env,
            1,
            [0],
            middle,
            dupable,
          ),
          0,
        )
      }
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "bounded pure middle preserves full suffix rewrites effects traps and write barriers" {
  for
    body in [
      "i32.const 7 local.set 0 call $tick nop call $tick local.get 0 call $consume",
      "i32.const 7 local.set 0 i32.const 9 local.set 0 local.get 0 call $consume",
      "i32.const 7 local.set 0 call $tick local.get 0 call $consume local.get 0 call $consume",
      "i32.const 7 local.set 0 call $tick i32.const 1 i32.const 0 i32.div_s drop local.get 0 call $consume",
      "i32.const 7 local.set 0 call $produce call $consume call $tick local.get 0 call $consume",
      "i32.const 7 local.set 0 call $tick i32.const 1 if local.get 0 call $consume end",
    ] {
    let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
    let saved = @binary.encode_module(input).unwrap()
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat(
      instrs, env,
    )
    assert_eq(actual, sl_pure_middle_reference_flat(instrs, env))
    let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
