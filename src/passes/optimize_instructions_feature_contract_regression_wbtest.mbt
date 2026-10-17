///|
fn feature_fill_module(payload : Bytes) -> @lib.Module {
  pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) local.get 0 i32.const 171 i32.const 16 memory.fill))",
  ).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("target_features"), payload),
  ])
}

///|
fn feature_fill_assert_no_simd(payload : Bytes) -> Unit raise {
  let input = feature_fill_module(payload)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(
    body.any(fn(instr) {
      match instr {
        @lib.V128Const(_) | @lib.V128Store(_) => true
        _ => false
      }
    }),
    msg="a target feature ban must prevent new SIMD instructions",
  )
  assert_eq(output.custom_secs, input.custom_secs)
}

///|
test "tiny memory fill respects an explicit SIMD target feature ban" {
  feature_fill_assert_no_simd(b"\x01\x2d\x07simd128")
}

///|
test "tiny memory fill respects SIMD bans across repeated feature sections" {
  let input = feature_fill_module(b"\x01\x2b\x07simd128").with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      b"\x01\x2b\x07simd128",
    ),
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      b"\x01\x2d\x07simd128",
    ),
  ])
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_false(
    body.any(fn(instr) {
      match instr {
        @lib.V128Const(_) | @lib.V128Store(_) => true
        _ => false
      }
    }),
  )
}

///|
test "malformed target feature metadata cannot permit a new SIMD fill store" {
  // These payloads deliberately violate target_features encoding. Restricting
  // feature introduction is the intentional fail-closed metadata contract.
  for payload in [b"", b"\x01\x2b", b"\x01\x3f\x07simd128", b"\x00\xff"] {
    feature_fill_assert_no_simd(payload)
  }
}

///|
test "a SIMD ban preserves permitted scalar tiny fill lowering" {
  let input = pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) local.get 0 i32.const 171 i32.const 1 memory.fill local.get 0 i32.const 171 i32.const 2 memory.fill local.get 0 i32.const 171 i32.const 4 memory.fill local.get 0 i32.const 171 i32.const 8 memory.fill))",
  ).with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      b"\x01\x2d\x07simd128",
    ),
  ])
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut stores = 0
  for instr in body {
    match instr {
      @lib.I32Store8(_)
      | @lib.I32Store16(_)
      | @lib.I32Store(_)
      | @lib.I64Store(_) => stores += 1
      @lib.MemoryFill(_) | @lib.V128Store(_) =>
        fail("scalar tiny fills must use permitted scalar stores")
      _ => ()
    }
  }
  assert_eq(stores, 4)
}
