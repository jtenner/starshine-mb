///|
test "audit globals cleanup preserves local writes used outside child scope" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(func (result i32) (local i32)
    #| global.get $g drop
    #| block (result i32) i32.const 1 local.tee 0 drop local.get 0 end
    #| drop local.get 0))
  let output = audit_run(wat, "simplify-globals-optimizing")
  @debug.assert_eq(
    try! scalar_fixture_run(output.code_sec.unwrap().0[0], [], globals=[0L]),
    [1L],
  )
}

///|
test "audit globals cleanup sees nested local reads" {
  let wat =
    #|(module (global $g (mut i32) (i32.const 0))
    #|(func (result i32) (local i32)
    #| global.get $g drop i32.const 1 local.tee 0 drop local.get 0 drop
    #| block (result i32) local.get 0 end))
  let output = audit_run(wat, "simplify-globals-optimizing")
  @debug.assert_eq(
    try! scalar_fixture_run(output.code_sec.unwrap().0[0], [], globals=[0L]),
    [1L],
  )
}

///|
test "audit globals cleanup retains meaningful early return" {
  let wat =
    #|(module (memory 1)
    #|(global $dummy (mut i32) (i32.const 0))
    #|(global $out (export "out") (mut i32) (i32.const 0))
    #|(func (export "run") global.get $dummy drop
    #| i32.const 1 memory.size i32.eq if return end i32.const 0 drop
    #| i32.const 7 global.set $out))
  let output = audit_run(wat, "simplify-globals-optimizing")
  @debug.assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.Return }),
    1,
  )
}

///|
test "audit globals flow observes conditional reference exits" {
  let wat =
    #|(module (global $g (export "g") (mut i32) (i32.const 0))
    #|(func (param externref) (result i32)
    #| block $exit local.get 0 br_on_null $exit drop i32.const 1 global.set $g end
    #| global.get $g))
  let output = audit_run(wat, "simplify-globals-optimizing")
  assert_true(
    audit_body(output).contains(
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
    ),
  )
}
