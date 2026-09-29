///|
test "lowering and expanded CFG preserve an old read before a source-ordered new wrapper" {
  for padding in [0, 64] {
    let input = @wast.wast_to_binary_module(
      "(module (func (export \"run\") (param i32) (result i32) local.get 0 block i32.const 11 local.set 0 end local.get 0 i32.add))",
    ).unwrap()
    let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let block = hot_root_get(func, 0)
    let body_ref = hot_region_body_ref(func, block)
    let old_set = hot_region_get(func, body_ref, 0)
    let value = hot_child_get(func, old_set, 0)
    let consumer = hot_root_get(func, 1)
    let old_read = hot_child_get(func, consumer, 0)
    ignore(hot_region_set(func, body_ref, 0, value))
    hot_control_result_type_set(
      func,
      block,
      hot_type_intern_block_result(
        func,
        @lib.BlockType::val_type(@lib.ValType::i32()),
      ),
    )
    let new_set = hot_build_local_set_from_value(func, 0, block)
    assert_true(new_set > consumer)
    assert_true(
      hot_node_get(func, new_set).order > hot_node_get(func, old_read).order,
    )
    ignore(hot_root_set(func, 0, new_set))
    hot_delete_detached_node(func, old_set)
    let roots = [new_set]
    for _ in 0..<padding {
      roots.push(hot_build_nop(func))
    }
    roots.push(consumer)
    ignore(hot_root_splice(func, 0, hot_root_count(func), roots))
    hot_verify_all(func).unwrap()
    let graph = local_graph_build_full_flow(
      func,
      cfg_build(func, expand_operand_control=true),
    )
    assert_eq(local_graph_reaching_sources_for_get(graph, old_read), [
      EntrySource(0),
    ])
    let lowered = hot_lower_func(func)
    let @lib.Func(_, @lib.Expr(body)) = lowered
    assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    let validation = @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([lowered])),
    )
    assert_true(validation is Ok(_), msg="\{validation}; body=\{body}")
  }
}
