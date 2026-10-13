///|
fn host_root_scan_fixture(body : Array[@lib.Instruction]) -> @lib.Module {
  @lib.Module::new()
  .with_func_sec(@lib.FuncSec::new(Array::make(6, @lib.TypeIdx::new(0U))))
  .with_code_sec(
    @lib.CodeSec::new(
      [
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
        ..Array::make(
          5,
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        ),
      ],
    ),
  )
}

///|
test "host reference scanner visits every nested control and legacy catch body" {
  // Structural scanner units intentionally isolate reference carriers; these
  // are not whole-module semantic equivalence or validation tests.
  let ref_ = @lib.Instruction::ref_func(@lib.FuncIdx::new(4U))
  let leaf = @lib.Expr::new([ref_])
  let empty = @lib.Expr::new([])
  let bt = @lib.BlockType::void_()
  for
    instr in [
      @lib.Instruction::block(bt, leaf),
      @lib.Instruction::loop_(bt, leaf),
      @lib.Instruction::if_(bt, [ref_], Some([])),
      @lib.Instruction::if_(bt, [], Some([ref_])),
      @lib.Instruction::try_table(bt, [], leaf),
      @lib.Instruction::try_(bt, leaf, []),
      @lib.Instruction::try_(bt, empty, [
        @lib.LegacyCatch::tagged(@lib.TagIdx::new(0U), leaf),
      ]),
      @lib.Instruction::try_(bt, empty, [@lib.LegacyCatch::all(leaf)]),
    ] {
    @debug.assert_eq(
      rume_host_root_prefix(host_root_scan_fixture([instr]), []),
      Some(5),
    )
  }
}

///|
test "host reference scanner visits globals tables elements and active offsets" {
  let base = host_root_scan_fixture([])
  let leaf = @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(4U))])
  let rt = @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func()))
  let global = base.with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::ref_type(rt), false),
        leaf,
      ),
    ]),
  )
  let table = base.with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(rt, @lib.Limits::i32(1U, None)),
        Some(leaf),
      ),
    ]),
  )
  @debug.assert_eq(rume_host_root_prefix(global, []), Some(5))
  @debug.assert_eq(rume_host_root_prefix(table, []), Some(5))
  for
    mode in [
      @lib.ElemMode::passive(),
      @lib.ElemMode::declarative(),
      @lib.ElemMode::active(@lib.TableIdx::new(0U), @lib.Expr::new([])),
    ] {
    for
      kind in [
        @lib.ElemKind::funcs([@lib.FuncIdx::new(4U)]),
        @lib.ElemKind::func_exprs([leaf]),
        @lib.ElemKind::typed_exprs(rt, [leaf]),
      ] {
      let input = base.with_elem_sec(
        @lib.ElemSec::new([@lib.Elem::new(mode, kind)]),
      )
      @debug.assert_eq(rume_host_root_prefix(input, []), Some(5))
    }
  }
  // Ref-valued offsets are deliberately invalid whole-module fixtures. The
  // scanner must still traverse their represented expressions before validation.
  let element_offset = base.with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(@lib.TableIdx::new(0U), leaf),
        @lib.ElemKind::funcs([]),
      ),
    ]),
  )
  let data_offset = base.with_data_sec(
    @lib.DataSec::new([
      @lib.Data::new(@lib.DataMode::active(@lib.MemIdx::new(0U), leaf), b""),
    ]),
  )
  @debug.assert_eq(rume_host_root_prefix(element_offset, []), Some(5))
  @debug.assert_eq(rume_host_root_prefix(data_offset, []), Some(5))
}

///|
test "host reference scanner intentionally rejects exhausted budgets and invalid indices" {
  let input = @lib.Module::new()
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
  @debug.assert_eq(rume_host_root_prefix(input, [], work_limit=3), Some(0))
  @debug.assert_eq(rume_host_root_prefix(input, [], work_limit=2), None)
  let selected = [
    @lib.Export::new(
      @lib.Name::from_string("run"),
      @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
    ),
  ]
  @debug.assert_eq(
    rume_host_root_prefix(input, selected, work_limit=5),
    Some(1),
  )
  @debug.assert_eq(rume_host_root_prefix(input, selected, work_limit=4), None)
  let bad = host_root_scan_fixture([
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0xffffffffU)),
  ])
  @debug.assert_eq(rume_host_root_prefix(bad, []), None)
  let scan = RumeHostRootScan::new(6, 100)
  assert_false(
    scan.body(
      [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(4U))]),
        ),
      ],
      256,
    ),
  )
}
