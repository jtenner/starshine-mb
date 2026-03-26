///|
fn hot_lift_perf_test_if_entry_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
          @lib.ValType::i32(),
        ]),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("pair"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
  ])
  @lib.Module::new()
  .with_type_sec(type_sec)
  .with_import_sec(import_sec)
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(2U)),
            [@lib.Instruction::drop()],
            Some([@lib.Instruction::drop()]),
          ),
        ]),
      ),
    ]),
  )
}

///|
test "hot lift preserves duplicated multivalue control-entry stacks without recomputing node result types" {
  let module_ = hot_lift_perf_test_if_entry_module()
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let if_id = hot_root_get(hot, 0)
  let then_region = hot_region_then_ref(hot, if_id)
  let else_region = hot_region_else_ref(hot, if_id).unwrap()
  let then_drop = hot_region_get(hot, then_region, 0)
  let else_drop = hot_region_get(hot, else_region, 0)
  let then_call = hot_child_get(hot, then_drop, 0)
  let else_call = hot_child_get(hot, else_drop, 0)

  assert_eq(hot_node_get(hot, if_id).op.to_string(), "If")
  assert_true(hot_node_kind_is_call(hot, then_call))
  assert_eq(then_call, else_call)
}
