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
fn hot_lower_test_struct_module() -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  @lib.Module::new().with_type_sec(@lib.TypeSec::new([struct_type]))
}

///|
fn hot_lower_test_count_substring(text : String, needle : String) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_string() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
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
test "hot lower peels typed wrapper blocks that only branch to the parent" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower peels same-typed payload wrappers that feed a final parent branch" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(9)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(9)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "hot lower peels payload wrappers inside side-effecting parent result blocks" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(9)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
      ]),
    ),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32(9)),
              ]),
            ),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "hot lower peels split payload wrappers with void-if and trailing roots" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (param i32) (result i32) (local i32 i32) (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 1 (i32.const 1)) (if (local.get 0) (then (local.set 1 (i32.const 7)) (br $block8)) (else (local.set 1 (i32.const 9)) (br $block9))) unreachable) (local.get 1)))) (i32.store align=1 (i32.const 0) (local.get 1)) (i32.store align=1 (i32.const 4) (local.get 1)) (return (local.get 1)))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1, None))]),
    )
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block10 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(br $block10"), msg=pretty)
}

///|
test "hot lower preserves carried payload forwarders with trailing values" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 1 (i32.const 1)) (br $block10 (if (result i32) (local.get 0) (then (local.set 1 (i32.const 7)) (br $block8)) (else (local.set 1 (i32.const 9)) (br $block9))))) (local.get 1)))))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_true(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower preserves carried payload forwarders with trailing stores and returns" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 2 (i32.const 1)) (br $block10 (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (br $block8)) (else (local.set 2 (i32.const 9)) (br $block9))))) (local.get 2)))) (i32.store align=1 (i32.const 0) (local.get 2)) (i32.store align=1 (i32.const 4) (local.get 2)) (return (local.get 2)))) (i32.const 0)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1, None))]),
    )
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_true(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower keeps flattened parent-exit payloads unpacked when child exits still target the wrapper" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block $block10 (result i32) (block $block9 (block $block8 (local.set 1 (i32.const 1)) (if (local.get 0) (then (local.set 1 (i32.const 7)) (br $block8)) (else (local.set 1 (i32.const 9)) (br $block9))) unreachable) (br $block10 (local.get 1))))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  assert_eq(
    lowered,
    @lib.Func::new(
      @lib.Locals::from_types([@lib.ValType::i32()]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::i32_const(@lib.I32(1)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::i32_const(@lib.I32(7)),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([
                        @lib.Instruction::i32_const(@lib.I32(9)),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                      ]),
                    ),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "hot lower keeps split parent-exit payload wrappers unpacked when child exits still target the wrapper" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit1 (block $exit0 (if (local.get 0) (then (local.set 2 (i32.const 7)) (br $exit0)) (else (local.set 2 (i32.const 9)) (br $exit1))) unreachable) (br $outer (local.get 2))))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  assert_eq(
    lowered,
    @lib.Func::new(
      @lib.Locals::from_types([@lib.ValType::i32()]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::i32_const(@lib.I32(7)),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                      ],
                      Some([
                        @lib.Instruction::i32_const(@lib.I32(9)),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                      ]),
                    ),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
}

///|
test "hot lower preserves typed result if forwarders that feed return" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (block $block (result i32) (block $block1 (return (if (result i32) (local.get 0) (then (i32.const 7) (br $block)) (else (i32.const 9) (br $block1))))) (i32.const 11))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_true(
    pretty.contains("(if (result i32)") || pretty.contains("(if I32"),
    msg=pretty,
  )
}

///|
test "hot lower preserves typed result if forwarders that feed return after prefix blocks" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (block (block $prefix (br $prefix)) (return (if (result i32) (local.get 0) (then (i32.const 7) (return)) (else (i32.const 9) (return)))))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_true(
    pretty.contains("(if (result i32)") || pretty.contains("(if I32"),
    msg=pretty,
  )
}

///|
test "hot lower repacks split local.set carried values under result blocks" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(5)),
            @lib.Instruction::drop(),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(
    pretty.contains("(block (result i32)") || pretty.contains("(block I32"),
    msg=pretty,
  )
  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
  assert_false(pretty.contains("(local.tee (Local 2))"), msg=pretty)
}

///|
test "hot lower repacks split local.set carried values with store-store-return tails" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (param i32) (result i32) (local i32 i32) (block $outer (result i32) (block $block23 (if (local.get 0) (then (drop (i32.const 5)) (br $block23)) (else (local.set 2 (i32.const 9)) (br $block23))) unreachable) (local.set 1 (local.get 2)) (i32.store align=1 (i32.const 0) (local.get 2)) (i32.store align=1 (i32.const 4) (local.get 2)) (return (local.get 2))) (i32.const 0)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1, None))]),
    )
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(
    pretty.contains("(if (Void)") || pretty.contains("(if Void"),
    msg=pretty,
  )
  assert_true(
    pretty.contains("(block (result i32)") || pretty.contains("(block I32"),
    msg=pretty,
  )
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower peels final typed wrappers with void prefix and local.get tail" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (block (result i32) (block $block5 (local.get 0) drop (br $block5)) (block $block7 (result i32) (local.get 1)))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  assert_eq(
    lowered,
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      ]),
    ),
  )
}

///|
test "hot lower preserves final typed wrappers when the prefix has mixed if exits" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (block $exit (result i32)
    #|      (block $side
    #|        (br $exit
    #|          (block $carry (result i32)
    #|            (block $inner
    #|              (br $carry
    #|                (if (result i32)
    #|                  (local.get 0)
    #|                  (then
    #|                    (local.set 1
    #|                      (local.get 1))
    #|                    (br $inner))
    #|                  (else
    #|                    (local.set 0
    #|                      (i32.const 3))
    #|                    (br $side)))))
    #|            (local.get 1))))
    #|      (i32.const 7)))))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
}

///|
test "hot lower preserves final typed wrappers with same-typed branch-payload tails" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (block (result i32) (block $block5 (local.get 0) drop (br $block5)) (block $block7 (result i32) (block $block6 (br $block7 (if (result i32) (local.get 0) (then (i32.const 7) (br $block6)) (else (i32.const 9) (br $block7)))))))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if Void"), msg=pretty)
}

///|
test "hot lower preserves nested split local.set carried values without extra result blocks" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(@lib.I32(5)),
                @lib.Instruction::drop(),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ],
              Some([
                @lib.Instruction::i32_const(@lib.I32(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(
    pretty.contains("(block (Void)") || pretty.contains("(block Void"),
    msg=pretty,
  )
  assert_false(pretty.contains("(drop\n"), msg=pretty)
  assert_false(pretty.contains("(block\n   (block $"), msg=pretty)
}

///|
test "hot lower peels same-typed nested if wrappers when inner label is unused" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              ],
              Some([@lib.Instruction::i32_const(@lib.I32(9))]),
            ),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([@lib.Instruction::i32_const(@lib.I32(9))]),
            ),
          ]),
        ),
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower peels escaping wrapper blocks and trims dead tails" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(8)),
      ]),
    ),
    @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower peels pure typed wrappers used as ref children" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(struct_ref_type),
      @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
    ),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower stackifies wrapped struct.set value prefixes through a scratch ref local" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(7)),
      ]),
    ),
    @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type, struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(struct_ref_type),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower keeps trailing if conditions outside wrapped struct.set scratch blocks" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(7))],
          Some([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
      ]),
    ),
    @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type, struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(struct_ref_type),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(7))],
          Some([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
        @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower materializes unreachable tails after loop exits to the parent block" {
  let struct_ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(8)),
      ]),
    ),
    @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(locals=[struct_ref_type]),
    hot_module_context_from_module(hot_lower_test_struct_module()),
    body_result_type=@lib.BlockType::val_type(struct_ref_type),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([struct_ref_type]),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::loop_(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(7)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ]),
    ),
  )
}

///|
test "hot lower keeps terminal unreachable after self-looping loop bodies" {
  let body = @lib.Expr::new([
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )

  assert_eq(hot_lower_body(hot), body)
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
fn hot_lower_test_void_block_param_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
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
fn hot_lower_test_single_param_multi_result_loop_module() -> @lib.Module {
  let type_sec = @lib.TypeSec::new([
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32()], [
          @lib.ValType::i32(),
          @lib.ValType::i64(),
        ]),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
      ),
    ),
  ])
  @lib.Module::new().with_type_sec(type_sec)
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
test "hot lower canonicalizes typed loop entry values without redundant tees" {
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

  assert_eq(
    hot_lower_body(hot),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::loop_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([]),
      ),
    ]),
  )
}

///|
test "hot lower spills transparent typed single-param void blocks through a second scratch local" {
  let module_ = hot_lower_test_void_block_param_module()
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([@lib.Instruction::drop()]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(),
    hot_module_context_from_module(module_),
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower preserves typed loop const-prefix carriers when merge-blocks wants Binaryen-stable spills" {
  let module_ = hot_lower_test_block_param_module()
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_add(),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(),
    hot_module_context_from_module(module_),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let lowered = hot_lower_func_with_options(
    hot,
    HotLowerOptions::new(preserve_typed_loop_const_prefix_spills=true),
  )
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::loop_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
        ]),
      ),
    ]),
  )
}

///|
test "hot lower preserves typed multi-result loop const-prefix carriers when merge-blocks wants Binaryen-stable spills" {
  let module_ = hot_lower_test_single_param_multi_result_loop_module()
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(4)),
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new([
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i64_const(@lib.I64(2L)),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(),
    hot_module_context_from_module(module_),
    body_result_type=@lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
  )
  let lowered = hot_lower_func_with_options(
    hot,
    HotLowerOptions::new(preserve_typed_loop_const_prefix_spills=true),
  )
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [
              @lib.ValType::i32(),
              @lib.ValType::i64(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i64()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_eq(hot_lower_test_count_substring(pretty, "local.set"), 2, msg=pretty)
  assert_eq(hot_lower_test_count_substring(pretty, "local.get"), 2, msg=pretty)
  assert_eq(hot_lower_test_count_substring(pretty, "drop"), 1, msg=pretty)
  assert_eq(hot_lower_test_count_substring(pretty, "i32.const"), 2, msg=pretty)
  assert_eq(hot_lower_test_count_substring(pretty, "i64.const"), 1, msg=pretty)
}

///|
test "hot lower rewrites typed multi-result loop if-arm carriers to result-only loop types when merge-blocks wants Binaryen-stable spills" {
  let body = @lib.Expr::new([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new([
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i64_const(@lib.I64(2L)),
          ]),
        ),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new([
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i64_const(@lib.I64(4L)),
          ]),
        ),
      ]),
    ),
  ])
  let hot = hot_lift_body_with_context(
    body,
    HotLocals::new(params=[@lib.ValType::i32()]),
    hot_module_context_from_module(
      hot_lower_test_single_param_multi_result_loop_module(),
    ),
    body_result_type=@lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
  )
  let lowered = hot_lower_func_with_options(
    hot,
    HotLowerOptions::new(preserve_typed_loop_const_prefix_spills=true),
  )
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::if_(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
        [
          @lib.Instruction::i32_const(@lib.I32(4)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::loop_(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
            @lib.Expr::new([
              @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(1)),
              @lib.Instruction::i64_const(@lib.I64(2L)),
            ]),
          ),
        ],
        Some([
          @lib.Instruction::i32_const(@lib.I32(8)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
          @lib.Instruction::loop_(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
            @lib.Expr::new([
              @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
              @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
              @lib.Instruction::drop(),
              @lib.Instruction::i32_const(@lib.I32(3)),
              @lib.Instruction::i64_const(@lib.I64(4L)),
            ]),
          ),
        ]),
      ),
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
test "hot lower canonicalizes tail if forwarders into void if plus unreachable" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (local.set 2
    #|      (block $outer (result i32)
    #|        (block $exit
    #|          (br $outer
    #|            (block $mid (result i32)
    #|              (block $cont
    #|                (if (result i32)
    #|                  (local.get 0)
    #|                  (then
    #|                    (i32.const 7)
    #|                    (local.set 1)
    #|                    (br $cont))
    #|                  (else
    #|                    (i32.const 9)
    #|                    (local.set 1)
    #|                    (br $exit))))
    #|              (local.get 1)))))
    #|    (local.get 2))))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower preserves nested local.set payload forwarders from compare shape" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.set 1
    #|      (block $block11 (result i32)
    #|        (block $block9
    #|          (br $block11
    #|            (block $block10 (result i32)
    #|              (block $block8
    #|                (br $block10
    #|                  (if (result i32)
    #|                    (local.get 0)
    #|                    (then
    #|                      (i32.const 7)
    #|                      (local.set 1)
    #|                      (br $block8))
    #|                    (else
    #|                      (i32.const 9)
    #|                      (local.set 1)
    #|                      (br $block9)))))
    #|              (local.get 1))))
    #|    (local.get 1)))))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
}

///|
test "hot lower preserves prefix-heavy nested local.set payload forwarders from compare shape" {
  let source =
    #|(module
    #|  (func (param i32 i32 i32) (result i32) (local i32 i32)
    #|    (local.set 3
    #|      (block $block11 (result i32)
    #|        (block $block9
    #|          (br $block11
    #|            (block $block10 (result i32)
    #|              (block $block8
    #|                (local.set 4 (local.get 0))
    #|                (drop (local.get 1))
    #|                (drop (local.get 2))
    #|                (br $block10
    #|                  (if (result i32)
    #|                    (local.get 2)
    #|                    (then
    #|                      (local.set 4 (i32.const 7))
    #|                      (br $block8))
    #|                    (else
    #|                      (local.set 4 (i32.const 9))
    #|                      (br $block9)))))
    #|              (local.get 4))))
    #|    (local.get 3)))))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
}

///|
test "hot lower repacks split local.set carry blocks from compare shape" {
  let source =
    #|(module
    #|  (func (param i64) (result i32) (local i32 i32 i64 i32)
    #|    (local.set 1
    #|      (block $block24 (result i32)
    #|        (block $block23
    #|          (if
    #|            (i64.eq
    #|              (local.tee 3
    #|                (local.get 0))
    #|              (i64.const 4294967296))
    #|            (then
    #|              (drop
    #|                (i32.const 5))
    #|              (br $block23))
    #|            (else
    #|              (local.set 2
    #|                (local.tee 4
    #|                  (i32.wrap_i64
    #|                    (local.tee 3
    #|                      (local.get 3)))))
    #|              (br $block23)))
    #|          unreachable)
    #|        (local.get 2)))
    #|    (local.get 1)))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(hot)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i64()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    pretty.contains("(block (result i32)") || pretty.contains("(block I32"),
    msg=pretty,
  )
  assert_true(pretty.contains("(if I32"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
  assert_false(pretty.contains("(local.tee (Local 2))"), msg=pretty)
}

///|
test "hot lower preserves packed local.set carry blocks" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local.set 2 (block $outer (result i32) (block $mid (br $outer (block (result i32) (block $cont (if (local.get 0) (then (local.set 2 (local.get 1)) (br $cont)) (else (local.set 2 (i32.const 9)) (br $mid)))) (local.get 2)))) (i32.const 1))) (local.get 2)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(br (Label 1))"), msg=pretty)
  assert_true(pretty.contains("(br (Label 3))"), msg=pretty)
  assert_false(pretty.contains("(br (Label 2))"), msg=pretty)
}

///|
test "hot lower keeps nested escaping-if unreachable sentinels" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (memory 1) (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) (local i32) local.get 0 call 0 local.get 1 call 0 i32.eq if loop local.get 0 call 0 local.get 2 i32.gt_s if local.get 0 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 local.get 1 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 i32.eq if local.get 2 i32.const 1 i32.add local.set 2 br 2 else i32.const 0 return end unreachable else i32.const 1 return end unreachable end unreachable else i32.const 0 return end unreachable))",
    code_idx=1,
  )
  let lowered = ir_test_assert_verify_and_lower(fixture)
  let pretty = lowered.pretty_print_func(@lib.FuncIdx::new(1U))

  assert_eq(
    hot_lower_test_count_substring(pretty, "unreachable"),
    4,
    msg=pretty,
  )
  assert_true(pretty.contains("(br (Label 2))"), msg=pretty)
}

///|
test "hot lower repacks prefix-heavy split local.set carry blocks" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32) (local.set 3 (block $block2 (result i32) (block $block1 (block $block (local.set 4 (local.get 0)) (drop (local.get 1)) (drop (local.get 2)) (if (local.get 2) (then (local.set 4 (i32.const 7)) (br $block)) (else (local.set 4 (i32.const 9)) (br $block1))) unreachable) (local.get 4) (br $block2)) (local.get 3))) (local.get 3)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 4))"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 3))"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower preserves mixed-depth result if escapes without inserting a typed carrier" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i64 i32 i32) (block $outer (block $inner (local.get 0) (if (result i32) (then (i32.const 7) (local.set 3) (br $inner)) (else (i64.const 9) (local.set 2) (br $outer))) return) (local.get 1) (local.set 4) (local.get 4) return) (i32.const 0)))",
  )
  let validated = ir_test_assert_verify_and_lower(fixture)
  let pretty = validated.pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("(local.set (Local 4))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 1))"), msg=pretty)
  assert_false(pretty.contains("(block (I32)"), msg=pretty)
}

///|
test "hot lower keeps wrapped local.set prefixes void when child exits still target the parent" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (block $mid (local.get 0) (if (then (local.get 1) (if (then (i32.const 7) (local.set 2) (br $mid)) (else (br $outer))) unreachable) (else (br $outer))) unreachable) (local.get 2) (local.set 1) (local.get 1) return) (i32.const 0)))",
  )
  let validated = ir_test_assert_verify_and_lower(fixture)
  let pretty = validated.pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("(block (I32)"), msg=pretty)
}

///|
test "hot lower peels nested br payload blocks with unreachable child payloads" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(i32.const I32(0))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower avoids wrapping parent-exit payloads in extra result blocks" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))

  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(br (Label 1))"), msg=pretty)
  assert_true(pretty.contains("(br (Label 2))"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "hot lower keeps mixed-exit parent payload wrappers stable across reroundtrip" {
  let source = "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))"
  let fixture = ir_test_build_hot_from_wat(source)
  let first = hot_lower_func(fixture.hot_func)
  let first_mod = fixture.mod_.with_code_sec(@lib.CodeSec::new([first]))
  match @validate.validate_module(first_mod) {
    Ok(_) => ()
    Err(err) => fail("expected first lower to validate, got \{err}")
  }
  let first_code = match first_mod.code_sec {
    Some(@lib.CodeSec(defs)) => defs[0]
    None => abort("expected lowered module code section")
  }
  let second = hot_lower_func(hot_lift_func(first_mod, @lib.FuncIdx::new(0U)))

  assert_eq(
    second,
    first_code,
    msg="first:\n\{first_code.to_string()}\n\nsecond:\n\{second.to_string()}",
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
test "hot lower collapses dead local.tee roots into local.set" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let hot = hot_lift_body(body, HotLocals::new(locals=[@lib.ValType::i32()]))
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ]),
  )
}

///|
test "hot lower preserves local.tee roots with dead drops when a later local.get reads the local" {
  let body = @lib.Expr::new([
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
  let hot = hot_lift_body(body, HotLocals::new(locals=[@lib.ValType::i32()]))
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower strips redundant nop roots during canonicalization" {
  let body = @lib.Expr::new([
    @lib.Instruction::nop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::nop(),
  ])
  let hot = hot_lift_body(body, HotLocals::new(param_count=1))
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, lowered_body) = lowered

  assert_eq(locals, @lib.Locals::from_types([]))
  assert_eq(
    lowered_body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "hot lower drops dead nested local.tee instructions" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (result i32) (local i32) i32.const 7 local.tee 0 i32.const 0 i32.gt_s if nop end i32.const 1))",
  )
  let validated = ir_test_assert_verify_and_lower(fixture)
  let pretty = validated.pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("i32.gt_s"), msg=pretty)
}

///|
test "hot lower drops dead nested local.tee instructions despite unreachable gets" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (result i32) (local i32) i32.const 7 local.tee 0 block unreachable local.get 0 drop end i32.const 1))",
  )
  let validated = ir_test_assert_verify_and_lower(fixture)
  let pretty = validated.pretty_print_func(@lib.FuncIdx::new(0U))

  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
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
test "hot lower roundtrips branch-exit triple-result temp copy chains" {
  let source =
    #|(module
    #|  (type (func (result i32 i32 i32)))
    #|  (func (type 0) (result i32 i32 i32)
    #|    (i32.const 10)
    #|    (i32.const 20)
    #|    (i32.const 30))
    #|  (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $exit (result i32)
    #|      (if
    #|        (local.get 0)
    #|        (then
    #|          (call 0)
    #|          (local.set 4)
    #|          (local.set 3)
    #|          (local.set 2)
    #|          (local.set 7 (local.get 4))
    #|          (local.set 6 (local.get 3))
    #|          (local.set 1 (local.get 2))
    #|          (local.set 5 (local.get 7))
    #|          (local.set 0 (local.get 6))
    #|          (br $exit (local.get 5))))
    #|      (i32.const 99))))
  let module_ = match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("expected module to parse, got \{err}")
  }
  let hot = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let lowered = hot_lower_func(hot)
  let expected = module_.pretty_print_defined_func(1U)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
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
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::i32_const(@lib.I32(20)),
            @lib.Instruction::i32_const(@lib.I32(30)),
          ]),
        ),
        lowered,
      ]),
    )
    .pretty_print_func(@lib.FuncIdx::new(1U))

  assert_eq(pretty, expected)
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
test "hot lower keeps wrapped prefix local.get carriers when they are read again later" {
  let body = @lib.Expr::new([
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let hot = hot_lift_body(
    body,
    HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
    body_result_type=@lib.BlockType::void_(),
  )

  assert_eq(
    hot_lower_func(hot),
    @lib.Func::new(
      @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
      body,
    ),
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
