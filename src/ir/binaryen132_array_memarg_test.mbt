///|
test "Binaryen 132 multibyte array operations preserve HOT operands immediates and effects" {
  let source =
    #|(module (type $A (array (mut i32)))
    #| (func (param (ref null $A)) (result i32)
    #|  (i32.store (type $A) offset=17 align=1 (local.get 0) (i32.const 4) (i32.const 9))
    #|  (i32.load (type $A) offset=17 align=1 (local.get 0) (i32.const 4))))
  let input = @wast.wast_to_binary_module(source).unwrap()
  let hot = hot_lift_func(input, @lib.FuncIdx::new(0U))
  match hot_verify_core(hot) {
    Ok(_) => ()
    Err(err) => fail("array HOT: \{err}")
  }
  let mut reads = 0
  let mut writes = 0
  for node = 0; node < hot_node_count(hot); node = node + 1 {
    match hot_node_exact_instr(hot, node) {
      Some(@lib.ArrayLoad(_, _, ma)) => {
        @debug.assert_eq(ma, @lib.MemArg::new(0U, None, 17UL))
        @debug.assert_eq(hot_child_span(hot, node).length(), 2)
        @debug.assert_eq(
          effects_reads_memory(effects_for_node(hot, node)),
          true,
        )
        @debug.assert_eq(effects_is_pure(effects_for_node(hot, node)), false)
        reads += 1
      }
      Some(@lib.ArrayStore(_, _, ma)) => {
        @debug.assert_eq(ma, @lib.MemArg::new(0U, None, 17UL))
        @debug.assert_eq(hot_child_span(hot, node).length(), 3)
        @debug.assert_eq(
          effects_writes_memory(effects_for_node(hot, node)),
          true,
        )
        @debug.assert_eq(effects_is_pure(effects_for_node(hot, node)), false)
        writes += 1
      }
      _ => ()
    }
  }
  @debug.assert_eq((reads, writes), (1, 1))
  @debug.assert_eq(hot_lower_func_unverified(hot), input.code_sec.unwrap().0[0])
}
