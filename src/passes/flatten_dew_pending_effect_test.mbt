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
