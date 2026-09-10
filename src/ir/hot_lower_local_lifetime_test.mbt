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
  let original = input.code_sec.unwrap().0[0]
  let output = hot_lower_func(hot_lift_func(input, @lib.FuncIdx::new(0U)))
  @debug.assert_eq(output, original)
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
