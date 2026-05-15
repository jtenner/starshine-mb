///|
test "precompute rejects multi-root constant-if chosen regions" {
  let func = @ir.HotFunc::new()
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(2)),
      @ir.hot_build_const_i32(func, @lib.I32(3)),
    ]),
  )
  let else_region = @ir.hot_region_else_ref(func, if_id).unwrap()

  assert_false(
    precompute_constant_if_chosen_region_can_inline(func, else_region),
  )
}
