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
  @debug.assert_eq(
    hot_node_exact_instr(func, load_id),
    Some(@lib.Instruction::i32_load(memarg)),
  )
  assert_true(hot_node_kind_is_numeric(func, add_id))
  @debug.assert_eq(
    hot_node_exact_instr(func, add_id),
    Some(@lib.Instruction::i32_add()),
  )
  assert_true(hot_node_kind_is_heap(func, array_id))
  @debug.assert_eq(
    hot_node_exact_instr(func, array_id),
    Some(@lib.Instruction::array_len()),
  )
  assert_true(hot_node_kind_is_simd(func, simd_id))
  @debug.assert_eq(
    hot_node_exact_instr(func, simd_id),
    Some(@lib.Instruction::i8x16_extract_lane_s(@lib.LaneIdx::new(b'\x00'))),
  )
  assert_true(hot_node_kind_is_atomic(func, atomic_id))
  @debug.assert_eq(
    hot_node_exact_instr(func, atomic_id),
    Some(@lib.Instruction::atomic_rmw(@lib.AtomicRmwOp::i32_add(), memarg)),
  )
}

///|
test "hot lift context result reports invalid body instead of aborting" {
  let result = hot_lift_body_with_context_result(
    @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    HotLocals::new(),
    hot_module_context_from_module(@lib.Module::new()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  match result {
    Ok(_) => fail("expected invalid lift body to return an error")
    Err(err) =>
      assert_true(err.to_string().contains("stack underflow"), msg="\{err}")
  }
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
fn hot_lift_test_multi_result_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
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
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lift_test_triple_result_bridge_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [
          @lib.ValType::i32(),
          @lib.ValType::i32(),
          @lib.ValType::i32(),
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [
            @lib.ValType::i32(),
            @lib.ValType::i32(),
            @lib.ValType::i32(),
            @lib.ValType::i64(),
          ],
          [@lib.ValType::i32()],
        ),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("check"),
      @lib.ExternType::func(@lib.TypeIdx::new(1U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lift_test_triple_result_tee_consumer_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [
          @lib.ValType::i32(),
          @lib.ValType::i32(),
          @lib.ValType::i32(),
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("consume"),
      @lib.ExternType::func(@lib.TypeIdx::new(1U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lift_test_deep_branch_body(depth : Int) -> @lib.Expr {
  let mut current = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::br(@lib.LabelIdx::new((depth - 1).reinterpret_as_uint())),
    @lib.Instruction::unreachable_(),
  ])
  for _ in 0..<depth {
    current = @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        current,
      ),
    ])
  }
  current
}

///|
test "hot lift func derives locals and direct call metadata from the module" {
  let func = hot_lift_func(hot_lift_test_func_module(), @lib.FuncIdx::new(1U))

  @debug.assert_eq(hot_local_param_count(func), 1)
  @debug.assert_eq(hot_local_body_count(func), 1)
  @debug.assert_eq(hot_root_count(func), 1)

  let call_id = hot_root_get(func, 0)
  assert_true(hot_node_kind_is_call(func, call_id))
  @debug.assert_eq(
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

  @debug.assert_eq(hot_node_get(func, try_table_id).op.to_string(), "TryTable")
  @debug.assert_eq(catch_info.catches.length(), 1)
  match catch_info.catches[0] {
    HotCatchArm::CatchAllArm(label_id) =>
      @debug.assert_eq(label_id, hot_control_node_label(func, block_id))
    other => fail("expected catch_all arm, got \{other}")
  }
}

///|
test "hot lift resolves deep branch labels without copying full label stacks" {
  let depth = 64
  let body = hot_lift_test_deep_branch_body(depth)
  let func = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  let outer_block = hot_root_get(func, 0)
  let outer_label = hot_control_node_label(func, outer_block)
  let mut current = outer_block
  for _ in 1..<depth {
    let region = hot_region_body_ref(func, current)
    current = hot_region_get(func, region, 0)
  }
  let inner_region = hot_region_body_ref(func, current)
  let br_id = hot_region_get(func, inner_region, 0)

  @debug.assert_eq(hot_node_get(func, br_id).op.to_string(), "Br")
  @debug.assert_eq(hot_node_get(func, br_id).imm0, outer_label)
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

  @debug.assert_eq(hot_root_count(func), 2)

  let prefix = hot_root_get(func, 0)
  let sub = hot_root_get(func, 1)

  assert_true(hot_node_kind_is_numeric(func, prefix))
  @debug.assert_eq(hot_child_count(func, prefix), 0)
  @debug.assert_eq(
    hot_node_exact_instr(func, sub),
    Some(@lib.Instruction::i32_sub()),
  )
  @debug.assert_eq(hot_child_count(func, sub), 2)
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, sub, 0)))
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, sub, 1)))
  @debug.assert_eq(hot_child_count(func, hot_child_get(func, sub, 0)), 0)
  @debug.assert_eq(hot_child_count(func, hot_child_get(func, sub, 1)), 0)
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

  @debug.assert_eq(hot_root_count(func), 1)

  let loop_id = hot_root_get(func, 0)
  @debug.assert_eq(
    hot_label_branch_arity(func, hot_control_node_label(func, loop_id)),
    1,
  )
  @debug.assert_eq(hot_child_count(func, loop_id), 2)
  let body_region = hot_region_body_ref(func, loop_id)
  let tee_id = hot_region_get(func, body_region, 0)

  assert_true(hot_node_kind_is_local(func, tee_id))
  @debug.assert_eq(hot_child_count(func, tee_id), 1)
  assert_true(hot_node_kind_is_numeric(func, hot_child_get(func, tee_id, 0)))
  @debug.assert_eq(hot_child_count(func, hot_child_get(func, tee_id, 0)), 0)
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

  @debug.assert_eq(hot_root_count(func), 4)

  let trap = hot_root_get(func, 0)
  let left = hot_root_get(func, 1)
  let right = hot_root_get(func, 2)
  let local_get = hot_root_get(func, 3)

  @debug.assert_eq(hot_node_get(func, trap).op.to_string(), "Unreachable")
  assert_true(hot_node_kind_is_numeric(func, left))
  assert_true(hot_node_kind_is_numeric(func, right))
  assert_true(hot_node_kind_is_local(func, local_get))
  @debug.assert_eq(hot_child_count(func, local_get), 0)
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

  @debug.assert_eq(hot_root_count(func), 1)

  let trap = hot_root_get(func, 0)
  @debug.assert_eq(hot_node_get(func, trap).op.to_string(), "Unreachable")
}

///|
test "hot lift preserves surviving results from multi-result producers" {
  let ctx = hot_module_context_from_module(hot_lift_test_multi_result_module())
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
        Some([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
    ]),
    HotLocals::new(locals=[@lib.ValType::i32()]),
    ctx,
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  @debug.assert_eq(hot_root_count(func), 2)

  let local_set = hot_root_get(func, 0)
  let if_id = hot_root_get(func, 1)
  let call_id = hot_child_get(func, local_set, 0)

  assert_true(hot_node_kind_is_local(func, local_set))
  @debug.assert_eq(hot_node_get(func, if_id).op.to_string(), "If")
  assert_true(hot_node_kind_is_call(func, call_id))
  @debug.assert_eq(hot_node_result_arity(func, call_id), 2)
  @debug.assert_eq(hot_child_get(func, if_id, 0), call_id)
}

///|
test "hot lift preserves explicit triple-result spill bridges" {
  let ctx = hot_module_context_from_module(
    hot_lift_test_triple_result_bridge_module(),
  )
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(10)),
          @lib.Instruction::i32_const(@lib.I32(20)),
          @lib.Instruction::i32_const(@lib.I32(30)),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
      @lib.Instruction::i64_extend_i32s(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
    ctx,
  )

  @debug.assert_eq(hot_root_count(func), 7)

  let set2 = hot_root_get(func, 0)
  let set1 = hot_root_get(func, 1)
  let set0 = hot_root_get(func, 2)
  let set4 = hot_root_get(func, 3)
  let set5 = hot_root_get(func, 4)
  let set7 = hot_root_get(func, 5)
  let drop_id = hot_root_get(func, 6)

  @debug.assert_eq(hot_node_get(func, set2).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set2).imm0, 2)
  @debug.assert_eq(hot_node_get(func, set1).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set1).imm0, 1)
  @debug.assert_eq(hot_node_get(func, set0).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set0).imm0, 0)

  let producer = hot_child_get(func, set2, 0)
  @debug.assert_eq(hot_child_get(func, set1, 0), producer)
  @debug.assert_eq(hot_child_get(func, set0, 0), producer)
  @debug.assert_eq(hot_node_get(func, producer).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, producer), 3)

  @debug.assert_eq(hot_node_get(func, set4).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set4).imm0, 4)
  @debug.assert_eq(hot_node_get(func, set5).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set5).imm0, 5)
  @debug.assert_eq(hot_node_get(func, set7).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set7).imm0, 7)
  @debug.assert_eq(hot_node_get(func, drop_id).op.to_string(), "Drop")
}

///|
test "hot lift preserves nested outer-block spill lanes after a triple-result bridge" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (type (func (param i32 i32 i32) (result i32 i32 i32))) (func (type 0) (param i32 i32 i32) (result i32 i32 i32) local.get 0 local.get 1 local.get 2) (func (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 10 local.set 5 i32.const 20 local.set 4 block block block i32.const 30 local.tee 3 local.get 4 local.get 5 call 0 local.set 8 local.set 7 local.set 6 block (result i32) block (result i32 i32 i32) local.get 6 local.get 7 local.get 8 end local.set 2 local.set 1 end local.set 0 end local.get 2 local.set 11 local.get 1 local.set 10 local.get 0 local.set 9 end local.get 11 drop local.get 10 drop local.get 9 drop end))",
    code_idx=1,
  )
  let func = fixture.hot_func
  let use_def = use_def_build(func)

  @debug.assert_eq(local_write_nodes_borrowed(use_def, 0).length(), 1)
  @debug.assert_eq(local_write_nodes_borrowed(use_def, 1).length(), 1)
  @debug.assert_eq(local_write_nodes_borrowed(use_def, 2).length(), 1)
  @debug.assert_eq(local_read_nodes_borrowed(use_def, 0).length(), 1)
  @debug.assert_eq(local_read_nodes_borrowed(use_def, 1).length(), 1)
  @debug.assert_eq(local_read_nodes_borrowed(use_def, 2).length(), 1)
}

///|
test "hot lift preserves branchy triple-result spill bridges" {
  let ctx = hot_module_context_from_module(
    hot_lift_test_triple_result_bridge_module(),
  )
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(10)),
                  @lib.Instruction::i32_const(@lib.I32(20)),
                  @lib.Instruction::i32_const(@lib.I32(30)),
                  @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                ],
                None,
              ),
              @lib.Instruction::i32_const(@lib.I32(40)),
              @lib.Instruction::i32_const(@lib.I32(50)),
              @lib.Instruction::i32_const(@lib.I32(60)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
      @lib.Instruction::i64_extend_i32s(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
    ctx,
  )

  @debug.assert_eq(hot_root_count(func), 7)

  let set2 = hot_root_get(func, 0)
  let set1 = hot_root_get(func, 1)
  let set0 = hot_root_get(func, 2)

  @debug.assert_eq(hot_node_get(func, set2).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set2).imm0, 2)
  @debug.assert_eq(hot_node_get(func, set1).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set1).imm0, 1)
  @debug.assert_eq(hot_node_get(func, set0).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set0).imm0, 0)

  let producer = hot_child_get(func, set2, 0)
  @debug.assert_eq(hot_child_get(func, set1, 0), producer)
  @debug.assert_eq(hot_child_get(func, set0, 0), producer)
  @debug.assert_eq(hot_node_get(func, producer).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, producer), 3)
}

///|
test "hot lift preserves spill bridges after branchy local-get result blocks" {
  let ctx = hot_module_context_from_module(
    hot_lift_test_triple_result_bridge_module(),
  )
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(10)),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  @lib.Instruction::i32_const(@lib.I32(20)),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  @lib.Instruction::i32_const(@lib.I32(30)),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                ],
                None,
              ),
              @lib.Instruction::i32_const(@lib.I32(40)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              @lib.Instruction::i32_const(@lib.I32(50)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              @lib.Instruction::i32_const(@lib.I32(60)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            ]),
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(6U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::i64_extend_i32s(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(9U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(8U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(9U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ]),
    ctx,
  )

  @debug.assert_eq(hot_root_count(func), 7)

  let set5 = hot_root_get(func, 0)
  let set4 = hot_root_get(func, 1)
  let set3 = hot_root_get(func, 2)

  @debug.assert_eq(hot_node_get(func, set5).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set5).imm0, 5)
  @debug.assert_eq(hot_node_get(func, set4).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set4).imm0, 4)
  @debug.assert_eq(hot_node_get(func, set3).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set3).imm0, 3)

  let producer = hot_child_get(func, set5, 0)
  @debug.assert_eq(hot_child_get(func, set4, 0), producer)
  @debug.assert_eq(hot_child_get(func, set3, 0), producer)
  @debug.assert_eq(hot_node_get(func, producer).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, producer), 3)
}

///|
test "hot lift preserves branchy triple-result bridges ending in local.tee" {
  let ctx = hot_module_context_from_module(
    hot_lift_test_triple_result_tee_consumer_module(),
  )
  let func = hot_lift_body_with_context(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(10)),
                  @lib.Instruction::i32_const(@lib.I32(20)),
                  @lib.Instruction::i32_const(@lib.I32(30)),
                  @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                ],
                None,
              ),
              @lib.Instruction::i32_const(@lib.I32(40)),
              @lib.Instruction::i32_const(@lib.I32(50)),
              @lib.Instruction::i32_const(@lib.I32(60)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::drop(),
    ]),
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    ctx,
  )

  @debug.assert_eq(hot_root_count(func), 5)

  let set2 = hot_root_get(func, 0)
  let set1 = hot_root_get(func, 1)
  let call_id = hot_root_get(func, 2)

  @debug.assert_eq(hot_node_get(func, set2).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set2).imm0, 2)
  @debug.assert_eq(hot_node_get(func, set1).op.to_string(), "LocalSet")
  @debug.assert_eq(hot_node_get(func, set1).imm0, 1)
  @debug.assert_eq(hot_node_get(func, call_id).op.to_string(), "Call")

  let producer = hot_child_get(func, set2, 0)
  @debug.assert_eq(hot_child_get(func, set1, 0), producer)
  @debug.assert_eq(hot_node_get(func, producer).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, producer), 3)

  let tee0 = hot_child_get(func, call_id, 0)
  @debug.assert_eq(hot_node_get(func, tee0).op.to_string(), "LocalTee")
  @debug.assert_eq(hot_node_get(func, tee0).imm0, 0)
  @debug.assert_eq(hot_child_get(func, tee0, 0), producer)
}

///|
test "hot lift tolerates unreachable br payloads with no concrete values" {
  let func = match
    hot_lift_body_result(
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::return_(),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
      HotLocals::new(),
      body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
    ) {
    Ok(func) => func
    Err(err) => fail(err.to_string())
  }

  @debug.assert_eq(hot_root_count(func), 1)
  let block_id = hot_root_get(func, 0)
  @debug.assert_eq(hot_node_get(func, block_id).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, block_id), 1)
  @debug.assert_eq(
    hot_region_root_count(func, hot_region_body_ref(func, block_id)),
    2,
  )
}

///|
test "hot lift keeps unreachable compare conditions wired to typed block results" {
  let func = match
    hot_lift_body_result(
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i64()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i64_const(@lib.I64(1L)),
                @lib.Instruction::i64_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i64_const(@lib.I64(4L)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32(0)),
                    @lib.Instruction::return_(),
                  ]),
                ),
                @lib.Instruction::unreachable_(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
        @lib.Instruction::i64_const(@lib.I64(0L)),
        @lib.Instruction::i64_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(1))],
          Some([
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i64_const(@lib.I64(0L)),
            @lib.Instruction::i64_gt_u(),
          ]),
        ),
      ]),
      HotLocals::new(params=[@lib.ValType::i64()], locals=[
        @lib.ValType::i32(),
        @lib.ValType::i64(),
      ]),
      body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
    ) {
    Ok(func) => func
    Err(err) => fail(err.to_string())
  }

  @debug.assert_eq(hot_root_count(func), 2)
  let if_id = hot_root_get(func, 1)
  @debug.assert_eq(hot_node_get(func, if_id).op.to_string(), "If")

  let cond = hot_child_get(func, if_id, 0)
  @debug.assert_eq(hot_node_get(func, cond).op.to_string(), "Compare")
  @debug.assert_eq(
    hot_node_exact_instr(func, cond),
    Some(@lib.Instruction::i64_eq()),
  )

  let lhs = hot_child_get(func, cond, 0)
  let rhs = hot_child_get(func, cond, 1)
  @debug.assert_eq(hot_node_get(func, lhs).op.to_string(), "Block")
  @debug.assert_eq(hot_node_result_arity(func, lhs), 1)
  @debug.assert_eq(hot_node_get(func, rhs).op.to_string(), "Const")
}
