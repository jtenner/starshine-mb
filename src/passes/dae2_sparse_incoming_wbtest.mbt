///|
fn dae2_sparse_exit_fixture(
  width : Int32,
  exits : Int32,
  changes : Int32,
  owned_leaves~ : Bool = false,
) -> @lib.Module {
  let body = StringBuilder::new()
  body.write_string("block $out ")
  for local in 4..<(4 + width) {
    body.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<exits {
    if changes > 0 {
      body.write_string("local.get 1 local.set 4 ")
    }
    if changes > 1 {
      body.write_string("local.get 2 local.set 5 ")
    }
    body.write_string("local.get 0 br_if $out ")
  }
  body.write_string("end ")
  if owned_leaves {
    body.write_string(
      "block $outer block $inner local.get 4 local.get 5 local.get 0 select (result i32) local.set 6 local.get 0 br_table $inner $outer end end ",
    )
  }
  body.write_string("local.get 4 local.get 5 i32.add local.get 6 i32.add")
  let locals = Array::make(width, "i32").join(" ")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{body.to_string()}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
fn dae2_sparse_incoming_compare(
  input : @lib.Module,
  expected_raw~ : Int32 = 2,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (bits, admitted) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (hot_bits, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(bits, hot_bits)
    assert_eq(raw_writes, hot_writes)
    let lifts = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(lifts),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_eq(actual.type_sec, reference.type_sec)
    assert_eq(actual.func_sec, reference.func_sec)
    assert_eq(actual.code_sec, reference.code_sec)
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(actual),
      @lib.FuncIdx::new(0U),
    ).unwrap()
    // A real boundary rewrite is required before the admission assertion.
    assert_eq(params.length(), 3)
    assert_eq(admitted, expected_raw)
    assert_eq(lifts[0], 2 - expected_raw)
  }
}

///|
#skip("dedicated synthetic work-threshold lane; include-skipped required for admission RED")
test "DAE2 two-write sparse exits retain HOT output and every write under the original eight-times bound" {
  // 64 initialized lanes and 64 exits. Every exit changes two lanes, so the
  // existing exact one_changed_local shortcut cannot admit this workload.
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(64, 64, 2))
}

///|
test "DAE2 unchanged and one-write exits retain exact output and boundary pruning" {
  for changes in [0, 1] {
    let input = dae2_sparse_exit_fixture(8, 8, changes)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let raw_writes = []
      let hot_writes = []
      let (bits, _) = raw_conditional_boundary_bits(
        input,
        true,
        closed_world~,
        write_demands=Some(raw_writes),
      )
      let (hot_bits, _) = raw_conditional_boundary_bits(
        input,
        false,
        closed_world~,
        write_demands=Some(hot_writes),
      )
      assert_eq(bits, hot_bits)
      assert_eq(raw_writes, hot_writes)
      let actual = dae2_run_module_pass(input, closed_world).unwrap()
      let reference = dae2_run_module_pass(
        input,
        closed_world,
        raw_analysis=false,
        raw_rewrite=false,
      ).unwrap()
      @validate.validate_module(actual).unwrap()
      @validate.validate_module(reference).unwrap()
      assert_eq(
        @binary.encode_module(actual).unwrap(),
        @binary.encode_module(reference).unwrap(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 sparse merge preserves nested restores applied phis late lanes and default entry demand" {
  for
    body in [
      "block $out local.get 0 br_if $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out local.get 0 if local.get 2 local.set 4 local.get 1 local.set 5 else local.get 1 local.set 4 local.get 2 local.set 5 end local.get 0 br_if $out end local.get 4 local.get 5 i32.add",
      "block $out local.get 0 br_if $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out block local.get 0 if local.get 2 local.set 4 else local.get 1 local.set 4 end end local.get 1 local.set 6 local.get 0 br_if $out end local.get 4 local.get 5 i32.add local.get 6 i32.add",
      "block $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out loop $again local.get 0 if local.get 2 local.set 4 local.get 1 local.set 5 else local.get 1 local.set 4 local.get 2 local.set 5 end local.get 0 i32.const 1 i32.sub local.tee 0 br_if $again end local.get 0 br_if $out end local.get 4 local.get 5 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32 i32 i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    dae2_sparse_incoming_compare(input)
  }
}

///|
test "DAE2 sparse merge retains source identity when equal operands name distinct stores" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32 i32 i32) block $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out local.get 1 local.set 4 local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out end local.get 4 local.get 5 i32.add local.get 6 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  dae2_sparse_incoming_compare(input)
}

///|
#skip("dedicated synthetic work-threshold lane; include-skipped required for admission RED")
test "DAE2 sparse admitted changed output owns branch targets select types and nested siblings" {
  let input = dae2_sparse_exit_fixture(64, 64, 2, owned_leaves=true)
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false, stack_suffix_rewrite=false).unwrap()
  @validate.validate_module(output).unwrap()
  let reference = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
    stack_suffix_rewrite=false,
  ).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let targets = raw_structured_table_targets(body).unwrap()
  let types = raw_structured_select_types(body).unwrap()
  targets[0] = @lib.LabelIdx::new(1U)
  types[0] = @lib.ValType::i64()
  for instr in body {
    match instr {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) => {
        child.push(@lib.Instruction::nop())
        break
      }
      _ => ()
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Admission is checked only after the owned output vectors were mutated.
  dae2_sparse_incoming_compare(input)
}

///|
test "DAE2 bounded two-write exits preserve exact HOT rewrite and demanded local sources" {
  dae2_sparse_incoming_compare(dae2_sparse_exit_fixture(4, 4, 2))
}
