///|
fn tuple_prepare_string_reference(
  func : @ir.HotFunc,
  state : HotPipelineLowerState,
) -> Unit {
  for id in 0..<@ir.hot_node_count(func) {
    if !@ir.hot_node_is_live(func, id) {
      continue
    }
    let node = @ir.hot_node_get(func, id)
    if node.op.to_string() != "TupleMake" {
      continue
    }
    let results = @ir.hot_type_results(func, node.ty)
    if results.length() > 1 {
      @ir.hot_tuple_make_promote_to_block(
        func,
        id,
        @lib.BlockType::type_idx(
          run_hot_pipeline_lower_intern_block_result_type_idx(state, results),
        ),
      )
    }
  }
}

///|
fn tuple_prepare_opcode_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit {
  let result_types = [@lib.ValType::i32(), @lib.ValType::i64()]
  let (before, _) = tuple_prepare_opcode_fixture(width, result_types)
  let (after, _) = tuple_prepare_opcode_fixture(width, result_types)
  let left : HotPipelineLowerState = {
    next_type_sec: None,
    type_sec_changed: false,
  }
  let right : HotPipelineLowerState = {
    next_type_sec: None,
    type_sec_changed: false,
  }
  tuple_prepare_string_reference(before, left)
  run_hot_pipeline_prepare_tuple_make_lowering(after, right)
  if @ir.hot_lower_func(before) != @ir.hot_lower_func(after) ||
    left.next_type_sec != right.next_type_sec {
    abort("tuple admission changed multivalue lowering or type interning")
  }
  it.bench(fn() {
    let (func, tuple) = tuple_prepare_opcode_fixture(width, result_types)
    let state : HotPipelineLowerState = {
      next_type_sec: None,
      type_sec_changed: false,
    }
    if reference {
      tuple_prepare_string_reference(func, state)
    } else {
      run_hot_pipeline_prepare_tuple_make_lowering(func, state)
    }
    it.keep(@ir.hot_node_op(func, tuple))
    it.keep(state.next_type_sec)
  })
}

///|
test "bench tuple preparation string scan roots=64" (it : @bench.T) {
  tuple_prepare_opcode_bench(it, 64, true)
}

///|
test "bench tuple preparation opcode scan roots=64" (it : @bench.T) {
  tuple_prepare_opcode_bench(it, 64, false)
}

///|
test "bench tuple preparation string scan roots=1024" (it : @bench.T) {
  tuple_prepare_opcode_bench(it, 1024, true)
}

///|
test "bench tuple preparation opcode scan roots=1024" (it : @bench.T) {
  tuple_prepare_opcode_bench(it, 1024, false)
}
