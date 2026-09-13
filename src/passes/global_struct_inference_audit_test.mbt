///|
test "audit global struct inference includes mutable global origins" {
  let wat =
    #|(module (type $s (struct (field i32)))
    #|(global $a (ref $s) (struct.new $s (i32.const 1)))
    #|(global $b (mut (ref $s)) (struct.new $s (i32.const 2)))
    #|(func $read (param (ref $s)) (result i32) local.get 0 struct.get $s 0)
    #|(func (export "run") (result i32) global.get $b call $read))
  let output = try! gsi_test_run(wat, true)
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructGet(_, _) }),
    1,
  )
}
