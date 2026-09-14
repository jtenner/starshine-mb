///|
test "fourth audit dae optimizing nullable parameter with function import" {
  let output = audit_run(
    "(module (import \"m\" \"f\" (func)) (func $f (param externref i32) (result i32) local.get 0 ref.is_null) (func (export \"nonnull\") (param (ref extern)) (result i32) i32.const 0) (func (export \"run\") (param externref) (result i32) local.get 0 i32.const 99 call $f))",
    "dae-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.RefIsNull }),
    1,
  )
}
