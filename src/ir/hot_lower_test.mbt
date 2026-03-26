///|
fn hot_lower_test_memarg() -> @lib.MemArg {
  @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
}

///|
fn hot_lower_test_context_module() -> @lib.Module {
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
test "hot lower roundtrips representative exact-payload families" {
  let memarg = hot_lower_test_memarg()
  let body = @lib.Expr::new([
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
  ])
  let func = hot_lift_body_with_context(
    body,
    HotLocals::new(),
    hot_module_context_from_module(hot_lower_test_context_module()),
  )

  assert_eq(hot_lower_body(func), body)
}

///|
test "hot lower roundtrips branches through label metadata" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(9)),
      ]),
    ),
    @lib.Instruction::return_(),
  ])
  let func = hot_lift_body(
    body,
    HotLocals::new(params=[@lib.ValType::i32()]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(hot_lower_body(func), body)
}

///|
test "hot lower preserves result-only loop fallthrough values" {
  let body = @lib.Expr::new([
    @lib.Instruction::loop_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
    ),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  let lowered = hot_lower_func(hot)

  assert_eq(lowered, @lib.Func::new(@lib.Locals::from_types([]), body))
}

///|
fn hot_lower_test_deep_branch_body(depth : Int) -> @lib.Expr {
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
test "hot lower roundtrips deep nested branch label stacks" {
  let body = hot_lower_test_deep_branch_body(64)
  let hot = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(hot_lower_body(hot), body)
}

///|
fn hot_lower_test_func_module() -> @lib.Module {
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
fn hot_lower_test_block_param_module() -> @lib.Module {
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
fn hot_lower_test_multi_result_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
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
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new([
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
            Some([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn hot_lower_test_triple_result_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
          @lib.ValType::i32(),
          @lib.ValType::i32(),
        ]),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("triple"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lower_test_plain_triple_result_module() -> @lib.Module {
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
  ])
  @lib.Module::new().with_type_sec(type_sec)
}

///|
fn hot_lower_test_triple_to_pair_module() -> @lib.Module {
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
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32(), @lib.ValType::i32()],
        ),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("finish"),
      @lib.ExternType::func(@lib.TypeIdx::new(2U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lower_test_loop_bridge_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32(), @lib.ValType::i32()],
        ),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("finish"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lower_test_triple_block_loop_bridge_module() -> @lib.Module {
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
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec)
}

///|
fn hot_lower_test_triple_chain_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
          @lib.ValType::i32(),
          @lib.ValType::i32(),
          @lib.ValType::i32(),
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32()],
        ),
      ),
    ),
  ])
  let import_sec = @lib.ImportSec::new([
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("triple"),
      @lib.ExternType::func(@lib.TypeIdx::new(0U)),
    ),
    @lib.Import::new(
      @lib.Name::from_string("env"),
      @lib.Name::from_string("finish"),
      @lib.ExternType::func(@lib.TypeIdx::new(1U)),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
test "hot lower func restores declared locals and body" {
  let module_ = hot_lower_test_func_module()
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower keeps typed loop entry values outside the loop" {
  let module_ = hot_lower_test_block_param_module()
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([@lib.Instruction::local_tee(@lib.LocalIdx::new(0U))]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[@lib.ValType::i32()]),
    hot_module_context_from_module(module_),
  )

  assert_eq(hot_lower_body(hot), body)
}

///|
test "hot lower roundtrips multi-result producers consumed across instructions" {
  let module_ = hot_lower_test_multi_result_module()
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
        Some([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
    ]),
  )
}

///|
test "hot lower preserves result blocks consumed by local.set" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(locals=[@lib.ValType::i32()]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower does not reintroduce dead drops after non-fallthrough block exits" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(param_count=1, locals=[]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(locals, @lib.Locals::from_types([]))
  assert_false(
    lowered_body.to_string().contains("drop"),
    msg=lowered_body.to_string(),
  )
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves result blocks consumed by local.tee and later local.gets" {
  let memarg = hot_lower_test_memarg()
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(16)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
    hot_module_context_from_module(hot_lower_test_context_module()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(16)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower preserves branchy result blocks consumed by local.tee and later local.gets" {
  let memarg = hot_lower_test_memarg()
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(@lib.I32(16)),
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              ],
              None,
            ),
            @lib.Instruction::i32_const(@lib.I32(20)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
    hot_module_context_from_module(hot_lower_test_context_module()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(16)),
                  @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                ],
                None,
              ),
              @lib.Instruction::i32_const(@lib.I32(20)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower preserves repeated local.get consumers after block-fed local.tee" {
  let memarg = hot_lower_test_memarg()
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(16)),
        @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_load(memarg),
    @lib.Instruction::drop(),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_context_module()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(16)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ]),
      ),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_load(memarg),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower preserves local.set fed by unreachable typed block results" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::return_(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::drop(),
      ],
      None,
    ),
    @lib.Instruction::i32_const(@lib.I32(0)),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(locals=[@lib.ValType::i32()]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::return_(),
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(9))]),
          ),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
        ],
        None,
      ),
      @lib.Instruction::i32_const(@lib.I32(0)),
    ]),
  )
}

///|
test "hot lower preserves multi-result calls after branchy block exits" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[@lib.ValType::i32()]),
    hot_module_context_from_module(hot_lower_test_multi_result_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves triple-result calls after polymorphic inner exits" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::drop(),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32(11)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(10000)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::drop(),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_triple_result_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ],
                Some([
                  @lib.Instruction::i32_const(@lib.I32(11)),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                ]),
              ),
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(10000)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves local.tee-fed triple-result consumers after inner exits" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::drop(),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32(11)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(10000)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_triple_chain_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32(0)),
              @lib.Instruction::if_(
                @lib.BlockType::void_(),
                [
                  @lib.Instruction::i32_const(@lib.I32(0)),
                  @lib.Instruction::drop(),
                ],
                Some([
                  @lib.Instruction::i32_const(@lib.I32(11)),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  @lib.Instruction::br(@lib.LabelIdx::new(0U)),
                ]),
              ),
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::br(@lib.LabelIdx::new(1U)),
            ]),
          ),
          @lib.Instruction::i32_const(@lib.I32(10000)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves triple-result local.set chains after removing leading nop from then region" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::nop(),
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
      ],
      Some([@lib.Instruction::i32_const(@lib.I32(99))]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_plain_triple_result_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let if_id = hot_root_get(hot, 0)
  let then_region = hot_region_then_ref(hot, if_id)
  let removed = hot_region_remove(hot, then_region, 0, 1)
  for node_id in removed {
    hot_delete_node(hot, node_id)
  }
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [
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
        ],
        Some([@lib.Instruction::i32_const(@lib.I32(99))]),
      ),
    ]),
  )
}

///|
test "hot lower preserves branchy triple-result bridges after removing leading nop from then region" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [
        @lib.Instruction::nop(),
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
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(99)),
        @lib.Instruction::i32_const(@lib.I32(100)),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_triple_to_pair_module()),
    body_result_type=@lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
  )
  let if_id = hot_root_get(hot, 0)
  let then_region = hot_region_then_ref(hot, if_id)
  let removed = hot_region_remove(hot, then_region, 0, 1)
  for node_id in removed {
    hot_delete_node(hot, node_id)
  }
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::if_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        [
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
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ],
        Some([
          @lib.Instruction::i32_const(@lib.I32(99)),
          @lib.Instruction::i32_const(@lib.I32(100)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves typed loop bridge roots after removing leading nop from loop body" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::i32_const(@lib.I32(20)),
    @lib.Instruction::i32_const(@lib.I32(30)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::nop(),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_loop_bridge_module()),
    body_result_type=@lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
  )
  let loop_id = hot_root_get(hot, hot_root_count(hot) - 1)
  let loop_body = hot_region_body_ref(hot, loop_id)
  let removed = hot_region_remove(hot, loop_body, 0, 1)
  for node_id in removed {
    hot_delete_node(hot, node_id)
  }
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::i32_const(@lib.I32(20)),
      @lib.Instruction::i32_const(@lib.I32(30)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves multi-result block values carried into typed loops" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::i32_const(@lib.I32(30)),
      ]),
    ),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new([@lib.Instruction::drop(), @lib.Instruction::drop()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[@lib.ValType::i32()]),
    hot_module_context_from_module(
      hot_lower_test_triple_block_loop_bridge_module(),
    ),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(10)),
          @lib.Instruction::i32_const(@lib.I32(20)),
          @lib.Instruction::i32_const(@lib.I32(30)),
        ]),
      ),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        @lib.Expr::new([@lib.Instruction::drop(), @lib.Instruction::drop()]),
      ),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower preserves multi-result local.tee bridges feeding later local.set chains" {
  let body = @lib.Expr::new([
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
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_plain_triple_result_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
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
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower preserves early local.tee bridges before later sibling local.set chains" {
  let body = @lib.Expr::new([
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
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    hot_module_context_from_module(hot_lower_test_plain_triple_result_module()),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    body,
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
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower drops dead non-final multi-result roots after mutation" {
  let hot = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  hot_body_result_type_set(hot, hot_type_intern_value(hot, @lib.ValType::i32()))
  let call = hot_build_call(
    hot,
    0,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let const7 = hot_build_const_i32(hot, @lib.I32(7))
  let set0 = hot_build_local_set(hot, 0, const7)
  let const99 = hot_build_const_i32(hot, @lib.I32(99))
  hot_root_append(hot, call)
  hot_root_append(hot, set0)
  hot_root_append(hot, const99)
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::drop(),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_const(@lib.I32(99)),
    ]),
  )
}

///|
test "hot lower drops partially dead multi-result roots after mutation" {
  let hot = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  hot_body_result_type_set(hot, hot_type_intern_value(hot, @lib.ValType::i32()))
  let call = hot_build_call(
    hot,
    0,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [],
  )
  let set0 = hot_build_local_set(hot, 0, call)
  hot_root_append(hot, call)
  hot_root_append(hot, set0)
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    ]),
  )
}
