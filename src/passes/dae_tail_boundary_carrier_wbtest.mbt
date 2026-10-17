///|
fn dae_tail_carrier_fixture(width : Int32, mode : Int32) -> @lib.Module {
  let prefix = Array::make(width, "local.get 0 call 0 drop").join(" ")
  let tail = match mode {
    0 => "local.get 0 call 0"
    1 => "local.get 0 return_call 0"
    2 => "local.get 0 i32.const 0 return_call_indirect (type $target)"
    3 =>
      "local.get 0 return_call 0 local.get 0 i32.const 0 return_call_indirect (type $target)"
    4 =>
      "local.get 0 return_call 0 local.get 0 ref.func 0 return_call_ref $target"
    _ => abort("unknown tail carrier mode")
  }
  pass_test_module_from_wat(
    "(module (type $target (func (param i32) (result i32))) (import \"env\" \"target\" (func (type $target))) (table 1 funcref) (elem (i32.const 0) func 0) (func (export \"run\") (param i32) (result i32) \{prefix} \{tail}))",
  )
}

///|
fn dae_tail_carrier_flags(
  evidence : DaeTailCallBoundaryEvidence,
) -> Array[Bool] {
  [
    evidence.has_direct_tail_call,
    evidence.has_indirect_tail_call,
    evidence.blocks_direct_call_rewrite,
    evidence.blocks_result_removal,
  ]
}

///|
fn dae_tail_carrier_expected(mode : Int32) -> Array[Bool] {
  match mode {
    0 => [false, false, false, false]
    1 => [true, false, false, true]
    2 => [false, true, true, true]
    3 | 4 => [true, true, true, true]
    _ => abort("unknown tail carrier mode")
  }
}

///|
test "tail boundary carrier preserves all syntactic flags including inactive tails" {
  for mode in 0..<5 {
    let input = dae_tail_carrier_fixture(2, mode)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let funcs = input.code_sec.unwrap().0
    let @lib.Func(_, @lib.Expr(body)) = funcs[0]
    assert_eq(
      dae_tail_carrier_flags(dae_tail_call_boundary_evidence_instrs(body)),
      dae_tail_carrier_expected(mode),
    )
    assert_eq(
      dae_tail_carrier_flags(dae_tail_call_boundary_evidence(funcs)),
      dae_tail_carrier_expected(mode),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "tail boundary carrier preserves Block Loop If and exception region flags" {
  let direct = dae_tail_carrier_fixture(0, 1)
  let indirect = dae_tail_carrier_fixture(0, 2)
  let @lib.Func(locals, @lib.Expr(direct_body)) = direct.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(indirect_body)) = indirect.code_sec.unwrap().0[0]
  let result_type = @lib.BlockType::val_type(@lib.ValType::i32())
  let mixed = dae_tail_carrier_fixture(0, 3)
  let @lib.Func(_, @lib.Expr(mixed_body)) = mixed.code_sec.unwrap().0[0]
  let bodies = [
    [@lib.Instruction::block(result_type, @lib.Expr::new(mixed_body))],
    [@lib.Instruction::loop_(result_type, @lib.Expr::new(mixed_body))],
    [@lib.Instruction::try_table(result_type, [], @lib.Expr::new(mixed_body))],
    [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(result_type, direct_body, Some(indirect_body)),
    ],
    [
      @lib.Instruction::try_(result_type, @lib.Expr::new(direct_body), [
        @lib.LegacyCatch::all(@lib.Expr::new(indirect_body)),
      ]),
    ],
  ]
  for body in bodies {
    let input = direct.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    assert_eq(
      dae_tail_carrier_flags(
        dae_tail_call_boundary_evidence(input.code_sec.unwrap().0),
      ),
      [true, true, true, true],
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
fn dae_tail_carrier_batch_fixture(
  rewritten : Bool,
  dead_indirect~ : Bool = false,
) -> @lib.Module {
  let target = if rewritten {
    "(result i32) i32.const 11"
  } else {
    "(param i32) (result i32) i32.const 11"
  }
  let argument = if rewritten { "" } else { "i32.const 7" }
  let indirect_type = if dead_indirect {
    "(type $indirect (func (param i32) (result i32)))"
  } else {
    ""
  }
  let table = if dead_indirect { "(table 1 funcref)" } else { "" }
  let dead = if dead_indirect {
    "(func (param i32) (result i32) i32.const 0 return local.get 0 i32.const 0 return_call_indirect (type $indirect))"
  } else {
    ""
  }
  let padding = Array::make(if dead_indirect { 28 } else { 29 }, "(func)").join(
    " ",
  )
  pass_test_module_from_wat(
    "(module (type $loop (func (param i32))) \{indirect_type} (import \"env\" \"effect\" (func (param i32))) \{table} (func $target \{target}) (func (export \"run\") (result i32) (local i32) i32.const 9 call 0 \{argument} call $target local.set 0 i32.const 10 call 0 local.get 0) (func i32.const 0 loop (type $loop) drop end) \{dead} \{padding})",
  )
}

///|
test "tail boundary carrier keeps real typed batch bytes effects and changed body ownership" {
  for pass_name in ["dae", "dae-optimizing"] {
    let input = dae_tail_carrier_batch_fixture(false)
    let expected = dae_tail_carrier_batch_fixture(true).without_name_sec()
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(output.code_sec, expected.code_sec)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(expected).unwrap(),
    )
    let @lib.Func(_, @lib.Expr(source)) = input.code_sec.unwrap().0[1]
    let @lib.Func(_, @lib.Expr(owned)) = output.code_sec.unwrap().0[1]
    assert_false(physical_equal(source, owned))
    owned.push(@lib.Instruction::nop())
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "tail boundary carrier keeps inactive indirect tail batch rejection" {
  for pass_name in ["dae", "dae-optimizing"] {
    let input = dae_tail_carrier_batch_fixture(false, dead_indirect=true)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    assert_eq(
      dae_tail_carrier_flags(
        dae_tail_call_boundary_evidence(input.code_sec.unwrap().0),
      ),
      [false, true, true, true],
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(output.code_sec, input.code_sec)
    assert_eq(@binary.encode_module(output).unwrap(), saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
