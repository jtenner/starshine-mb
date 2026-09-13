///|
test "audit remove unused brs preserves signed zero branch results" {
  let wat =
    #|(module (func (param i32) (result i32)
    #| block (result f32)
    #| f32.const 0 local.get 0 br_if 0 drop f32.const -0 end
    #| i32.reinterpret_f32))
  let output = audit_run(wat, "remove-unused-brs")
  let func = output.code_sec.unwrap().0[0]
  @debug.assert_eq(try! scalar_fixture_run(func, [0L]), [-2147483648L])
  @debug.assert_eq(try! scalar_fixture_run(func, [1L]), [0L])
}

///|
test "audit remove unused brs preserves imported tag alias priority" {
  let wat =
    #|(module
    #| (import "env" "a" (tag $a)) (import "env" "b" (tag $b))
    #| (func (result i32)
    #| block $first
    #|  block $second
    #|   try_table (catch $a $first) (catch $b $second) throw $b end
    #|  end
    #|  i32.const 2 return
    #| end i32.const 1))
  let output = audit_run(wat, "remove-unused-brs")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Throw(_) }),
    1,
  )
}
