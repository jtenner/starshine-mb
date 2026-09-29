///|
test "DAE2 raw observed producers preserve exact HOT rewriting without an initial arena" {
  for
    wat in [
      "(module (memory 1) (func $h (param i32 i32) (result i32) local.get 0 i32.load) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $h))",
      "(module (func $h (param i32 i32 i32) (result i32) local.get 0 local.get 1 i32.div_s) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 9 call $h))",
      "(module (func $h (param f64 i32) (result i32) local.get 0 i32.trunc_f64_s) (func (export \"run\") (param f64) (result i32) local.get 0 i32.const 9 call $h))",
      "(module (type $s (struct (field i32))) (func $h (param i32 i32) (result i32) local.get 0 struct.new $s struct.get $s 0) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $h))",
      "(module (func $h (param i32 i32) (result i32) local.get 0 ref.i31 i31.get_s) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 9 call $h))",
      "(module (type $s (struct (field i32))) (func $h (param i32) (result i32) struct.new_default $s ref.as_non_null struct.get $s 0) (func (export \"run\") (result i32) i32.const 9 call $h))",
      "(module (table 1 funcref) (func $h (param i32 i32) local.get 0 table.get 0 drop local.get 1 drop) (func (export \"run\") (param i32) local.get 0 i32.const 9 call $h))",
      "(module (memory 1) (func $h (param i32 i32) local.get 0 memory.grow drop local.get 1 drop) (func (export \"run\") (param i32) local.get 0 i32.const 9 call $h))",
      "(module (type $s (struct (field i32))) (func $h (param i32 i32) local.get 0 struct.new $s ref.null $s ref.eq drop local.get 1 drop) (func (export \"run\") (param i32) local.get 0 i32.const 9 call $h))",
    ] {
    let input = match
      @wast.wast_to_binary_module(wat, filename="raw-producers.wat") {
      Ok(input) => input
      Err(error) => fail("raw producer fixture \{wat}: \{error}")
    }
    let saved = @binary.encode_module(input).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(lifts[0], 0)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 raw array allocation and length dependencies use direct opcodes" {
  for kind in 0..<3 {
    let input = pass_test_module_from_wat(
      "(module (type $a (array i32)) (func $h (param i32 i32 i32) (result i32) i32.const 0) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 9 call $h))",
    )
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    body.clear()
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    if kind != 0 {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    }
    body.push(
      if kind == 0 {
        @lib.Instruction::array_new_default(@lib.TypeIdx::new(0U))
      } else if kind == 1 {
        @lib.Instruction::array_new(@lib.TypeIdx::new(0U))
      } else {
        @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(2U))
      },
    )
    // The text reader lacks these access names; exercise binary/IR opcodes.
    if kind == 1 {
      body.push(@lib.Instruction::i32_const(@lib.I32(0)))
      body.push(@lib.Instruction::array_get(@lib.TypeIdx::new(0U)))
    } else {
      body.push(@lib.Instruction::array_len())
    }
    @validate.validate_module(input).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(lifts[0], 0)
    @validate.validate_module(output).unwrap()
  }
}

///|
test "DAE2 raw observed producers keep trap operands live when their result is dropped" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func $h (param i32 i32 i32) local.get 0 i32.load drop i32.const 8 local.get 1 i32.div_s drop local.get 2 drop) (func (export \"run\") (param i32 i32) local.get 0 local.get 1 i32.const 9 call $h))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
  )
  assert_eq(lifts[0], 0)
}
