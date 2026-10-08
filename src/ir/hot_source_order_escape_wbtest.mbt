///|
test "source-order dependencies preserve a carried local write before an escaping branch" {
  for writes in [false, true] {
    let func = HotFunc::new(
      locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
        @lib.ValType::i32(),
      ]),
    )
    let block = hot_build_block(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
    )
    let input = hot_build_local_get(func, 0)
    let carried = if writes {
      hot_build_local_tee(func, 1, input)
    } else {
      input
    }
    let payload = hot_build_const_i32(func, @lib.I32(0))
    let condition = hot_build_local_get(func, 0)
    let branch = hot_build_br_if(
      func,
      hot_control_node_label(func, block),
      condition,
      values=[payload],
    )
    let select = hot_build_select(
      func,
      @lib.ValType::i32(),
      carried,
      payload,
      hot_build_const_i32(func, @lib.I32(0)),
    )
    let drop = hot_build_drop(func, select)
    let tail = hot_build_const_i32(func, @lib.I32(0))
    ignore(hot_replace_child_span(func, block, [branch, drop, tail]))
    hot_root_append(func, hot_build_drop(func, block))
    hot_verify_all(func).unwrap()
    let facts = HotSourceOrderFacts::new(func)
    for _ in 0..<3 {
      assert_eq(
        hot_source_order_preceding_dependencies(
          func,
          branch,
          [drop, tail],
          0,
          None,
          facts,
        ),
        if writes {
          [carried]
        } else {
          []
        },
      )
    }
  }
}
