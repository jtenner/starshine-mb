///|
fn rume_perf_repeated_indirect_call_fixture(
  candidate_count : Int,
  call_count : Int,
) -> @lib.Module {
  let type_idx = @lib.TypeIdx::new(0U)
  let func_types : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let elem_funcs : Array[@lib.FuncIdx] = []
  let root_body : Array[@lib.Instruction] = []
  let mut func_idx = 0
  while func_idx <= candidate_count {
    func_types.push(type_idx)
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    )
    if func_idx > 0 {
      elem_funcs.push(@lib.FuncIdx::new(func_idx.reinterpret_as_uint()))
    }
    func_idx += 1
  }
  let mut call_idx = 0
  while call_idx < call_count {
    root_body.push(@lib.Instruction::i32_const(@lib.I32(0)))
    root_body.push(
      @lib.Instruction::call_indirect(type_idx, @lib.TableIdx::new(0U)),
    )
    call_idx += 1
  }
  funcs[0] = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(root_body))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new(func_types))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
          @lib.Limits::i32(candidate_count.reinterpret_as_uint(), None),
        ),
        None,
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("root"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
        ),
        @lib.ElemKind::funcs(elem_funcs),
      ),
    ]),
  )
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "RUME scans repeated identical indirect-call candidates once" {
  let candidate_count = 64
  let candidate_visits = [0]
  ignore(
    rume_collect_liveness_with_import_parent_policy(
      rume_perf_repeated_indirect_call_fixture(candidate_count, 32),
      true,
      indirect_candidate_visits=Some(candidate_visits),
    ),
  )
  @debug.assert_eq(candidate_visits[0], candidate_count)
}

///|
fn rume_perf_direct_type_root_fixture(
  rooted_type_count : Int,
  total_type_count : Int,
) -> @lib.Module {
  let rec_types : Array[@lib.RecType] = []
  let func_types : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  let mut type_idx = 0
  while type_idx < total_type_count {
    rec_types.push(
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    )
    type_idx += 1
  }
  type_idx = 0
  while type_idx < rooted_type_count {
    func_types.push(@lib.TypeIdx::new(type_idx.reinterpret_as_uint()))
    funcs.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    )
    type_idx += 1
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(rec_types))
  .with_func_sec(@lib.FuncSec::new(func_types))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
test "RUME proves directly rooted type sections without body scans" {
  @debug.assert_eq(
    rume_direct_func_roots_cover_all_types(
      rume_perf_direct_type_root_fixture(64, 64),
    ),
    true,
  )
  @debug.assert_eq(
    rume_direct_func_roots_cover_all_types(
      rume_perf_direct_type_root_fixture(63, 64),
    ),
    false,
  )
}

///|
test "RUME closes type dependencies with one visit per type" {
  let type_count = 64
  let rec_types : Array[@lib.RecType] = []
  let mut type_idx = 0
  while type_idx < type_count {
    rec_types.push(
      @lib.RecType::new(
        @lib.SubType::new(
          false,
          if type_idx == 0 {
            []
          } else {
            [@lib.TypeIdx::new((type_idx - 1).reinterpret_as_uint())]
          },
          @lib.CompType::func([], []),
        ),
      ),
    )
    type_idx += 1
  }
  let used_types = @bitset.BitSet::new(type_count)
  used_types[type_count - 1] = true
  let dependency_visits = [0]
  rume_close_type_dependencies(
    used_types,
    rec_types,
    dependency_type_visits=Some(dependency_visits),
  )
  @debug.assert_eq(dependency_visits[0], type_count)
  @debug.assert_eq(rume_all_true(used_types), true)
}

///|
test "RUME remaps a kept subtype after an unused sibling" {
  let base = @lib.CompType::func([], [])
  let child = @lib.CompType::func([], [])
  let module_ = @lib.Module::new().with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(@lib.SubType::new(false, [], base)),
      @lib.RecType::new(@lib.SubType::new(true, [@lib.TypeIdx::new(2U)], child)),
      @lib.RecType::new(@lib.SubType::new(true, [@lib.TypeIdx::new(2U)], child)),
    ]),
  )
  let used_types = @bitset.BitSet::new(5)
  used_types[0] = true
  used_types[2] = true
  used_types[4] = true
  let remap = rume_build_type_remap(used_types)
  // This check proves that the dense map moves old type 2 to new type 1.
  @debug.assert_eq(remap.get(2U), Some(1U))
  // This check proves that the shared rewrite helper uses the dense map.
  @debug.assert_eq(
    dfe_rewrite_type_idx(@lib.TypeIdx::new(2U), remap),
    @lib.TypeIdx::new(1U),
  )
  let compacted = rume_compact_type_sec(
    module_,
    precomputed_used_types=Some(used_types),
  )
  match compacted.type_sec {
    Some(
      @lib.TypeSec(
        [
          _,
          _,
          @lib.SingleRecType(@lib.SubType(_, [@lib.TypeIdx(super_type)], _, _)),
        ]
      )
    ) =>
      // This check proves that type-section rebuild uses rewritten types.
      @debug.assert_eq(super_type, 1U)
    _ => fail("expected one remapped kept subtype")
  }
}

///|
test "RUME type compaction remaps retained type and field names" {
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        type_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("dead")),
            @lib.NameAssoc::new(2U, @lib.Name::from_string("live")),
          ]),
        ),
        field_names=Some(
          @lib.IndirectNameMap::new([
            @lib.IndirectNameAssoc::new(
              2U,
              @lib.NameMap::new([
                @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
              ]),
            ),
          ]),
        ),
      ),
    )
  let used_types = @bitset.BitSet::new(3)
  used_types[1] = true
  used_types[2] = true
  let compacted = rume_compact_type_sec(
    module_,
    precomputed_used_types=Some(used_types),
  )
  match @validate.validate_module(compacted) {
    Ok(_) => ()
    Err(err) => fail("expected compacted named types to validate, got \{err}")
  }
  let names = compacted.name_sec.unwrap()
  @debug.assert_eq(
    names.type_names,
    Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(1U, @lib.Name::from_string("live")),
      ]),
    ),
  )
  @debug.assert_eq(
    names.field_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          1U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
          ]),
        ),
      ]),
    ),
  )
}

///|
fn rume_named_reference_only_func_fixture() -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("root"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::declarative(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::void_(),
            @lib.Expr::new([@lib.Instruction::nop()]),
          ),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      label_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("stale")),
            ]),
          ),
        ]),
      ),
    ),
  )
}

///|
test "RUME drops label names when reference-only bodies are nullified" {
  let optimized = rume_run_module_pass(
    rume_named_reference_only_func_fixture(),
    closed_world=true,
  )
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, body), _])) =>
      @debug.assert_eq(body, @lib.Expr::new([@lib.Instruction::unreachable_()]))
    _ => fail("expected reference-only callee plus exported root")
  }
  @debug.assert_eq(optimized.name_sec, None)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nullified named function to validate, got \{err}")
  }
}
