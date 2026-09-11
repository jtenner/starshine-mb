///|
test "hot lower keeps a carried read before an overwrite" {
  let input = match
    @wast.wast_to_binary_module(
      (
        #|(module (func (result i32) (local i32)
        #|  i32.const 1 local.set 0
        #|  local.get 0
        #|  i32.const 2 local.set 0
        #|  local.get 0 i32.add))
      ),
    ) {
    Ok(value) => value
    Err(error) => fail("invalid lifetime fixture: \{error}")
  }
  let output = hot_lower_func(hot_lift_func(input, @lib.FuncIdx::new(0U)))
  // Capture locals may change the encoding. Execute this scalar fragment so
  // the check protects the carried value rather than an incidental layout.
  let @lib.Func(locals, @lib.Expr(body)) = output
  let values = Array::make(locals.length(), 0)
  let stack : Array[Int] = []
  for instr in body {
    match instr {
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.LocalSet(@lib.LocalIdx(raw)) =>
        values[raw.reinterpret_as_int()] = stack.pop().unwrap()
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        stack.push(values[raw.reinterpret_as_int()])
      @lib.I32Add => {
        let rhs = stack.pop().unwrap()
        let lhs = stack.pop().unwrap()
        stack.push(lhs + rhs)
      }
      _ => fail("unexpected scalar lifetime instruction: \{instr}")
    }
  }
  @debug.assert_eq(stack, [3])
}

///|
test "hot lower keeps a carried allocation before argument locals change" {
  let array = @lib.TypeIdx::new(0U)
  let local0 = @lib.LocalIdx::new(0U)
  let local1 = @lib.LocalIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(7),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::local_set(local1),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::array_new(array),
            @lib.Instruction::i32_const(9),
            @lib.Instruction::local_set(local1),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::local_set(local0),
            @lib.Instruction::local_get(local0),
            @lib.Instruction::local_get(local1),
            @lib.Instruction::array_set(array),
          ]),
        ),
      ]),
    )
  ignore(@validate.validate_module(input).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(
    hot_lift_func(input, @lib.FuncIdx::new(0U)),
  )
  let mut allocation = -1
  let mut overwrite = -1
  for index, instruction in body {
    if instruction == @lib.Instruction::array_new(@lib.TypeIdx::new(0U)) {
      allocation = index
    }
    if instruction == @lib.Instruction::i32_const(@lib.I32(9)) {
      overwrite = index
    }
  }
  assert_true(
    allocation >= 0 && overwrite >= 0 && allocation < overwrite,
    msg=body.to_string(),
  )
}

///|
test "hot lower keeps a replacement read after its inserted definition" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let old_value = hot_build_const_i32(func, @lib.I32(0))
  let consumer = hot_build_drop(func, old_value)
  let definition = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(42)),
  )
  let read = hot_build_local_get(func, 0)
  hot_replace_node(func, old_value, hot_node_get(func, read))
  hot_delete_detached_node(func, read)
  hot_append_root(func, definition)
  hot_append_root(func, consumer)
  @debug.assert_eq(
    hot_lower_body(func),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(42)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower respects an inserted definition before an existing consumer" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let read = hot_build_local_get(func, 0)
  let consumer = hot_build_drop(func, read)
  let definition = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(42)),
  )
  hot_append_root(func, definition)
  hot_append_root(func, consumer)
  @debug.assert_eq(
    hot_lower_body(func),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(42)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "lift preserves a pending throwing call before a conflicting local write" {
  for capture_stack_locals in [false, true] {
    let source =
      #|(module
      #|  (import "env" "may_throw" (func (result i32)))
      #|  (func (param i32) (result i32)
      #|    (try (result i32)
      #|      (do call 0 local.get 0 i32.const 9 local.set 0 i32.add)
      #|      (catch_all local.get 0))))
    let input = @wast.wast_to_binary_module(source).unwrap()
    let hot = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(1U),
      hot_module_context_from_module(input),
      capture_stack_locals~,
      materialize_multi_values=true,
    ).unwrap()
    let accesses = hot_lift_local_accesses(hot)
    @debug.assert_eq(accesses.gets.length(), 2)
    @debug.assert_eq(accesses.writes.length(), 1)
    @debug.assert_eq(accesses.local_count, 1)
    let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(hot)
    let events : Array[Int] = []
    fn visit(body : Array[@lib.Instruction]) -> Unit {
      for instruction in body {
        match instruction {
          @lib.Call(@lib.FuncIdx(0U)) => events.push(0)
          @lib.LocalSet(@lib.LocalIdx(0U)) => events.push(1)
          @lib.Block(_, @lib.Expr(nested))
          | @lib.Try(_, @lib.Expr(nested), _, _)
          | @lib.TryTable(_, _, @lib.Expr(nested)) => visit(nested)
          _ => ()
        }
      }
    }
    visit(body)
    // If the import throws, the handler must still observe the incoming local.
    @debug.assert_eq(events, [0, 1])
  }
}

///|
test "hot lower keeps a later tee after an inserted earlier control root" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let early_read = hot_build_local_get(func, 0)
  let early_store = hot_build_local_set(func, 1, early_read)
  let later_write = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let later_consumer = hot_build_drop(func, later_write)
  // A pass wraps an existing earlier operation after the later nodes exist.
  // Region order still places its read before the later write.
  let earlier_control = hot_build_block(func, @lib.BlockType::void_(), [
    early_store,
  ])
  hot_append_root(func, earlier_control)
  hot_append_root(func, later_consumer)
  let @lib.Expr(body) = hot_lower_body(func)
  assert_true(body.length() > 0)
  assert_true(body[0] is @lib.Block(_, _), msg=body.to_string())
}

///|
test "hot lower respects an inserted write before a later existing tee" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let later_write = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let later_consumer = hot_build_drop(func, later_write)
  let inserted_write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(42)),
  )
  hot_append_root(func, inserted_write)
  hot_append_root(func, later_consumer)
  let @lib.Expr(body) = hot_lower_body(func)
  @debug.assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(42)))
}

///|
test "hot lower preserves an old carried tee before a newly wrapped write" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let carried = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let old_write = hot_build_local_set(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(42)),
  )
  let consumer = hot_build_drop(func, carried)
  let wrapper = hot_build_block(func, @lib.BlockType::void_(), [old_write])
  hot_append_root(func, wrapper)
  hot_append_root(func, consumer)
  let @lib.Expr(body) = hot_lower_body(func)
  @debug.assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(2)))
}

///|
test "hot lower respects a newly inserted call before an existing consumer" {
  let func = HotFunc::new()
  let value = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let consumer = hot_build_drop(func, value)
  let inserted = hot_build_call(func, 1, [], [])
  hot_append_root(func, inserted)
  hot_append_root(func, consumer)
  let @lib.Expr(body) = hot_lower_body(func)
  @debug.assert_eq(body[0], @lib.Instruction::call(@lib.FuncIdx::new(1U)))
}
