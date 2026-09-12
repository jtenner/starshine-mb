///|
test "vacuum preserves return that discards ambient stack values" {
  let wat =
    #|(module
    #|  (func (export "main") (param i32 i64) (result i32)
    #|    local.get 0 local.get 1 i32.const 42 return))
  for passes in [["vacuum"], ["optimize"]] {
    let optimized = pass_test_run_pipeline(
      wat,
      passes,
      options=HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ).unwrap()
    @validate.validate_module(o4z_canonicalize_final_size_candidate(optimized)).unwrap()
  }
}

///|
test "vacuum preserves stack unwinding around a constructor result call" {
  let wat =
    #|(module
    #|  (func $read (param i32) (result i32) local.get 0)
    #|  (func (export "main") (param i32 i64) (result i32) (local i32)
    #|    local.get 0 local.get 1 i32.const 42 call $read
    #|    return local.set 2 i32.const 0))
  let optimized = pass_test_run_pipeline(wat, ["vacuum"]).unwrap()
  @validate.validate_module(o4z_canonicalize_final_size_candidate(optimized)).unwrap()
}

///|
test "vacuum still removes final return with exactly the function results" {
  let wat = "(module (func (export \"main\") (result i32) i32.const 42 return))"
  let optimized = o4z_canonicalize_final_size_candidate(
    pass_test_run_pipeline(wat, ["vacuum"]).unwrap(),
  )
  @validate.validate_module(optimized).unwrap()
  let body = match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => fail("expected one function after vacuum")
  }
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(42))])
}

///|
test "vacuum preserves a carried struct read before a region tail write" {
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x10\x03\x5f\x01\x7f\x01\x60\x02\x64\x00\x7f\x01\x7f\x60\x00\x01\x7f\x03\x03\x02\x01\x02\x07\x08\x01\x04\x6d\x61\x69\x6e\x00\x01\x0a\x26\x02\x18\x00\x20\x01\x04\x7f\x00\x05\x20\x00\xfb\x02\x00\x00\x20\x00\x41\x09\xfb\x05\x00\x00\x01\x0b\x0b\x0b\x00\x41\x07\xfb\x00\x00\x41\x00\x10\x00\x0b\x00\x27\x04\x6e\x61\x6d\x65\x01\x07\x01\x00\x04\x72\x65\x61\x64\x02\x11\x01\x00\x02\x00\x01\x70\x01\x09\x63\x6f\x6e\x64\x69\x74\x69\x6f\x6e\x04\x04\x01\x00\x01\x73",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let events : Array[String] = []
  fn visit(body : Array[@lib.Instruction]) -> Unit {
    for instruction in body {
      match instruction {
        @lib.StructGet(_, _) => events.push("read")
        @lib.StructSet(_, _) => events.push("write")
        @lib.If(_, yes, no) => {
          visit(yes)
          if no is Some(other) {
            visit(other)
          }
        }
        _ => ()
      }
    }
  }
  visit(body)
  @debug.assert_eq(events, ["read", "write"])
}
