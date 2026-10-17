///|
fn dae2_constant_packet_compare(
  input : @lib.Module,
  flat : @lib.Module,
  remaining : Int32,
  calls : Int32,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  @validate.validate_module(flat).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let flat_saved = @binary.encode_module(flat).unwrap()
  let output = dae2_cleanup_captures(input)
  let expected = dae2_cleanup_captures(flat)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(expected).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(expected).unwrap(),
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(locals.length(), remaining)
  assert_eq(body.filter(fn(instr) { instr is @lib.Call(_) }).length(), calls)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(@binary.encode_module(flat).unwrap(), flat_saved)
}

///|
test "DAE2 held aliases pass through independent constant local copies" {
  for
    (type_, constant) in [
      ("i32", "i32.const 0"),
      ("i64", "i64.const 0"),
      ("f64", "f64.const 0"),
      ("externref", "ref.null extern"),
    ] {
    let fixture = fn(packet) {
      pass_test_module_from_wat(
        "(module (import \"e\" \"pointer\" (func $pointer (param i32))) (import \"e\" \"other\" (func $other (param \{type_}))) (func (export \"run\") (param i32) (local \{type_} i32) \{packet} local.get 2 call $pointer local.get 1 call $other local.get 2 call $pointer local.get 1 call $other))",
      )
    }
    // The parameter is unwritten. Moving only this pure read past the other
    // local assignment gives an independent adjacent-copy reference.
    let input = fixture("local.get 0 \{constant} local.set 1 local.set 2")
    let flat = fixture("\{constant} local.set 1 local.get 0 local.set 2")
    dae2_constant_packet_compare(input, flat, 1, 4)
  }
}

///|
test "DAE2 held aliases preserve dominated single-write local sources" {
  let fixture = fn(packet) {
    pass_test_module_from_wat(
      "(module (import \"e\" \"value\" (func $value (result i32))) (import \"e\" \"consume\" (func $consume (param i32))) (func (export \"run\") (local i32 i32 i32) call $value local.set 0 \{packet} local.get 2 call $consume local.get 1 call $consume local.get 2 call $consume local.get 1 call $consume local.get 0 call $consume))",
    )
  }
  let input = fixture("local.get 0 i32.const 0 local.set 1 local.set 2")
  let flat = fixture("i32.const 0 local.set 1 local.get 0 local.set 2")
  dae2_constant_packet_compare(input, flat, 2, 6)
}
