///|
test "deep audit simplify globals resolves signatures after multi member recursive groups" {
  let output = audit_run(
    (
      #|(module (rec (type (func)) (type (func (param i64))))
      #| (type $host (func (param i32) (result i32 i32)))
      #| (type (func (result i32)))
      #| (import "env" "host" (func $host (type $host)))
      #| (global $g (mut i32) (i32.const 0))
      #| (func (export "run") global.get $g call $host i32.const 0 select
      #| if i32.const 1 global.set $g end))
    ),
    "simplify-globals-optimizing",
  )
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.GlobalSet(_) }),
    1,
  )
}
