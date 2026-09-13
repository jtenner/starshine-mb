///|
test "campaign global struct inference distinguishes signed zero" {
  let output = gsi_test_run(
    (
      #|(module (type $s (struct (field f64)))
      #| (global $p (ref $s) (struct.new $s (f64.const 0)))
      #| (global $n (ref $s) (struct.new $s (f64.const -0)))
      #| (func (export "read") (param (ref $s)) (result f64)
      #|  local.get 0 struct.get $s 0))
    ),
    true,
  )
  // Both allocations are possible values of the public parameter; the load
  // cannot collapse to positive zero for the negative-zero allocation.
  assert_true(
    audit_count(audit_body(output), fn(i) {
      match i {
        @lib.StructGet(_, _) => true
        @lib.F64Const(@lib.F64(value)) =>
          value.reinterpret_as_int64() == (-0.0).reinterpret_as_int64()
        _ => false
      }
    }) >
    0,
  )
}
