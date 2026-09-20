///|
test "OI global interference without module context must assume storage aliasing" {
  let writes = OiStateWriteSetFact::empty()
  writes.add_global(0)
  assert_true(writes.writes_global(1))
}

///|
test "OI global write sets use proven storage disjointness" {
  let module_ctx = Some(
    @ir.hot_module_context_from_module(
      pass_test_module_from_wat(
        "(module (import \"m\" \"a\" (global (mut i32))) (import \"m\" \"b\" (global (mut i32))) (global (mut i32) (i32.const 1)) (global (mut i32) (i32.const 2)))",
      ),
    ),
  )
  let writes = OiStateWriteSetFact::empty()
  writes.add_global(0)
  assert_true(writes.writes_global(1, module_ctx~))
  assert_false(writes.writes_global(2, module_ctx~))
  let defined = OiStateWriteSetFact::empty()
  defined.add_global(2)
  assert_false(defined.writes_global(3, module_ctx~))
  assert_true(defined.writes_global(2, module_ctx~))
}
