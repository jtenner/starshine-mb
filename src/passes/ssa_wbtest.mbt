///|
test "full ssa validates a merge rewrite before mutating the function" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let get_id = @ir.hot_build_local_get(func, 0)
  let invalid_write = @ir.hot_build_const_i32(func, @lib.I32(7))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, get_id))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, invalid_write))
  let before_local_count = @ir.hot_local_count(func)
  let before_get = @ir.hot_node_get(func, get_id)
  let rewrite : SsaFullMergeGetRewrite = {
    get_id,
    original_local: 0,
    merge_local: 1,
    inputs: [SsaFullMergeInput::ExplicitWrite(invalid_write)],
  }

  assert_false(ssa_full_apply_simple_explicit_merge_rewrite(func, rewrite))
  @debug.assert_eq(@ir.hot_local_count(func), before_local_count)
  @debug.assert_eq(@ir.hot_node_get(func, get_id), before_get)
}
