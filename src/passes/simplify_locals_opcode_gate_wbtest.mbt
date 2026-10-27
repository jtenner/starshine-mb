///|
fn sl_opcode_gate_run(
  kind : Int32,
  body : Array[@lib.Instruction],
  reference : Bool,
) -> (Array[@lib.Instruction], Int32) {
  match kind {
    0 =>
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          body,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences(
          body,
        )
      }
    1 =>
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences_opcode_reference(
          body,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_alternating_simd_recurrences(
          body,
        )
      }
    2 =>
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries_opcode_reference(
          body,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_split_i32x4_rotate_temporaries(
          body,
        )
      }
    3 =>
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers_opcode_reference(
          body,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_commutative_simd_carriers(
          body,
        )
      }
    4 =>
      if reference {
        run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_opcode_reference(
          body,
        )
      } else {
        run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences(
          body,
        )
      }
    _ => abort("unknown opcode gate control")
  }
}

///|
fn sl_opcode_gate_scalar_fixture(width : Int32) -> @lib.Module {
  let out = StringBuilder()
  for _ in 0..<width {
    out.write_string(
      "local.get 0 local.set 1 local.get 1 drop call $effect i32.const 0 i32.load drop ",
    )
  }
  let body = out.to_string()
  pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect)) (memory 1) (func (param i32) (local i32) block loop \{body} end end))",
  )
}

///|
test "opcode-free cleanup preserves scalar effects and returns the unchanged body" {
  let input = sl_opcode_gate_scalar_fixture(1)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  for kind in 0..<5 {
    let (expected, expected_count) = sl_opcode_gate_run(kind, body, true)
    let (actual, count) = sl_opcode_gate_run(kind, body, false)
    assert_eq(count, expected_count)
    assert_eq(count, 0)
    assert_eq(actual, expected)
    assert_true(
      physical_equal(actual, body),
      msg="opcode-free cleanup copied its input",
    )
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
fn sl_opcode_gate_active_fixture(kind : Int32) -> @lib.Module {
  let (params, locals, result, body) = match kind {
    0 => {
      let step = "local.get 0 local.get 2 i32.add local.tee 1 local.get 3 i32.add local.tee 2 local.get 1 i32.add local.set 3 "
      ("i32", "i32 i32 i32", "i32", "\{step}\{step} local.get 3")
    }
    // Despite its name, this recurrence also supports scalar binary operators.
    1 => {
      let step = "local.get 0 local.get 1 i32.add local.set 0 local.get 1 local.get 0 i32.xor local.set 1 "
      ("i32 i32", "", "i32", "\{step}\{step} local.get 1")
    }
    2 =>
      (
        "v128", "v128 v128", "v128", "local.get 0 i32.const 8 i32x4.shr_u local.set 1 local.get 0 i32.const 24 i32x4.shl local.set 2 local.get 1 local.get 2 v128.or",
      )
    3 =>
      (
        "v128 v128", "v128", "v128", "local.get 0 local.set 2 local.get 1 local.get 2 v128.xor",
      )
    4 => {
      let step = "local.get 0 local.get 1 v128.const i32x4 1 2 3 4 v128.bitselect local.set 0 local.get 1 local.get 0 v128.const i32x4 1 2 3 4 v128.bitselect local.set 1 "
      ("v128 v128", "", "v128", "\{step}\{step} local.get 1")
    }
    _ => abort("unknown active opcode gate control")
  }
  let declarations = if locals == "" { "" } else { "(local \{locals})" }
  pass_test_module_from_wat(
    "(module (func (param \{params}) (result \{result}) \{declarations} block nop end block (result \{result}) \{body} end))",
  )
}

///|
test "admitted cleanup retains active scalar and SIMD rewrites with owned nested rows" {
  for kind in 0..<5 {
    let input = sl_opcode_gate_active_fixture(kind)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let (expected, expected_count) = sl_opcode_gate_run(kind, body, true)
    let (actual, count) = sl_opcode_gate_run(kind, body, false)
    assert_true(count > 0)
    assert_eq(count, expected_count)
    assert_eq(actual, expected)
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    // Later cleanup may mutate an inactive sibling after an active rewrite.
    // The active worker must therefore retain its complete deep-owned result.
    match actual[0] {
      @lib.Block(_, @lib.Expr(sibling)) =>
        sibling[0] = @lib.Instruction::unreachable_()
      _ => abort("missing unchanged sibling block")
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
