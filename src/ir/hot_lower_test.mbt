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
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
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
  ])
  @lib.Module::new().with_type_sec(type_sec).with_import_sec(import_sec)
}

///|
fn hot_lower_test_triple_chain_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(
          [@lib.ValType::i32(), @lib.ValType::i32()],
          [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
        ),
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
