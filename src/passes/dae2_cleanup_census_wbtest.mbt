///|
test "DAE2 cleanup hands its census to compaction and preserves exact output" {
  for
    body in [
      "i32.const 7 local.set 0 local.get 0 drop", "i32.const 7 local.set 0 i32.const 8 local.set 1 local.get 1 drop local.get 0 drop",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (local i32 i32) \{body}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let func = input.code_sec.unwrap().0[0]
    let admission = dae2_cleanup_admit_func(
      func,
      [],
      @ir.hot_module_context_from_module(input),
    )
    assert_true(admission.may_change())
    assert_false(admission.has_forwarding())
    let (gets, writes) = admission.local_counts().unwrap()
    assert_true(gets[0] > 0)
    let seed = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let expected = fused_alias_reference_compact(
      func,
      seed,
      [],
      propagate_parameter_aliases=true,
    )
    let actual = pass_lower_compact_captures_with_map(
      func,
      seed,
      [],
      propagate_parameter_aliases=true,
      local_counts=Some((gets, writes)),
    )
    assert_eq(actual, expected)
    // The supplied census belongs to this compaction. Its entries must track
    // removed accesses so no second census is allocated or scanned.
    assert_eq(gets, [0, 0])
    assert_eq(writes, [0, 0])
    let @lib.Func(locals, _) = actual.0
    assert_eq(locals.length(), 0)
    @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([actual.0])),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 cleanup keeps scalar and tuple forwarding label rules" {
  for
    (results, gets) in [
      ("i32", "local.get 0"),
      ("i32 i32", "local.get 0 local.get 1"),
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32 i32) (result \{results}) block (result \{results}) \{gets} end))",
    )
    let func = input.code_sec.unwrap().0[0]
    let admission = dae2_cleanup_admit_func(
      func,
      [@lib.ValType::i32(), @lib.ValType::i32()],
      @ir.hot_module_context_from_module(input),
    )
    assert_true(admission.may_change())
    assert_true(admission.has_forwarding())
    assert_true(admission.local_counts() is None)
    let @lib.Func(_, @lib.Expr(original)) = func
    let (forwarded, changed, scalar) = dae2_cleanup_forwarding(
      original,
      @ir.hot_module_context_from_module(input),
    )
    assert_true(changed)
    assert_eq(scalar, results == "i32")
    let before_gets = [0, 0]
    let before_writes = [0, 0]
    let after_gets = [0, 0]
    let after_writes = [0, 0]
    pass_lower_count_locals(original, before_gets, before_writes)
    pass_lower_count_locals(forwarded, after_gets, after_writes)
    assert_eq(after_gets, before_gets)
    assert_eq(after_writes, before_writes)
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_false(body.any(fn(instr) { instr is @lib.Block(_, _) }))
    assert_eq(body.length(), if results == "i32" { 1 } else { 2 })
  }
}

///|
test "DAE2 normalization output owns nested body containers" {
  for
    (kind, control) in [
      (
        "select", "block local.get 0 local.get 0 i32.const 1 select (result i32) drop end",
      ),
      ("table", "block block i32.const 0 br_table 0 1 end end"),
      ("catch", "block try_table (catch_all 0) local.get 0 drop end end"),
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (local i32 i32) \{control} local.get 0 drop local.get 0 drop local.get 1 drop local.get 1 drop))",
    )
    let @lib.Func(_, expr) = input.code_sec.unwrap().0[0]
    let locals = @lib.Locals::from_decl_runs_preserving_groups([
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
      @lib.LocalRun::new(1U, @lib.ValType::i32()),
    ])
    let func = @lib.Func::new(locals, expr)
    let input = input.with_code_sec(@lib.CodeSec::new([func]))
    let admission = dae2_cleanup_admit_func(
      func,
      [],
      @ir.hot_module_context_from_module(input),
    )
    assert_true(admission is Normalize)
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    let expected = payload_ownership_reference_dae2_cleanup_captures(input)
    assert_eq(output, expected)
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    guard body[0] is @lib.Block(_, @lib.Expr(child)) else {
      fail("expected retained outer block")
    }
    let nested = match (kind, child[0]) {
      ("table", @lib.Block(_, @lib.Expr(nested))) => nested
      ("catch", @lib.TryTable(_, _, @lib.Expr(nested))) => nested
      ("select", _) => child
      _ => fail("missing \{kind} container")
    }
    nested.push(@lib.Instruction::nop())
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 cleanup census keeps unchanged label metadata and remaps local names" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 7 local.set 1 local.get 1 drop block (result i32) local.get 2 local.get 2 i32.add local.get 0 i32.add br 0 end))",
  )
  let local_names = @lib.NameMap::new([
    @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
    @lib.NameAssoc::new(1U, @lib.Name::from_string("removed")),
    @lib.NameAssoc::new(2U, @lib.Name::from_string("retained")),
  ])
  let labels = @lib.IndirectNameMap::new([
    @lib.IndirectNameAssoc::new(
      0U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("branch-target")),
      ]),
    ),
  ])
  let input = input.with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(0U, local_names)]),
      ),
      label_names=Some(labels),
    ),
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let names = output.name_sec.unwrap()
  assert_eq(names.label_names, Some(labels))
  assert_eq(
    names.local_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("parameter")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("retained")),
          ]),
        ),
      ]),
    ),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 cleanup census owns typed select and branch table payloads" {
  for
    control in [
      "local.get 0 local.get 0 local.get 0 select (result i32) drop", "block block local.get 0 br_table 0 1 end end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (local i32) i32.const 7 local.set 1 \{control} local.get 1 drop))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    match raw_structured_select_types(body) {
      Some(types) => types[0] = @lib.ValType::i64()
      None =>
        raw_structured_table_targets(body).unwrap()[0] = @lib.LabelIdx::new(1U)
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 cleanup census owns try table catch arrays" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) i32.const 7 local.set 1 block try_table (catch_all 0) local.get 0 drop end end local.get 1 drop))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  guard body[2] is @lib.Block(_, @lib.Expr(nested)) else {
    fail("expected retained block")
  }
  guard nested[0] is @lib.TryTable(_, catches, _) else {
    fail("expected retained try table")
  }
  catches[0] = @lib.Catch::all(@lib.LabelIdx::new(1U))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
