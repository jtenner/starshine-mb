///|
fn tuple_nested_overlap_cmd_source() -> String {
  "(module (type $pair (func (result i32 i32))) " +
  "(func (export \"run\") (result i32) " +
  "(local $saved i32) (local $a i32) (local $b i32) (local $out i32) " +
  "loop block (type $pair) i32.const 11 i32.const 100 end " +
  "local.set $b local.set $a " +
  "block (type $pair) local.get $a local.get $b end " +
  "local.set $b local.set $a " +
  "i32.const 1 if local.get $a local.set $saved end " +
  "block (type $pair) local.get $saved local.get $b end " +
  "local.set $out local.set $b end " +
  "local.get $b local.get $out i32.add))"
}

///|
test "tuple dispatcher preserves nested overlapping self-copy values in encoded output" {
  let input = @passes.pass_test_module_from_wat(
    tuple_nested_overlap_cmd_source(),
  )
  @debug.assert_eq(tuple_alias_cmd_execute(input.code_sec.unwrap().0[0]), 111)
  for
    passes in [
      ["tuple-optimization"],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = optimize_module_with_pass_flags(
      input,
      passes,
      OptimizeOptions::new(),
    ).unwrap()
    let decoded = decode_module_bytes(encode_module_bytes(output))
    ignore(@validate.validate_module(decoded).unwrap())
    @debug.assert_eq(
      tuple_alias_cmd_execute(decoded.code_sec.unwrap().0[0]),
      111,
    )
  }
}
