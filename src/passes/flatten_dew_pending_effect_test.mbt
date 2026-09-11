///|
test "flatten keeps a carried call before a later global store" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (global (mut i32) (i32.const 0))
      #| (func $write (result i32)
      #|   i32.const 1 global.set 0 i32.const 7)
      #| (func (export "run") (result i32)
      #|   call $write i32.const 2 global.set 0 drop global.get 0))
    ),
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  let mut call_at = -1
  let mut store_at = -1
  for index, instr in body {
    match instr {
      @lib.Call(_) => call_at = index
      @lib.GlobalSet(_) => store_at = index
      _ => ()
    }
  }
  assert_true(call_at >= 0 && call_at < store_at, msg=body.to_string())
  assert_true(output.code_sec != input.code_sec)
}

///|
test "flatten preserves source order when spilling a cast before a local write" {
  // Two casts feed local 1. A later cast reads local 1 for a field access.
  // Spilling the first cast must not give it a position after that later read.
  let input = @binary.decode_module(
    b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x0a\x02\x5f\x01\x7f\x00\x60\x01\x6d\x01\x7f\x03\x02\x01\x01\x0a\x1d\x01\x1b\x01\x01\x64\x00\x20\x00\xfb\x16\x00\xfb\x16\x00\x21\x01\x20\x01\xfb\x16\x00\xfb\x02\x00\x00\x1a\x41\x2a\x0b\x00\x0d\x04\x6e\x61\x6d\x65\x04\x06\x01\x00\x03\x62\x6f\x78",
  ).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["flatten"]).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  assert_true(input.code_sec != output.code_sec)
}
