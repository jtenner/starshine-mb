///|
fn type_reference_scan_fixture(count : Int, body_size : Int) -> @lib.Module {
  let types = Array::make(
    count,
    @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
  )
  let body = Array::make(body_size, @lib.Instruction::nop())
  body.push(
    @lib.Instruction::block(
      @lib.BlockType::type_idx(@lib.TypeIdx::new((count / 2).to_uint())),
      @lib.Expr::new([]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "type pruning scans module roots once and remaps a body-only signature" {
  let input = type_reference_scan_fixture(16, 8)
  @validate.validate_module(input).unwrap()
  let scans = [0]
  let output = dfe_prune_unused_simple_types(input, root_scans=Some(scans))
  @validate.validate_module(output).unwrap()
  let types = match output.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => fail("missing types")
  }
  assert_eq(types.length(), 2)
  let funcs = match output.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => fail("missing code")
  }
  let @lib.Func(_, @lib.Expr(body)) = funcs[0]
  assert_true(
    body[body.length() - 1]
    is @lib.Block(@lib.TypeIdxBlockType(@lib.TypeIdx(1U)), _),
  )
  assert_true(scans[0] <= 1, msg="whole-module root scans: \{scans[0]}")
}

///|
fn type_reference_assert_roots(
  input : @lib.Module,
  expected : Array[Int],
) -> Unit raise {
  let refs : DfeTypeRefs = { live: Array::make(16, false), pending: [], }
  dfe_type_refs_module_roots(input, refs)
  for idx in 0..<16 {
    assert_eq(refs.live[idx], expected.contains(idx))
    let probe : Map[UInt, UInt] = Map([])
    probe[idx.to_uint()] = 16U
    assert_eq(refs.live[idx], dfe_module_type_refs_use_remap(input, probe))
  }
  assert_eq(refs.pending.length(), expected.length())
}

///|
fn type_reference_ref(idx : UInt) -> @lib.RefType {
  @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(idx)))
}

///|
fn type_reference_expr(idx : UInt) -> @lib.Expr {
  @lib.Expr::new([@lib.Instruction::ref_null_type(type_reference_ref(idx))])
}

///|
test "type root collector agrees with probes on declarations and initializer expressions" {
  let input = @lib.Module::new()
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("f"),
          @lib.ExternType::func(@lib.TypeIdx::new(1U)),
        ),
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("tag"),
          @lib.ExternType::tag(@lib.TagType::new(@lib.TypeIdx::new(2U))),
        ),
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("table"),
          @lib.ExternType::table(
            @lib.TableType::new(
              type_reference_ref(3U),
              @lib.Limits::i32(1U, None),
            ),
          ),
        ),
        @lib.Import::new(
          @lib.Name::new("env"),
          @lib.Name::new("global"),
          @lib.ExternType::global(
            @lib.GlobalType::new(
              @lib.ValType::ref_type(type_reference_ref(4U)),
              false,
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(5U)]))
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(6U))]))
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            type_reference_ref(7U),
            @lib.Limits::i32(1U, None),
          ),
          Some(type_reference_expr(8U)),
        ),
      ]),
    )
    .with_global_sec(
      @lib.GlobalSec::new([
        @lib.Global::new(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(type_reference_ref(9U)),
            false,
          ),
          type_reference_expr(10U),
        ),
      ]),
    )
  // Structural reference fixtures isolate collector coverage, not validation.
  type_reference_assert_roots(input, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
}

///|
test "type root collector includes element data offsets and compressed locals" {
  let input = @lib.Module::new()
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(@lib.TableIdx::new(0U), type_reference_expr(1U)),
          @lib.ElemKind::typed_exprs(type_reference_ref(2U), [
            type_reference_expr(3U),
          ]),
        ),
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::func_exprs([type_reference_expr(4U)]),
        ),
      ]),
    )
    .with_data_sec(
      @lib.DataSec::new([
        @lib.Data::new(
          @lib.DataMode::active(@lib.MemIdx::new(0U), type_reference_expr(5U)),
          b"",
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(
            100U,
            @lib.ValType::ref_type(type_reference_ref(6U)),
          ),
          type_reference_expr(7U),
        ),
      ]),
    )
  type_reference_assert_roots(input, [1, 2, 3, 4, 5, 6, 7])
}

///|
test "type root collector includes nested control and handler bodies" {
  let input = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::try_(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
            @lib.Expr::new([
              @lib.Instruction::if_(
                @lib.BlockType::val_type(
                  @lib.ValType::ref_type(type_reference_ref(2U)),
                ),
                [@lib.Instruction::call_ref(@lib.TypeIdx::new(3U))],
                Some([@lib.Instruction::return_call_ref(@lib.TypeIdx::new(4U))]),
              ),
            ]),
            [
              @lib.LegacyCatch::all(
                @lib.Expr::new([
                  @lib.Instruction::loop_(
                    @lib.BlockType::type_idx(@lib.TypeIdx::new(5U)),
                    type_reference_expr(6U),
                  ),
                  @lib.Instruction::try_table(
                    @lib.BlockType::type_idx(@lib.TypeIdx::new(7U)),
                    [],
                    type_reference_expr(8U),
                  ),
                ]),
              ),
            ],
          ),
        ]),
      ),
    ]),
  )
  type_reference_assert_roots(input, [1, 2, 3, 4, 5, 6, 7, 8])
}

///|
test "type pruning follows retained definition dependencies and rewrites every index" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(
                  @lib.ValType::ref_type(type_reference_ref(1U)),
                ),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::ref_type(type_reference_ref(2U))],
              [],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::f64()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(3U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  @validate.validate_module(input).unwrap()
  let output = dfe_prune_unused_simple_types(input)
  @validate.validate_module(output).unwrap()
  assert_eq(output, type_reference_probe_reference(input))
  let types = match output.type_sec {
    Some(@lib.TypeSec(types)) => types
    None => fail("missing types")
  }
  assert_eq(types.length(), 3)
  assert_eq(output.func_sec, Some(@lib.FuncSec::new([@lib.TypeIdx::new(2U)])))
  assert_eq(
    types[1],
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::array(
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(type_reference_ref(0U)),
            ),
            @lib.Mut::const_(),
          ),
        ),
      ),
    ),
  )
}

///|
test "type dependency collector includes supertypes descriptors and embedded definition groups" {
  let rec_type = @lib.RecType::group([
    @lib.SubType::new(
      false,
      [@lib.TypeIdx::new(2U)],
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(
            @lib.ValType::ref_type(type_reference_ref(5U)),
          ),
          @lib.Mut::var_(),
        ),
      ]),
      metadata=@lib.TypeMetadata::new(
        describes=Some(@lib.TypeIdx::new(3U)),
        descriptor=Some(@lib.TypeIdx::new(4U)),
      ),
    ),
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(6U))),
  ])
  let refs : DfeTypeRefs = { live: Array::make(16, false), pending: [], }
  dfe_type_refs_mark_heap_type(
    @lib.HeapType::def_type(@lib.DefType::new(rec_type, 0U)),
    refs,
  )
  for idx in 0..<16 {
    assert_eq(refs.live[idx], idx >= 2 && idx <= 6)
    let probe : Map[UInt, UInt] = Map([])
    probe[idx.to_uint()] = 16U
    assert_eq(refs.live[idx], dfe_rec_type_uses_remap(rec_type, probe))
  }
  assert_eq(refs.pending.length(), 5)
}

///|
test "type root collector agrees with rewrites for GC descriptor cast and call operands" {
  let idx = @lib.TypeIdx::new(3U)
  let other = @lib.TypeIdx::new(7U)
  let field = @lib.U32::new(0U)
  let heap = @lib.HeapType::new(idx)
  let target = @lib.HeapType::new(other)
  let order = @lib.AtomicOrder::seq_cst()
  let cases : Array[(@lib.Instruction, Array[Int])] = [
    (@lib.Instruction::call_ref(idx), [3]),
    (@lib.Instruction::return_call_ref(idx), [3]),
    (@lib.Instruction::struct_new(idx), [3]),
    (@lib.Instruction::struct_new_default(idx), [3]),
    (@lib.Instruction::struct_new_desc(idx), [3]),
    (@lib.Instruction::struct_new_default_desc(idx), [3]),
    (@lib.Instruction::array_new(idx), [3]),
    (@lib.Instruction::array_new_default(idx), [3]),
    (@lib.Instruction::array_get(idx), [3]),
    (@lib.Instruction::array_get_s(idx), [3]),
    (@lib.Instruction::array_get_u(idx), [3]),
    (@lib.Instruction::array_set(idx), [3]),
    (@lib.Instruction::array_fill(idx), [3]),
    (@lib.Instruction::ref_get_desc(idx), [3]),
    (@lib.Instruction::struct_get(idx, field), [3]),
    (@lib.Instruction::struct_get_s(idx, field), [3]),
    (@lib.Instruction::struct_get_u(idx, field), [3]),
    (@lib.Instruction::struct_set(idx, field), [3]),
    (@lib.Instruction::array_new_fixed(idx, field), [3]),
    (@lib.Instruction::struct_atomic_get(order, idx, field), [3]),
    (@lib.Instruction::struct_atomic_get_s(order, idx, field), [3]),
    (@lib.Instruction::struct_atomic_get_u(order, idx, field), [3]),
    (@lib.Instruction::struct_atomic_set(order, idx, field), [3]),
    (@lib.Instruction::array_atomic_get(order, idx), [3]),
    (@lib.Instruction::array_atomic_get_s(order, idx), [3]),
    (@lib.Instruction::array_atomic_get_u(order, idx), [3]),
    (@lib.Instruction::array_atomic_set(order, idx), [3]),
    (@lib.Instruction::ref_test(true, heap), [3]),
    (@lib.Instruction::ref_cast(true, heap), [3]),
    (@lib.Instruction::ref_test_desc(true, heap), [3]),
    (@lib.Instruction::ref_cast_desc_eq(true, heap), [3]),
    (
      @lib.Instruction::struct_atomic_rmw(
        @lib.AggregateAtomicRmwOp::add(),
        idx,
        field,
      ),
      [3],
    ),
    (
      @lib.Instruction::array_atomic_rmw(@lib.AggregateAtomicRmwOp::add(), idx),
      [3],
    ),
    (@lib.Instruction::array_copy(idx, other), [3, 7]),
    (@lib.Instruction::struct_atomic_cmpxchg(idx, field), [3]),
    (@lib.Instruction::array_atomic_cmpxchg(idx), [3]),
    (@lib.Instruction::array_new_data(idx, @lib.DataIdx::new(0U)), [3]),
    (@lib.Instruction::array_init_data(idx, @lib.DataIdx::new(0U)), [3]),
    (@lib.Instruction::array_new_elem(idx, @lib.ElemIdx::new(0U)), [3]),
    (@lib.Instruction::array_init_elem(idx, @lib.ElemIdx::new(0U)), [3]),
    (@lib.Instruction::call_indirect(idx, @lib.TableIdx::new(0U)), [3]),
    (@lib.Instruction::return_call_indirect(idx, @lib.TableIdx::new(0U)), [3]),
    (
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        heap,
        true,
        target,
      ),
      [3, 7],
    ),
    (
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        heap,
        true,
        target,
      ),
      [3, 7],
    ),
    (
      @lib.Instruction::select(
        types=Some([@lib.ValType::ref_type(type_reference_ref(3U))]),
      ),
      [3],
    ),
  ]
  for pair in cases {
    let (instr, expected) = pair
    type_reference_assert_roots(
      @lib.Module::new().with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([instr])),
        ]),
      ),
      expected,
    )
  }
}

///|
test "type pruning preserves NaN initializer bytes while removing unused signatures" {
  let input = pass_test_module_from_wat(
    "(module (type (func)) (type (func (param i32))) (type (func (param i64))) (global f64 f64.const nan:0x123456) (func (type 0)))",
  )
  @validate.validate_module(input).unwrap()
  let output = dfe_prune_unused_simple_types(input)
  @validate.validate_module(output).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 1)
  assert_eq(
    @binary.encode_module(input).unwrap().length() -
    @binary.encode_module(output).unwrap().length(),
    8,
  )
  // Restoring only the original type section must reproduce every input byte,
  // including the NaN payload, global initializer and function body.
  assert_eq(
    @binary.encode_module(output.with_type_sec(input.type_sec.unwrap())).unwrap(),
    @binary.encode_module(input).unwrap(),
  )
}
