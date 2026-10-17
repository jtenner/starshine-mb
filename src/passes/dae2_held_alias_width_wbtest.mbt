///|
test "DAE2 held alias retirement preserves final index bounds for reverse copies" {
  // The held copy at slot 1 disappears. The later copy at slot 128 therefore
  // becomes a one-byte index, while its source stays at a two-byte index.
  // Treating slot 1 as fixed would admit twenty size-losing forwarded reads.
  let setup = Array::makei(126, fn(offset) {
    let index = offset + 2
    "i32.const 1 local.set \{index} i32.const 2 local.set \{index} local.get \{index} call $consume"
  }).join(" ")
  let locals = Array::make(130, "i32").join(" ")
  let reads = Array::make(20, "local.get 128 call $consume").join(" ")
  let fixture = fn(packet) {
    pass_test_module_from_wat(
      "(module (import \"e\" \"consume\" (func $consume (param i32))) (func (export \"run\") (param i32) (local \{locals}) \{setup} \{packet} local.get 1 call $consume local.get 129 call $consume local.get 1 call $consume local.get 129 call $consume local.get 130 local.set 128 \{reads}))",
    )
  }
  let input = fixture("local.get 0 local.get 2 local.set 129 local.set 1")
  // Reading the immutable parameter after the other local copy gives the
  // same values and effects. Its adjacent alias was already in the proof.
  let flat = fixture("local.get 2 local.set 129 local.get 0 local.set 1")
  @validate.validate_module(input).unwrap()
  @validate.validate_module(flat).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_cleanup_captures(input)
  let reference = dae2_cleanup_captures(flat)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  let @lib.Func(output_locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(output_locals.length(), 129)
  assert_eq(
    body
    .filter(fn(instr) { instr is @lib.LocalGet(@lib.LocalIdx(127U)) })
    .length(),
    20,
  )
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), 150)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
