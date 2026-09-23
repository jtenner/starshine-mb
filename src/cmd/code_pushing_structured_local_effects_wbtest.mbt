///|
test "command code-pushing keeps legacy-EH set before nested structured local read" {
  let output = cmd_deep_audit_run(
    (
      #|(module
      #|  (tag $e (param i32))
      #|  (global $seen (export "seen") (mut i32) (i32.const 0))
      #|  (func (export "f") (param $cond i32) (result i32) (local $value i32)
      #|    (block $out
      #|      (local.set $value (i32.const 7))
      #|      (try
      #|        (do (throw $e (i32.const 0)))
      #|        (catch_all))
      #|      (block
      #|        (global.set $seen (local.get $value)))
      #|      nop
      #|      (br_if $out (local.get $cond))
      #|      (drop (local.get $value)))
      #|    (global.get $seen)))
      #|
    ),
    "code-pushing",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  let body = match cmd_deep_audit_body(output)[0] {
    @lib.Block(_, @lib.Expr(body)) => body
    other => fail("expected outer block, got \{other}")
  }
  let mut set_idx = -1
  let mut block_idx = -1
  for idx = 0; idx < body.length(); idx = idx + 1 {
    match body[idx] {
      @lib.LocalSet(@lib.LocalIdx(1U)) => set_idx = idx
      @lib.Block(_, _) => block_idx = idx
      _ => ()
    }
  }
  assert_true(
    set_idx >= 0 && block_idx >= 0 && set_idx < block_idx,
    msg=body.to_string(),
  )
}
