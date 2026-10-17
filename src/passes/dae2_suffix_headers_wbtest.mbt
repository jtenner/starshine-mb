///|
fn dae2_suffix_headers_compare(input : @lib.Module) -> @lib.Module raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  // Keep HOT analysis here so this test isolates suffix replay and its exact
  // lexical writer-demand provenance from new raw analysis admissions.
  let output = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    rewrite_lifts=Some(lifts),
  ).unwrap()
  let reference_lifts = [0]
  let reference = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
    rewrite_lifts=Some(reference_lifts),
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  // Disabling raw analysis keeps one flat callee/caller on its HOT path.
  // The one structured function must lose its otherwise-required relift.
  assert_eq(
    lifts[0],
    1,
    msg="qualified structured replay still performed a HOT rewrite lift",
  )
  assert_eq(lifts[0] + 1, reference_lifts[0])
  output
}

///|
test "DAE2 suffix replay preserves no-result indexed loop entries and backedge payloads" {
  let input = pass_test_module_from_wat(
    "(module (type $entry (func (param i32))) (global $g (mut i32) (i32.const 0)) (func $sink (param i32 i32) local.get 0 global.set $g) (func (export \"run\") (type $entry) local.get 0 i32.const 3 i32.and loop (type $entry) local.set 0 local.get 0 i32.const 9 call $sink local.get 0 i32.const 1 i32.sub local.tee 0 i32.const 0 i32.gt_s if local.get 0 br 1 end end))",
  )
  let output = dae2_suffix_headers_compare(input)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(
    body.any(fn(instr) { instr is @lib.Loop(@lib.TypeIdxBlockType(_), _) }),
  )
  assert_eq(dae_wb_param_count(output, 0), 1)
}

///|
test "DAE2 suffix replay keeps overwritten numeric parameters in reverse body-local order" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (global $wide (mut i64) (i64.const 0)) (func $h (param i32 i64 f32 f64) i32.const 7 local.set 0 i64.const 8 local.set 1 loop local.get 0 global.set $g local.get 1 global.set $wide end) (func (export \"run\") i32.const 9 i64.const 10 f32.const 11 f64.const 12 call $h))",
  )
  let names = @lib.IndirectNameMap::new([
    @lib.IndirectNameAssoc::new(
      0U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("small")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("wide")),
      ]),
    ),
  ])
  let input = input.with_name_sec(@lib.NameSec::new(local_names=Some(names)))
  let output = dae2_suffix_headers_compare(input)
  assert_eq(dae_wb_param_count(output, 0), 0)
  let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 2)
  assert_eq(locals.get(0), @lib.ValType::i64())
  assert_eq(locals.get(1), @lib.ValType::i32())
  assert_eq(
    output.name_sec.unwrap().local_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("wide")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("small")),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "DAE2 suffix replay removes unread numeric parameter tee writes and declarations" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32) loop i32.const 7 local.tee 0 global.set $g end) (func (export \"run\") i32.const 9 call $h))",
  )
  let output = dae2_suffix_headers_compare(input)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), 0)
  assert_eq(body, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      ]),
    ),
  ])
}

///|
test "DAE2 suffix replay intentionally keeps shrinking indexed result boundaries on HOT" {
  let input = pass_test_module_from_wat(
    "(module (type $entry (func (param i32) (result i32))) (func (export \"pin\") (type $entry) local.get 0) (func $h (param i32 i64) local.get 0 i32.const 3 i32.and loop (type $entry) local.set 0 local.get 0 end drop) (func (export \"run\") (param i32) local.get 0 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    rewrite_lifts=Some(lifts),
  ).unwrap()
  let reference = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_true(lifts[0] > 0)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
