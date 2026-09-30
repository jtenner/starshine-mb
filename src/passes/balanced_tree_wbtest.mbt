///|
test "balanced cleanup borrows unchanged nested control storage" {
  for
    body in [
      "block call $produce call $consume end", "loop call $produce call $consume end",
      "try_table call $produce call $consume end", "i32.const 1 if call $produce call $consume else call $tick end",
      "block call $produce local.set 0 local.get 0 call $consume local.get 0 call $consume end",
    ] {
    let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
    let saved = @binary.encode_module(input).unwrap()
    let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets(
      instrs, env,
    )
    assert_eq(actual, sl_balanced_tree_reference(instrs, env))
    assert_eq(actual.1, 0)
    assert_true(physical_equal(actual.0, instrs))
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "balanced cleanup owns changed paths and preserves all control rewrites" {
  let active = "call $produce local.set 0 call $tick local.get 0 call $consume"
  for type_ in ["i32", "i64", "externref"] {
    for
      body in [
        "block \{active} end",
        "loop \{active} end",
        "block call $produce local.set 0 i32.const 1 i32.const 0 i32.div_s drop local.get 0 call $consume end",
        "try_table \{active} end",
        "i32.const 1 if \{active} else call $tick end",
        "i32.const 1 if call $tick else \{active} end",
        "block loop i32.const 1 if \{active} end end end",
      ] {
      let (input, env, instrs) = sl_balanced_range_fixture(body, type_)
      let saved = @binary.encode_module(input).unwrap()
      let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets(
        instrs, env,
      )
      assert_eq(actual, sl_balanced_tree_reference(instrs, env))
      assert_eq(actual.1, 1)
      assert_false(physical_equal(actual.0, instrs))
      let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
        ),
      ).unwrap()
      // The actual next consumer may reuse unchanged storage but must never write it.
      let (pure, _) = run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
        actual.0,
        env,
      )
      let (carrier, _) = run_hot_pipeline_raw_simplify_locals_rewrite_control_carrier_local_gets_fixpoint(
        pure,
      )
      ignore(
        run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
          carrier, env,
        ),
      )
      actual.0[0] = @lib.Instruction::nop()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "balanced cleanup preserves unchanged siblings and both changed if arms" {
  let active = "call $produce local.set 0 call $tick local.get 0 call $consume"
  let (input, env, instrs) = sl_balanced_range_fixture(
    "block call $tick end i32.const 1 if \{active} else \{active} end block call $tick end",
    "i32",
  )
  let saved = @binary.encode_module(input).unwrap()
  let actual = run_hot_pipeline_raw_simplify_locals_rewrite_balanced_statement_local_gets(
    instrs, env,
  )
  assert_eq(actual, sl_balanced_tree_reference(instrs, env))
  assert_eq(actual.1, 2)
  assert_true(physical_equal(actual.0[0], instrs[0]))
  assert_true(physical_equal(actual.0[3], instrs[3]))
  match actual.0[2] {
    @lib.If(_, yes, Some(no)) => {
      yes[0] = @lib.Instruction::nop()
      no[0] = @lib.Instruction::nop()
    }
    _ => abort("expected rewritten if with both arms")
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
