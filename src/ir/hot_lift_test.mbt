///|
fn hot_lift_test_memarg() -> @lib.MemArg {
  @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
}

///|
fn hot_lift_test_context_module() -> @lib.Module {
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([array_type]))
  .with_mem_sec(
    @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1, None))]),
  )
}

///|
test "hot lift can preserve representative exact-payload families in module context" {
  let memarg = hot_lift_test_memarg()
  let module_ = hot_lift_test_context_module()
  let ctx = hot_module_context_from_module(module_)
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
      @lib.Instruction::array_len(),
      @lib.Instruction::drop(),
      @lib.Instruction::v128_const(
        b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
        b'\x09', b'\x0a', b'\x0b', b'\x0c', b'\x0d', b'\x0e', b'\x0f',
      ),
      @lib.Instruction::i8x16_extract_lane_s(@lib.LaneIdx::new(b'\x00')),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::atomic_rmw(@lib.AtomicRmwOp::i32_add(), memarg),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(),
    ctx,
  )

  let load_drop = hot_root_get(func, 0)
  let add_drop = hot_root_get(func, 1)
  let array_drop = hot_root_get(func, 2)
  let simd_drop = hot_root_get(func, 3)
  let atomic_drop = hot_root_get(func, 4)

  let load_id = hot_child_get(func, load_drop, 0)
  let add_id = hot_child_get(func, add_drop, 0)
  let array_id = hot_child_get(func, array_drop, 0)
  let simd_id = hot_child_get(func, simd_drop, 0)
  let atomic_id = hot_child_get(func, atomic_drop, 0)

  assert_true(hot_node_kind_is_memory(func, load_id))
  assert_eq(
    hot_node_exact_instr(func, load_id),
    Some(@lib.Instruction::i32_load(memarg)),
  )
  assert_true(hot_node_kind_is_numeric(func, add_id))
  assert_eq(
    hot_node_exact_instr(func, add_id),
    Some(@lib.Instruction::i32_add()),
  )
  assert_true(hot_node_kind_is_heap(func, array_id))
  assert_eq(
    hot_node_exact_instr(func, array_id),
    Some(@lib.Instruction::array_len()),
  )
  assert_true(hot_node_kind_is_simd(func, simd_id))
  assert_eq(
    hot_node_exact_instr(func, simd_id),
    Some(@lib.Instruction::i8x16_extract_lane_s(@lib.LaneIdx::new(b'\x00'))),
  )
  assert_true(hot_node_kind_is_atomic(func, atomic_id))
  assert_eq(
    hot_node_exact_instr(func, atomic_id),
    Some(@lib.Instruction::atomic_rmw(@lib.AtomicRmwOp::i32_add(), memarg)),
  )
}

///|
fn hot_lift_test_func_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("callee"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
  ])
  @lib.Module::new()
  .with_type_sec(type_sec)
  .with_import_sec(import_sec)
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
fn hot_lift_test_block_param_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
      ),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec)
}

///|
test "hot lift func derives locals and direct call metadata from the module" {
  let func = hot_lift_func(hot_lift_test_func_module(), @lib.FuncIdx::new(1U))

  assert_eq(hot_local_param_count(func), 1)
  assert_eq(hot_local_body_count(func), 1)
  assert_eq(hot_root_count(func), 1)

  let call_id = hot_root_get(func, 0)
  assert_true(hot_node_kind_is_call(func, call_id))
  assert_eq(
    hot_node_type(func, call_id),
    hot_type_intern_value(func, @lib.ValType::i32()),
  )
}

///|
test "hot lift maps try_table catches onto hot labels" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::try_table(
            @lib.BlockType::void_(),
            [@lib.Catch::all(@lib.LabelIdx::new(0U))],
            @lib.Expr::new([@lib.Instruction::nop()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )

  let block_id = hot_root_get(func, 0)
  let try_table_id = hot_child_get(func, block_id, 0)
  let catch_info = hot_catch_info_get(
    func,
    hot_node_get(func, try_table_id).imm1,
  )

  assert_eq(hot_node_get(func, try_table_id).op.to_string(), "TryTable")
  assert_eq(catch_info.catches.length(), 1)
  match catch_info.catches[0] {
    HotCatchArm::CatchAllArm(label_id) =>
      assert_eq(label_id, hot_control_node_label(func, block_id))
    other => fail("expected catch_all arm, got \{other}")
  }
}

///|
test "hot lift preserves live prefixes across repeated stack types" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_const(@lib.I32(3)),
      @lib.Instruction::i32_sub(),
    ]),
    HotLocals::new(),
  )

  assert_eq(hot_root_count(func), 2)

  let prefix = hot_root_get(func, 0)
  let sub = hot_root_get(func, 1)

  assert_true(hot_node_kind_is_numeric(func, prefix))
  assert_eq(hot_child_count(func, prefix), 0)
  assert_eq(hot_node_exact_instr(func, sub), Some(@lib.Instruction::i32_sub()))
  assert_eq(hot_child_count(func, sub), 2)
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, sub, 0)))
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, sub, 1)))
  assert_eq(hot_child_count(func, hot_child_get(func, sub, 0)), 0)
  assert_eq(hot_child_count(func, hot_child_get(func, sub, 1)), 0)
}

///|
test "hot lift seeds loop param values into nested regions" {
  let module_ = hot_lift_test_block_param_module()
  let ctx = hot_module_context_from_module(module_)
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([@lib.Instruction::local_tee(@lib.LocalIdx::new(0U))]),
      ),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
    ctx,
  )

  assert_eq(hot_root_count(func), 1)

  let loop_id = hot_root_get(func, 0)
  let body_region = hot_region_body_ref(func, loop_id)
  let tee_id = hot_region_get(func, body_region, 0)

  assert_true(hot_node_kind_is_local(func, tee_id))
  assert_eq(hot_child_count(func, tee_id), 1)
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, tee_id, 0)))
  assert_eq(hot_child_count(func, hot_child_get(func, tee_id, 0)), 0)
}

///|
test "hot lift preserves concrete unreachable stack prefixes for local.get" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::unreachable_(),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
  )

  assert_eq(hot_root_count(func), 4)

  let trap = hot_root_get(func, 0)
  let left = hot_root_get(func, 1)
  let right = hot_root_get(func, 2)
  let local_get = hot_root_get(func, 3)

  assert_eq(hot_node_get(func, trap).op.to_string(), "Unreachable")
  assert_true(hot_node_kind_is_numeric(func, left))
  assert_true(hot_node_kind_is_numeric(func, right))
  assert_true(hot_node_kind_is_local(func, local_get))
  assert_eq(hot_child_count(func, local_get), 0)
}

///|
test "hot lift tolerates polymorphic unreachable operands with no concrete values" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::unreachable_(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
  )

  assert_eq(hot_root_count(func), 1)

  let trap = hot_root_get(func, 0)
  assert_eq(hot_node_get(func, trap).op.to_string(), "Unreachable")
}
