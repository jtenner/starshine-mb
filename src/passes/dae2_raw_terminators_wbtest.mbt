///|
test "DAE2 raw terminators preserve nested return and trap boundaries" {
  for
    body in [
      "local.get 0 if local.get 1 return end local.get 2", "local.get 0 if (result i32) local.get 1 return else local.get 2 end",
      "local.get 0 if (result i32) local.get 1 return else local.get 2 return end",
      "block (result i32) local.get 0 if local.get 1 return end local.get 2 end",
      "local.get 0 if (result i32) unreachable else local.get 1 end", "local.get 0 if (result i32) local.get 1 else unreachable end",
      "local.get 0 if (result i32) unreachable else local.get 1 return end", "local.get 1 local.get 0 if (result i32) local.get 2 return else local.get 2 end i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let lifts = [0]
    ignore(
      dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap(),
    )
    assert_eq(lifts[0], 0)
  }
}

///|
test "DAE2 raw terminators keep only reaching fallthrough writes" {
  for
    body in [
      "local.get 0 if local.get 1 local.set 4 local.get 2 return else local.get 2 local.set 4 end local.get 4",
      "local.get 0 if local.get 1 local.set 4 unreachable else local.get 2 local.set 4 end local.get 4",
      "local.get 0 if local.get 2 local.set 4 else local.get 1 local.set 4 unreachable end local.get 4",
      "local.get 0 if local.get 1 return end local.get 2 local.set 4 local.get 4",
      "local.get 1 local.set 4 local.get 0 if local.get 2 local.set 4 local.get 2 return end local.get 4",
      "local.get 0 if local.get 1 if local.get 2 return end local.get 2 local.set 4 else unreachable end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw terminators preserve unused return demand effects and tuple payloads" {
  for
    wat in [
      "(module (func $h (param i32 i32 i64 f64) (result i64 f64) local.get 0 if local.get 2 local.get 3 return end local.get 2 local.get 3) (func (export \"run\") (param i32 i64 f64) (result i64 f64) local.get 0 i32.const 9 local.get 1 local.get 2 call $h))",
      "(module (func $h (param i32 externref i64) (result externref) local.get 0 if unreachable end local.get 1) (func (export \"run\") (param i32 externref) (result externref) local.get 0 local.get 1 i64.const 9 call $h))",
    ] {
    raw_conditional_compare_boundaries(pass_test_module_from_wat(wat), 2)
  }
}

///|
test "DAE2 raw terminators intentionally retain HOT for materialized dead tails" {
  // HOT can materialize concrete instructions after a terminator. This first
  // raw extension declines those tails instead of dropping their dependencies.
  for
    body in [
      "local.get 0 if local.get 1 return local.get 2 drop end local.get 2", "local.get 0 if unreachable local.get 1 i32.load drop end local.get 2",
      "local.get 0 if unreachable else unreachable end local.get 1", "local.get 0 if (result i32) local.get 1 unreachable else local.get 2 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32 i32 i64) (result i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 1)
  }
}

///|
test "DAE2 raw unused load return saves only the redundant HOT void block" {
  // Shape contract: docs/wiki/binaryen/passes/dae2/wat-shapes.md.
  // Verified v133 canonical/downstream bytes and bounded Node trap replay show
  // a three-byte direct win; only this exact unused block differs from HOT.
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func $h (param i32 i32 i32 i64) (result i32) local.get 0 if local.get 1 i32.load return end local.get 2) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h drop))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let expected_raw = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32) local.get 0 if local.get 1 i32.load drop return end) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 call $h))",
    ).code_sec.unwrap().0
  let expected_hot = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32) local.get 0 if block local.get 1 i32.load drop return end end) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 call $h))",
    ).code_sec.unwrap().0
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (raw_bits, raw_count) = raw_conditional_boundary_bits(
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
    assert_eq(raw_bits, hot_bits)
    assert_eq(raw_count, 2)
    // The journal includes two functions and two synthetic type-family infos.
    assert_eq(raw_writes.length(), 4)
    assert_eq(raw_writes, hot_writes)
    let output = dae2_run_module_pass(input, closed_world).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_conditionals=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    @validate.validate_module(reference).unwrap()
    let raw_funcs = output.code_sec.unwrap().0
    let hot_funcs = reference.code_sec.unwrap().0
    assert_eq(raw_funcs.length(), 2)
    assert_eq(hot_funcs.length(), 2)
    // Assert both exact instruction forms before projecting any body.
    assert_eq(raw_funcs[0], expected_raw[0])
    assert_eq(hot_funcs[0], expected_hot[0])
    assert_eq(raw_funcs[1], expected_raw[1])
    assert_eq(hot_funcs[1], expected_hot[1])
    for funcs in [raw_funcs, hot_funcs] {
      for func in funcs {
        let @lib.Func(locals, _) = func
        assert_eq(locals.run_count(), 0)
      }
    }
    for mod_ in [output, reference] {
      let context = @ir.hot_module_context_from_module(mod_)
      assert_eq(
        @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
        Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
      )
      assert_eq(
        @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
        Some(
          @lib.FuncType::new(
            [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
            [],
          ),
        ),
      )
    }
    let raw_bytes = @binary.encode_module(output).unwrap()
    let hot_bytes = @binary.encode_module(reference).unwrap()
    assert_eq(raw_bytes.length() + 3, hot_bytes.length())
    // Copy only the reference code array and replace only the proven h body.
    // All remaining instructions, signatures, sections and metadata must match.
    let projected_funcs = hot_funcs.copy()
    let @lib.Func(reference_locals, _) = hot_funcs[0]
    let @lib.Func(_, @lib.Expr(raw_body)) = raw_funcs[0]
    projected_funcs[0] = @lib.Func::new(
      reference_locals,
      @lib.Expr::new(raw_body.copy()),
    )
    let projected = reference.with_code_sec(@lib.CodeSec::new(projected_funcs))
    assert_eq(@binary.encode_module(projected).unwrap(), raw_bytes)
    assert_eq(@binary.encode_module(reference).unwrap(), hot_bytes)
    assert_eq(@binary.encode_module(output).unwrap(), raw_bytes)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
