///|
fn dae2_single_exit_fixture(depth : Int32, width : Int32) -> @lib.Module {
  let body = StringBuilder::new()
  // A forward branch selects the forward planner instead of the branchless one.
  body.write_string("block local.get 0 br_if 0 ")
  for _ in 0..<depth {
    body.write_string("block ")
  }
  for local in 4..<(4 + width) {
    body.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<depth {
    body.write_string("end ")
  }
  body.write_string("end local.get 4")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{Array::make(width, "i32").join(" ")}) \{body.to_string()}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
#skip("dedicated nested-state work-budget regression; include-skipped")
test "DAE2 single-exit nesting stays raw within the unchanged work budget" {
  let input = dae2_single_exit_fixture(12, 16)
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
    let (reference_bits, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(bits, reference_bits)
    assert_eq(raw_writes, hot_writes)
    let lifts = [0]
    let output = dae2_run_module_pass(
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
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(admitted, 2)
    assert_eq(lifts[0], 0)
  }
}

///|
test "DAE2 single exits preserve enclosing joins loop writes and scalar results" {
  for
    body in [
      "block $out local.get 0 br_if $out block local.get 1 local.set 4 local.get 2 local.set 4 end end local.get 4",
      "block $out block local.get 1 local.set 4 local.get 0 br_if $out local.get 2 local.set 4 end end local.get 4",
      "local.get 0 if block local.get 1 local.set 4 end else block local.get 2 local.set 4 end end block local.get 0 br_if 0 end local.get 4",
      "local.get 1 local.set 4 loop $again block local.get 4 i32.const 1 i32.sub local.set 4 end local.get 4 br_if $again end local.get 4",
      "block $out loop $again block local.get 1 local.set 4 end local.get 0 br_if $out local.get 2 local.set 4 local.get 4 br_if $again end end local.get 4",
      "block (result i32) block local.get 0 br_if 0 end local.get 1 end", "block $out local.get 0 if block local.get 1 local.set 4 br $out end else block local.get 2 local.set 4 end end end local.get 4",
      "block local.get 0 if local.get 1 return end block local.get 2 local.set 4 end end local.get 4",
    ] {
    let input = dae2_first_input_fixture(body)
    raw_conditional_compare_boundaries(input, 2)
    let saved = @binary.encode_module(input).unwrap()
    for closed_world in [false, true] {
      let plain = dae2_run_module_pass(input, closed_world).unwrap()
      let expected = dae2_cleanup_captures(
        run_hot_pipeline(plain, HotPipelineOptions::new(closed_world~), [
          "simplify-locals", "vacuum",
        ]).unwrap(),
      )
      let actual = run_hot_pipeline(
        input,
        HotPipelineOptions::new(closed_world~),
        ["dae2-optimizing"],
      ).unwrap()
      @validate.validate_module(actual).unwrap()
      assert_eq(
        @binary.encode_module(actual).unwrap(),
        @binary.encode_module(expected).unwrap(),
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
#skip("dedicated demand-driven local-flow work-budget regression; include-skipped")
test "DAE2 nested local joins stay raw without eager state transport" {
  let body = StringBuilder::new()
  body.write_string("block local.get 0 br_if 0 end ")
  for _ in 0..<12 {
    body.write_string("local.get 0 if else ")
  }
  for local in 4..<20 {
    body.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<12 {
    body.write_string("end ")
  }
  body.write_string("local.get 4 ")
  for local in 5..<20 {
    body.write_string("local.get \{local} i32.add ")
  }
  raw_conditional_compare_boundaries(
    dae2_first_input_fixture(body.to_string(), locals=16),
    2,
  )
}
