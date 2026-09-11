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

///|
test "hot lowering keeps call order after replacing drop roots" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (import "env" "a" (func (result i32)))
      #| (import "env" "b" (func (result i32)))
      #| (func call 0 drop call 1 drop))
    ),
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(2U))
  for index = 0; index < hot_root_count(func); index = index + 1 {
    let root = hot_root_get(func, index)
    let call = hot_child_get(func, root, 0)
    ignore(hot_root_set(func, index, hot_build_drop(func, call)))
  }
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(func)
  let calls : Array[UInt] = []
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
      _ => ()
    }
  }
  @debug.assert_eq(calls, [0U, 1U])
}

///|
test "hot lowering reuses a carried call below another constructor operand" {
  let input = @wast.wast_to_binary_module(
    (
      #|(module
      #| (import "env" "read" (func (result i32)))
      #| (import "env" "mutate" (func))
      #| (func (export "run") (result i32) (local i32)
      #|  call 0 call 1 local.set 0
      #|  i32.const 1 local.get 0 i32.add))
    ),
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(2U))
  let mut set_id = -1
  let mut get_id = -1
  for id = 0; id < hot_node_count(func); id = id + 1 {
    if !hot_node_is_live(func, id) {
      continue
    }
    let node = hot_node_get(func, id)
    if node.op is HotOp::LocalSet && node.imm0 == 0 {
      set_id = id
    }
    if node.op is HotOp::LocalGet && node.imm0 == 0 {
      get_id = id
    }
  }
  assert_true(set_id >= 0 && get_id >= 0)
  let tee = hot_build_local_tee_from_set(func, set_id)
  hot_replace_node(
    func,
    get_id,
    hot_node_get(func, tee),
    preserve_value_order=true,
  )
  hot_delete_node(func, tee)
  let nop = hot_build_nop(func)
  hot_replace_node(func, set_id, hot_node_get(func, nop))
  hot_delete_node(func, nop)
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(func)
  let calls : Array[UInt] = []
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(index)) => calls.push(index)
      _ => ()
    }
  }
  @debug.assert_eq(calls, [0U, 1U])
  assert_true(body.contains(@lib.Instruction::i32_add()))
}
