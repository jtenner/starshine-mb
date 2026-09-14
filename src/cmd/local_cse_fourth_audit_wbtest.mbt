///|
test "fourth audit command local cse preserves interleaved global write" {
  let output = cmd_deep_audit_run(
    "(module (global (export \"g\") (mut i32) (i32.const 0)) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 99 global.set 0 i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.GlobalSet(_)
    }),
    1,
  )
}

///|
test "fourth audit command local cse preserves interleaved store" {
  let output = cmd_deep_audit_run(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 i32.const 0 i32.const 99 i32.store i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.I32Store(_)
    }),
    1,
  )
}

///|
test "fourth audit command local cse preserves interleaved call" {
  let output = cmd_deep_audit_run(
    "(module (import \"env\" \"effect\" (func)) (func (param i32) (result i32) local.get 0 i32.const 1 i32.add drop local.get 0 call 0 i32.const 1 i32.add))",
    "local-cse",
  )
  @debug.assert_eq(
    cmd_deep_audit_count(cmd_deep_audit_body(output), fn(i) {
      i is @lib.Call(_)
    }),
    1,
  )
}
