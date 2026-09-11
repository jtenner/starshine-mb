///|
test "hot lift keeps a result store after a nested loop exit" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (func (result i32) (local i32 i32 i32)
      #|   block
      #|     loop
      #|       block
      #|         block
      #|           i32.const 0
      #|           if br 3 end
      #|         end
      #|         block br 3 end
      #|       end
      #|       unreachable
      #|     end
      #|     unreachable
      #|   end
      #|   i32.const 7
      #|   i32.const 9
      #|   i32.const 0
      #|   if (result i32) unreachable else i32.const 42 end
      #|   local.set 0
      #|   local.set 1
      #|   local.set 2
      #|   local.get 0))
    ),
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let mut writes = 0
  for id = 0; id < hot_node_count(func); id = id + 1 {
    let node = hot_node_get(func, id)
    if node.op is HotOp::LocalSet && node.imm0 == 0 {
      writes += 1
      assert_true(
        hot_node_get(func, hot_child_get(func, id, 0)).op is HotOp::If,
      )
    }
  }
  @debug.assert_eq(writes, 1)
}
