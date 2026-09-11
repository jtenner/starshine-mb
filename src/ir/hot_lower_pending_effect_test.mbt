///|
test "hot lowering orders a carried call before a later global store" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (global (mut i32) (i32.const 0))
      #| (func $write (result i32)
      #|   i32.const 1 global.set 0 i32.const 7)
      #| (func (export "run") (result i32)
      #|   call $write i32.const 2 global.set 0 drop global.get 0))
    ),
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(
    hot_lift_func(input, @lib.FuncIdx::new(1U)),
  )
  let mut call_at = -1
  let mut store_at = -1
  for index, instr in body {
    match instr {
      @lib.Call(_) => call_at = index
      @lib.GlobalSet(_) => store_at = index
      _ => ()
    }
  }
  assert_true(call_at >= 0 && call_at < store_at, msg=body.to_string())
}

///|
test "hot lowering uses source order for a set split from a tee" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let address = hot_build_const_i32(func, @lib.I32(0))
  let arg = @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0))
  let value = hot_build_load(func, @lib.ValType::i32(), arg, address)
  hot_node_exact_instr_set(func, value, @lib.Instruction::i32_load(arg))
  let tee = hot_build_local_tee(func, 0, value)
  let read = hot_build_local_get(func, 0)
  let load = hot_build_load(
    func,
    @lib.ValType::i32(),
    @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0)),
    read,
  )
  hot_node_exact_instr_set(
    func,
    load,
    @lib.Instruction::i32_load(@lib.MemArg::new(@lib.U32(2), None, @lib.U64(0))),
  )
  // A transform can allocate unrelated nodes before splitting this tee.
  ignore(hot_build_const_i32(func, @lib.I32(0)))
  let split_set = hot_build_local_set_from_tee(func, tee)
  let consumer = hot_build_drop(func, load)
  hot_root_append(func, split_set)
  hot_root_append(func, consumer)
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(func)
  let mut initialized = false
  let mut reads = 0
  for instr in body {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(0U)) => initialized = true
      @lib.LocalGet(@lib.LocalIdx(0U)) => {
        assert_true(initialized, msg=body.to_string())
        reads += 1
      }
      _ => ()
    }
  }
  @debug.assert_eq(reads, 1)
}
