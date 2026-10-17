///|
fn raw_literal_prefix_compare(
  input : @lib.Module,
  prefix : Array[@lib.Instruction],
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_conditionals=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = actual.code_sec.unwrap().0[0]
    for index in 0..<prefix.length() {
      assert_eq(body[index], prefix[index])
    }
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw replay keeps a leading literal below a void If condition" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) i32.const 0 local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end local.get 4 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  raw_literal_prefix_compare(input, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "DAE2 raw replay keeps literal order with a scalar typed If result" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) i32.const 0 local.get 0 if (result i32) local.get 1 else local.get 2 end i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  raw_literal_prefix_compare(input, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "DAE2 raw replay keeps a held load and literal below a void If condition" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func $h (param i32 i32 i32 i64) (result i32) (local i32) local.get 1 i32.load i32.const 0 local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end local.get 4 i32.add i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0[0]
  raw_literal_prefix_compare(input, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    original[1],
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "DAE2 raw replay keeps effectful calls inside their source If arms" {
  let input = pass_test_module_from_wat(
    "(module (import \"e\" \"observe\" (func $observe (param i32))) (func $h (param i32 i32 i32 i64) (result i32) (local i32) i32.const 0 local.get 0 if local.get 1 call $observe local.get 1 local.set 4 else local.get 2 call $observe local.get 2 local.set 4 end local.get 4 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  raw_literal_prefix_compare(input, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}
