///|
test "suffix cleanup returns unchanged flat and nested storage without discarding ownership" {
  for
    body in [
      "call $produce call $consume nop", "call $produce local.set 0 call $tick local.get 0 call $consume",
      "block call $produce call $consume end", "loop call $produce call $consume end",
      "try_table call $produce call $consume end", "i32.const 1 if call $produce call $consume else call $tick end",
      "block loop i32.const 1 if call $produce call $consume end end end",
    ] {
    let (input, env, instrs) = sl_balanced_range_fixture(body, "i32")
    let saved = @binary.encode_module(input).unwrap()
    for
      (rewrite, reference) in [
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets, sl_suffix_storage_reference_pure_suffix_local_sets,
        ),
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets,
          sl_suffix_storage_reference_effectful_suffix_local_gets,
        ),
      ] {
      let actual = rewrite(instrs, env)
      assert_eq(actual, reference(instrs, env))
      assert_eq(actual.1, 0)
      assert_true(physical_equal(actual.0, instrs))
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
    for
      (rewrite, reference) in [
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_flat,
          sl_suffix_storage_reference_pure_suffix_local_sets_flat,
        ),
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat,
          sl_suffix_storage_reference_effectful_suffix_local_gets_flat,
        ),
      ] {
      let actual = rewrite(instrs, env)
      assert_eq(actual, reference(instrs, env))
      assert_eq(actual.1, 0)
      assert_true(physical_equal(actual.0, instrs))
    }
  }
}

///|
test "suffix cleanup copies both changed arms before later mutations" {
  for (effectful, producer) in [(false, "i32.const 7"), (true, "call $produce")] {
    let active = "\{producer} local.set 0 nop local.get 0 call $consume"
    let (input, env, body) = sl_balanced_range_fixture(
      "i32.const 1 if \{active} else \{active} end",
      "i32",
    )
    let saved = @binary.encode_module(input).unwrap()
    let rewrite = if effectful {
      run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets
    } else {
      run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets
    }
    let (next, count) = rewrite(body, env)
    assert_eq(count, 2)
    guard body[1] is @lib.If(_, source_yes, Some(source_no)) else {
      fail("expected source conditional")
    }
    guard next[1] is @lib.If(_, yes, Some(no)) else {
      fail("expected changed conditional")
    }
    assert_false(physical_equal(yes, source_yes))
    assert_false(physical_equal(no, source_no))
    yes[0] = @lib.Instruction::unreachable_()
    no[0] = @lib.Instruction::unreachable_()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "suffix cleanup owns changed paths and retains sibling storage and exact rewrites" {
  for
    (effectful, producer, type_) in [
      (false, "i32.const 7", "i32"),
      (false, "i64.const 7", "i64"),
      // The existing predicate classifies reference constants with the
      // non-numeric suffix worker; retain that admission rather than widening it.
      (true, "ref.null extern", "externref"),
      (true, "call $produce", "i32"),
      (true, "call $produce", "i64"),
      (true, "call $produce", "externref"),
      (true, "i32.const 1 i32.const 0 i32.div_s", "i32"),
    ] {
    let active = "\{producer} local.set 0 nop local.get 0 call $consume"
    for
      body in [
        "block \{active} end",
        "loop \{active} end",
        "try_table \{active} end",
        "i32.const 1 if \{active} else call $tick end",
        "i32.const 1 if call $tick else \{active} end",
        "i32.const 1 if \{active} else \{active} end",
        "block call $tick end block loop \{active} end end block call $tick end",
      ] {
      let (input, env, instrs) = sl_balanced_range_fixture(body, type_)
      let saved = @binary.encode_module(input).unwrap()
      let (rewrite, reference) = if effectful {
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets,
          sl_suffix_storage_reference_effectful_suffix_local_gets,
        )
      } else {
        (
          run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets, sl_suffix_storage_reference_pure_suffix_local_sets,
        )
      }
      let actual = rewrite(instrs, env)
      assert_eq(actual, reference(instrs, env))
      if actual.1 == 0 {
        fail(
          "expected active suffix cleanup for \{type_} producer=\{producer}: \{body}",
        )
      }
      assert_false(physical_equal(actual.0, instrs))
      if instrs.length() == 3 {
        assert_true(physical_equal(actual.0[0], instrs[0]))
        assert_true(physical_equal(actual.0[2], instrs[2]))
      }
      let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
      @validate.validate_module(
        input.with_code_sec(
          @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual.0))]),
        ),
      ).unwrap()
      ignore(
        run_hot_pipeline_raw_simplify_locals_rewrite_pure_suffix_local_sets_fixpoint(
          actual.0,
          env,
        ),
      )
      ignore(
        run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_fixpoint(
          actual.0,
          env,
        ),
      )
      actual.0[0] = @lib.Instruction::nop()
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}
