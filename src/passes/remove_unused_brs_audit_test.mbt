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

///|
#skip
test "audit remove unused brs does not skip a removable branch in constructor ladder" {
  let wat = perf_test_make_nested_constructor_hot_skip_module().replace(
    old="           br 0\n         end\n         unreachable",
    new="           block br 0 end\n         end\n         unreachable",
  )
  let input = pass_test_module_from_wat(wat)
  let before = audit_count(audit_body(input, index=6), fn(i) { i is @lib.Br(_) })
  assert_true(before > 0)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "remove-unused-brs",
  ]).unwrap()
  let after = audit_count(audit_body(output, index=6), fn(i) { i is @lib.Br(_) })
  assert_true(after < before, msg="before=\{before} after=\{after}")
}
