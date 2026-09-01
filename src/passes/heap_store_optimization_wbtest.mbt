///|
test "heap-store-optimization external root context visits suffixes without prefixes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0))
  let suffix = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1))
  let outer = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 2))
  let external_roots = hso_new_external_roots()

  hso_external_roots_push(external_roots, [prefix, suffix], 1)
  assert_false(hso_external_roots_touch_local(func, external_roots, 0))
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_false(hso_external_roots_touch_local(func, external_roots, 2))

  hso_external_roots_push(external_roots, [outer], 0)
  assert_false(hso_external_roots_touch_local(func, external_roots, 0))
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_true(hso_external_roots_touch_local(func, external_roots, 2))

  hso_external_roots_pop(external_roots)
  assert_true(hso_external_roots_touch_local(func, external_roots, 1))
  assert_false(hso_external_roots_touch_local(func, external_roots, 2))
}

///|
test "heap-store-optimization bounds per-candidate chain scratch capacity" {
  @debug.assert_eq(hso_chain_scratch_capacity(0), 0)
  @debug.assert_eq(hso_chain_scratch_capacity(3), 3)
  @debug.assert_eq(hso_chain_scratch_capacity(4096), 8)
}
