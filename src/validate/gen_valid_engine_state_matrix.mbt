///|
fn gen_valid_engine_state_linked_resource_imports() -> Array[Import] {
  [
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_global_i32"),
      ExternType::global(GlobalType::new(ValType::i32(), true)),
    ),
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_memory"),
      ExternType::mem(MemType::new(Limits::i32(1U, Some(2U)))),
    ),
    Import::new(
      Name::from_string("__link"),
      Name::from_string("state_table"),
      ExternType::table(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(8U)),
        ),
      ),
    ),
  ]
}

///|
fn gen_valid_engine_state_linked_resource_exports() -> Array[Export] {
  [
    Export::new(
      Name::from_string("state_global_i32"),
      ExternIdx::global(GlobalIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("state_memory"),
      ExternIdx::mem(MemIdx::new(0U)),
    ),
    Export::new(
      Name::from_string("state_table"),
      ExternIdx::table(TableIdx::new(0U)),
    ),
  ]
}

///|
fn gen_valid_engine_state_link_graph_relay_module() -> Module {
  Module::new()
  .with_import_sec(
    ImportSec::new(gen_valid_engine_state_linked_resource_imports()),
  )
  .with_export_sec(
    ExportSec::new(gen_valid_engine_state_linked_resource_exports()),
  )
}

///|
pub fn gen_valid_engine_state_link_graph_support_modules(
  seed : UInt64,
) -> Array[Module] {
  let support = [gen_valid_engine_state_cross_instance_support_module(seed)]
  let relay_count = (seed % 3UL).to_int()
  for _ in 0..<relay_count {
    support.push(gen_valid_engine_state_link_graph_relay_module())
  }
  support
}

///|
fn gen_valid_engine_state_link_graph_consumer_module(seed : UInt64) -> Module {
  gen_valid_engine_state_cross_instance_module(seed ^ 0x4c494e4bUL)
}

///|
fn gen_valid_engine_state_initialization_graph_module(seed : UInt64) -> Module {
  let constant = gen_valid_engine_state_seed_i32(seed, 201UL)
  let imported_const = Import::new(
    Name::from_string("__fuzz"),
    Name::from_string("const_i32"),
    ExternType::global(GlobalType::new(ValType::i32(), false)),
  )
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_get(GlobalIdx::new(2U)),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4100))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(32)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(7)),
    Instruction::memory_init(DataIdx::new(1U), MemIdx::new(0U)),
    Instruction::data_drop(DataIdx::new(1U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(0)),
    Instruction::i32_const(I32(1)),
    Instruction::table_init(ElemIdx::new(1U), TableIdx::new(0U)),
    Instruction::elem_drop(ElemIdx::new(1U)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(310, [
      Instruction::global_get(GlobalIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(311, [
      Instruction::global_get(GlobalIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(312, [
      Instruction::global_get(GlobalIdx::new(2U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(313, [
      Instruction::i32_const(I32(32)),
      Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(314, [
      Instruction::i32_const(I32(314)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [imported_const],
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_global_0"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_global_1"),
        ExternIdx::global(GlobalIdx::new(1U)),
      ),
      Export::new(
        Name::from_string("__fuzz_global_2"),
        ExternIdx::global(GlobalIdx::new(2U)),
      ),
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(4U, Some(4U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [
      Global::new(
        GlobalType::new(ValType::i32(), false),
        Expr::new([
          Instruction::global_get(GlobalIdx::new(0U)),
          Instruction::i32_const(constant),
          Instruction::i32_add(),
        ]),
      ),
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([
          Instruction::global_get(GlobalIdx::new(1U)),
          Instruction::i32_const(I32(3)),
          Instruction::i32_mul(),
        ]),
      ),
    ],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U)]),
      ),
      Elem::new(ElemMode::passive(), ElemKind::funcs([FuncIdx::new(5U)])),
    ],
    [
      Data::new(
        DataMode::active(
          MemIdx::new(0U),
          Expr::new([
            Instruction::global_get(GlobalIdx::new(0U)),
            Instruction::i32_const(I32(16)),
            Instruction::i32_add(),
          ]),
        ),
        b"active-init-graph",
      ),
      Data::new(DataMode::passive(), b"passive"),
    ],
  ).with_data_cnt_sec(DataCntSec::new(2U))
}

///|
fn gen_valid_engine_state_exception_unwind_module(seed : UInt64) -> Module {
  let payload = gen_valid_engine_state_seed_i32(seed, 202UL)
  let thrower = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::global_set(GlobalIdx::new(0U)),
      Instruction::i32_const(I32(48)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::throw_(TagIdx::new(0U)),
    ]),
  )
  let route : Array[Instruction] = [Instruction::local_get(LocalIdx::new(0U))]
  match (seed % 4UL).to_int() {
    0 => route.push(Instruction::call(FuncIdx::new(5U)))
    1 => {
      route.push(Instruction::i32_const(I32(0)))
      route.push(
        Instruction::call_indirect(TypeIdx::new(2U), TableIdx::new(0U)),
      )
    }
    2 => {
      route.push(Instruction::ref_func(FuncIdx::new(5U)))
      route.push(Instruction::call_ref(TypeIdx::new(2U)))
    }
    _ => route.push(Instruction::return_call(FuncIdx::new(5U)))
  }
  let wrapper = Func::new(Locals::empty(), Expr::new(route))
  let catcher = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::try_table(
            BlockType::void_(),
            [Catch::new(TagIdx::new(0U), LabelIdx::new(0U))],
            Expr::new([
              Instruction::i32_const(payload),
              Instruction::call(FuncIdx::new(6U)),
            ]),
          ),
          Instruction::i32_const(I32(0)),
        ]),
      ),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4200))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(320, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(321, [
      Instruction::global_get(GlobalIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(2U), TypeIdx::new(2U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [thrower, wrapper, catcher, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_global_0"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(1U, Some(1U)),
        ),
        None,
      ),
    ],
    [MemType::new(Limits::i32(1U, Some(1U)))],
    [
      Global::new(
        GlobalType::new(ValType::i32(), true),
        Expr::new([Instruction::i32_const(I32(0))]),
      ),
    ],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U)]),
      ),
    ],
    [],
  ).with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
}

///|
fn gen_valid_engine_state_metamorphic_module(
  seed : UInt64,
  alternate : Bool,
) -> Module {
  let constant = (seed % 1000003UL + 1UL).to_int()
  let body = if alternate {
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(-constant)),
      Instruction::i32_sub(),
    ]
  } else {
    [
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(constant)),
      Instruction::i32_add(),
    ]
  }
  let leaf = Func::new(Locals::empty(), Expr::new(body))
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4300))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(330, [
      Instruction::i32_const(I32(330)),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}

///|
pub fn gen_valid_engine_state_metamorphic_comparison_module(
  seed : UInt64,
) -> Module {
  gen_valid_engine_state_metamorphic_module(seed, true)
}

///|
fn gen_valid_engine_state_invalid_base_module(seed : UInt64) -> Module {
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4400))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(340, [
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 203UL)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(5U)],
    [Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}

///|
pub fn gen_valid_engine_state_invalid_module_family(seed : UInt64) -> String {
  match (seed % 4UL).to_int() {
    0 => "invalid-magic"
    1 => "invalid-version"
    2 => "truncated-binary"
    _ => "malformed-section-length"
  }
}

///|
fn gen_valid_engine_state_gc_graph_module(seed : UInt64) -> Module {
  let struct_idx = TypeIdx::new(12U)
  let array_idx = TypeIdx::new(13U)
  let struct_ref = RefType::new(true, HeapType::new(struct_idx))
  let array_ref = RefType::new(true, HeapType::new(array_idx))
  let first = gen_valid_engine_state_seed_i32(seed, 210UL)
  let second = gen_valid_engine_state_seed_i32(seed, 211UL)
  let body = [
    Instruction::i32_const(first),
    Instruction::ref_null(HeapType::new(struct_idx)),
    Instruction::struct_new(struct_idx),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::struct_set(struct_idx, U32(1U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(second),
    Instruction::struct_set(struct_idx, U32(0U)),
    Instruction::i32_const(first),
    Instruction::i32_const(second),
    Instruction::i32_const(I32(3)),
    Instruction::array_new_fixed(array_idx, U32(3U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_const(I32(0x5a5a5a5a)),
    Instruction::array_set(array_idx),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::struct_get(struct_idx, U32(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::i32_const(I32(1)),
    Instruction::array_get(array_idx),
    Instruction::i32_xor(),
    Instruction::i32_const(I32(0x1234567)),
    Instruction::ref_i31(),
    Instruction::i31_get_s(),
    Instruction::i32_xor(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::ref_test(false, HeapType::new(struct_idx)),
    Instruction::i32_xor(),
  ]
  let graph = Func::new(
    Locals::from_types([
      ValType::ref_type(struct_ref),
      ValType::ref_type(array_ref),
    ]),
    Expr::new(body),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4500))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(350, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [graph, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
            FieldType::new(
              StorageType::val_type(ValType::ref_type(struct_ref)),
              Mut::var_(),
            ),
          ]),
        ),
      ),
      RecType::new(
        SubType::comp_type(
          CompType::array(
            FieldType::new(StorageType::val_type(ValType::i32()), Mut::var_()),
          ),
        ),
      ),
    ]),
  )
}

///|
fn gen_valid_engine_state_recursive_multivalue_step(
  seed : UInt64,
  salt : UInt64,
  callee : FuncIdx,
) -> Func {
  let delta = gen_valid_engine_state_seed_i32(seed, salt)
  Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_eqz(),
      Instruction::if_(
        BlockType::type_idx(TypeIdx::new(13U)),
        [
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::i64_extend_i32s(),
        ],
        Some([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::i32_const(I32(1)),
          Instruction::i32_sub(),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::i32_const(delta),
          Instruction::i32_add(),
          Instruction::call(callee),
        ]),
      ),
    ]),
  )
}

///|
fn gen_valid_engine_state_recursive_multivalue_module(seed : UInt64) -> Module {
  let direct = gen_valid_engine_state_recursive_multivalue_step(
    seed,
    250UL,
    FuncIdx::new(5U),
  )
  let mutual_left = gen_valid_engine_state_recursive_multivalue_step(
    seed,
    251UL,
    FuncIdx::new(7U),
  )
  let mutual_right = gen_valid_engine_state_recursive_multivalue_step(
    seed,
    252UL,
    FuncIdx::new(6U),
  )
  let join = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(I32(1)),
      Instruction::i32_and(),
      Instruction::if_(
        BlockType::type_idx(TypeIdx::new(13U)),
        [
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::call(FuncIdx::new(5U)),
        ],
        Some([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::call(FuncIdx::new(6U)),
        ]),
      ),
    ]),
  )
  let depth = 2 + ((seed >> 7) % 7UL).to_int()
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4600))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(depth)),
    Instruction::i32_const(I32(360)),
    Instruction::call(FuncIdx::new(0U)),
    Instruction::call(FuncIdx::new(8U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(360, [
      Instruction::local_get(LocalIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(361, [
      Instruction::local_get(LocalIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(depth + 1)),
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 253UL)),
    Instruction::call(FuncIdx::new(6U)),
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(0U)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(362, [
      Instruction::local_get(LocalIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(363, [
      Instruction::local_get(LocalIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(12U),
      TypeIdx::new(12U),
      TypeIdx::new(12U),
      TypeIdx::new(12U),
      TypeIdx::new(5U),
    ],
    [
      direct,
      mutual_left,
      mutual_right,
      join,
      Func::new(
        Locals::from_types([ValType::i32(), ValType::i64()]),
        Expr::new(start),
      ),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      gen_valid_engine_state_func_type([ValType::i32(), ValType::i32()], [
        ValType::i32(),
        ValType::i64(),
      ]),
      gen_valid_engine_state_func_type([], [ValType::i32(), ValType::i64()]),
    ]),
  )
}

///|
fn gen_valid_engine_state_subtype_field(vt : ValType) -> FieldType {
  FieldType::new(StorageType::val_type(vt), Mut::var_())
}

///|
fn gen_valid_engine_state_subtype_cast_graph_module(seed : UInt64) -> Module {
  let root_idx = TypeIdx::new(12U)
  let left_idx = TypeIdx::new(13U)
  let right_idx = TypeIdx::new(14U)
  let leaf_idx = TypeIdx::new(15U)
  let root_ref = RefType::new(true, HeapType::new(root_idx))
  let root_value = gen_valid_engine_state_seed_i32(seed, 260UL)
  let left_value = gen_valid_engine_state_seed_i32(seed, 261UL)
  let leaf_value = gen_valid_engine_state_seed_i32(seed, 262UL)
  let right_value = gen_valid_engine_state_seed_i64(seed, 263UL)
  let graph = Func::new(
    Locals::from_types([
      ValType::ref_type(root_ref),
      ValType::ref_type(root_ref),
      ValType::i32(),
    ]),
    Expr::new([
      Instruction::i32_const(root_value),
      Instruction::i32_const(left_value),
      Instruction::i32_const(leaf_value),
      Instruction::struct_new(leaf_idx),
      Instruction::local_set(LocalIdx::new(0U)),
      Instruction::i32_const(I32(0)),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_test(false, HeapType::new(root_idx)),
      Instruction::i32_or(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_test(false, HeapType::new(left_idx)),
      Instruction::i32_const(I32(1)),
      Instruction::i32_shl(),
      Instruction::i32_or(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_test(false, HeapType::new(right_idx)),
      Instruction::i32_const(I32(2)),
      Instruction::i32_shl(),
      Instruction::i32_or(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_test(false, HeapType::new(leaf_idx)),
      Instruction::i32_const(I32(3)),
      Instruction::i32_shl(),
      Instruction::i32_or(),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_cast(false, HeapType::new(left_idx)),
      Instruction::struct_get(left_idx, U32(1U)),
      Instruction::i32_xor(),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::ref_cast(false, HeapType::new(leaf_idx)),
      Instruction::struct_get(leaf_idx, U32(2U)),
      Instruction::i32_xor(),
      Instruction::local_set(LocalIdx::new(2U)),
      Instruction::i32_const(root_value),
      Instruction::i64_const(right_value),
      Instruction::struct_new(right_idx),
      Instruction::local_set(LocalIdx::new(1U)),
      Instruction::local_get(LocalIdx::new(2U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::ref_test(false, HeapType::new(right_idx)),
      Instruction::i32_const(I32(4)),
      Instruction::i32_shl(),
      Instruction::i32_or(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::ref_test(false, HeapType::new(left_idx)),
      Instruction::i32_const(I32(5)),
      Instruction::i32_shl(),
      Instruction::i32_or(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::ref_cast(false, HeapType::new(right_idx)),
      Instruction::struct_get(right_idx, U32(1U)),
      Instruction::i32_wrap_i64(),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4700))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(370, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [graph, Func::new(Locals::empty(), Expr::new(start))],
    [],
    [],
    [],
    [],
    [],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      RecType::new(
        SubType::new(
          false,
          [],
          CompType::struct_([
            gen_valid_engine_state_subtype_field(ValType::i32()),
          ]),
        ),
      ),
      RecType::new(
        SubType::new(
          false,
          [root_idx],
          CompType::struct_([
            gen_valid_engine_state_subtype_field(ValType::i32()),
            gen_valid_engine_state_subtype_field(ValType::i32()),
          ]),
        ),
      ),
      RecType::new(
        SubType::new(
          true,
          [root_idx],
          CompType::struct_([
            gen_valid_engine_state_subtype_field(ValType::i32()),
            gen_valid_engine_state_subtype_field(ValType::i64()),
          ]),
        ),
      ),
      RecType::new(
        SubType::new(
          true,
          [left_idx],
          CompType::struct_([
            gen_valid_engine_state_subtype_field(ValType::i32()),
            gen_valid_engine_state_subtype_field(ValType::i32()),
            gen_valid_engine_state_subtype_field(ValType::i32()),
          ]),
        ),
      ),
    ]),
  )
}

///|
fn gen_valid_engine_state_type_call_matrix_module(seed : UInt64) -> Module {
  let i32_constant = gen_valid_engine_state_seed_i32(seed, 220UL)
  let i64_constant = gen_valid_engine_state_seed_i64(seed, 221UL)
  let numeric = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(i32_constant),
      Instruction::i32_add(),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i64_const(i64_constant),
      Instruction::i64_xor(),
    ]),
  )
  let direct = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  let indirect = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::i32_const(I32(0)),
      Instruction::call_indirect(TypeIdx::new(9U), TableIdx::new(0U)),
    ]),
  )
  let referenced = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::ref_func(FuncIdx::new(5U)),
      Instruction::call_ref(TypeIdx::new(9U)),
    ]),
  )
  let tail = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(1U)),
      Instruction::return_call(FuncIdx::new(5U)),
    ]),
  )
  let f32_leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::f32_const(F32(Float::reinterpret_from_uint(0x3f400000U))),
    ]),
  )
  let f64_leaf = Func::new(
    Locals::empty(),
    Expr::new([Instruction::f64_const(F64(6.25))]),
  )
  let simd_leaf = Func::new(
    Locals::empty(),
    Expr::new([gen_valid_engine_state_simd_const(seed)]),
  )
  let ref_leaf = Func::new(
    Locals::empty(),
    Expr::new([Instruction::ref_func(FuncIdx::new(5U))]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4600))
  for target in [6, 7, 8, 9] {
    start.push(Instruction::i32_const(I32(target)))
    start.push(Instruction::i64_const(I64(target.to_int64() * 17L)))
    start.push(Instruction::call(FuncIdx::new(target.reinterpret_as_uint())))
    start.push(Instruction::local_set(LocalIdx::new(1U)))
    start.push(Instruction::local_set(LocalIdx::new(0U)))
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i32(360 + target, [
        Instruction::local_get(LocalIdx::new(0U)),
      ]),
    )
    gen_valid_engine_state_append(
      start,
      gen_valid_engine_state_observe_i64(370 + target, [
        Instruction::local_get(LocalIdx::new(1U)),
      ]),
    )
  }
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(380, [
      Instruction::call(FuncIdx::new(10U)),
      Instruction::i32_reinterpret_f32(),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(381, [
      Instruction::call(FuncIdx::new(11U)),
      Instruction::i64_reinterpret_f64(),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(382, [
      Instruction::call(FuncIdx::new(12U)),
      Instruction::i32x4_extract_lane(LaneIdx::new(0)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(383, [
      Instruction::call(FuncIdx::new(13U)),
      Instruction::ref_is_null(),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [
      TypeIdx::new(9U),
      TypeIdx::new(9U),
      TypeIdx::new(9U),
      TypeIdx::new(9U),
      TypeIdx::new(9U),
      TypeIdx::new(12U),
      TypeIdx::new(13U),
      TypeIdx::new(10U),
      TypeIdx::new(14U),
      TypeIdx::new(5U),
    ],
    [
      numeric,
      direct,
      indirect,
      referenced,
      tail,
      f32_leaf,
      f64_leaf,
      simd_leaf,
      ref_leaf,
      Func::new(
        Locals::from_types([ValType::i32(), ValType::i64()]),
        Expr::new(start),
      ),
    ],
    [
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    [
      Table::new(
        TableType::new(
          gen_valid_engine_state_funcref(),
          Limits::i32(1U, Some(1U)),
        ),
        None,
      ),
    ],
    [],
    [],
    [
      Elem::new(
        ElemMode::active(
          TableIdx::new(0U),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
        ElemKind::funcs([FuncIdx::new(5U)]),
      ),
    ],
    [],
  ).with_type_sec(
    gen_valid_engine_state_extended_types([
      gen_valid_engine_state_func_type([], [ValType::f32()]),
      gen_valid_engine_state_func_type([], [ValType::f64()]),
      gen_valid_engine_state_func_type([], [
        ValType::ref_type(gen_valid_engine_state_funcref()),
      ]),
    ]),
  )
}

///|
fn gen_valid_engine_state_leb_index_boundaries_module(seed : UInt64) -> Module {
  let functions : Array[Func] = []
  let types : Array[TypeIdx] = []
  for index in 0..<130 {
    functions.push(
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::i32_const(I32(index))]),
      ),
    )
    types.push(TypeIdx::new(8U))
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4700))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(390, [
      Instruction::call(FuncIdx::new(128U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  functions.push(Func::new(Locals::empty(), Expr::new(start)))
  types.push(TypeIdx::new(5U))
  gen_valid_engine_state_base_module([], types, functions, [], [], [], [], [], []).with_custom_secs([
      @lib.CustomSec::new(
        Name::from_string("leb.127"),
        gen_valid_engine_state_decoder_payload(127, seed),
      ),
      @lib.CustomSec::new(
        Name::from_string("leb.128"),
        gen_valid_engine_state_decoder_payload(128, seed >> 1),
      ),
      @lib.CustomSec::new(
        Name::from_string("leb.16383"),
        gen_valid_engine_state_decoder_payload(16383, seed >> 2),
      ),
      @lib.CustomSec::new(
        Name::from_string("leb.16384"),
        gen_valid_engine_state_decoder_payload(16384, seed >> 3),
      ),
    ],
  )
}

///|
fn gen_valid_engine_state_table_reference_matrix_module(
  seed : UInt64,
) -> Module {
  let typed_ref = RefType::new(true, HeapType::new(TypeIdx::new(7U)))
  let variant = (seed % 4UL).to_int()
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 230UL)),
      Instruction::i32_xor(),
    ]),
  )
  let start : Array[Instruction] = []
  let tables : Array[Table] = []
  let elems : Array[Elem] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4800))
  match variant {
    0 => {
      tables.push(
        Table::new(
          TableType::new(
            gen_valid_engine_state_funcref(),
            Limits::i32(4U, Some(8U)),
          ),
          None,
        ),
      )
      elems.push(
        Elem::new(
          ElemMode::active(
            TableIdx::new(0U),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::funcs([FuncIdx::new(5U)]),
        ),
      )
      gen_valid_engine_state_append(start, [
        Instruction::i32_const(I32(1)),
        Instruction::ref_func(FuncIdx::new(5U)),
        Instruction::i32_const(I32(2)),
        Instruction::table_fill(TableIdx::new(0U)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(2)),
        Instruction::table_copy(TableIdx::new(0U), TableIdx::new(0U)),
      ])
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i32(400, [
          Instruction::i32_const(I32(0)),
          Instruction::table_get(TableIdx::new(0U)),
          Instruction::ref_is_null(),
        ]),
      )
    }
    1 => {
      tables.push(
        Table::new(
          TableType::new(
            RefType::abs(AbsHeapType::extern_()),
            Limits::i32(2U, Some(4U)),
          ),
          None,
        ),
      )
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i32(401, [
          Instruction::ref_null(HeapType::abs(AbsHeapType::extern_())),
          Instruction::i32_const(I32(1)),
          Instruction::table_grow(TableIdx::new(0U)),
        ]),
      )
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i32(402, [
          Instruction::table_size(TableIdx::new(0U)),
        ]),
      )
    }
    2 => {
      tables.push(
        Table::new(TableType::new(typed_ref, Limits::i32(2U, Some(4U))), None),
      )
      elems.push(
        Elem::new(
          ElemMode::active(
            TableIdx::new(0U),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::typed_exprs(typed_ref, [
            Expr::new([Instruction::ref_func(FuncIdx::new(5U))]),
          ]),
        ),
      )
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i32(403, [
          Instruction::i32_const(I32(0)),
          Instruction::table_get(TableIdx::new(0U)),
          Instruction::ref_is_null(),
        ]),
      )
    }
    _ => {
      tables.push(
        Table::new(
          TableType::new(
            gen_valid_engine_state_funcref(),
            Limits::i64(2UL, Some(4UL)),
          ),
          None,
        ),
      )
      elems.push(
        Elem::new(
          ElemMode::active(
            TableIdx::new(0U),
            Expr::new([Instruction::i64_const(I64(0L))]),
          ),
          ElemKind::funcs([FuncIdx::new(5U)]),
        ),
      )
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i32(404, [
          Instruction::i64_const(I64(0L)),
          Instruction::table_get(TableIdx::new(0U)),
          Instruction::ref_is_null(),
        ]),
      )
      gen_valid_engine_state_append(
        start,
        gen_valid_engine_state_observe_i64(405, [
          Instruction::table_size(TableIdx::new(0U)),
        ]),
      )
    }
  }
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(406, [
      Instruction::i32_const(I32(406)),
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_table_0"),
        ExternIdx::table(TableIdx::new(0U)),
      ),
    ],
    tables,
    [],
    [],
    elems,
    [],
  )
}

///|
fn gen_valid_engine_state_memory64_multi_memory_module(seed : UInt64) -> Module {
  let value32 = gen_valid_engine_state_seed_i32(seed, 240UL)
  let value64 = gen_valid_engine_state_seed_i64(seed, 241UL)
  let reader = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::i32_const(I32(24)),
      Instruction::i32_load(gen_valid_engine_state_indexed_memarg(2U, 0U, 0UL)),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(4900))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(I32(24)),
    Instruction::i32_const(value32),
    Instruction::i32_store(gen_valid_engine_state_indexed_memarg(2U, 0U, 0UL)),
    Instruction::i64_const(I64(40L)),
    Instruction::i64_const(value64),
    Instruction::i64_store(gen_valid_engine_state_indexed_memarg(3U, 1U, 0UL)),
  ])
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(410, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(411, [
      Instruction::i64_const(I64(40L)),
      Instruction::i64_load(gen_valid_engine_state_indexed_memarg(3U, 1U, 0UL)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(412, [
      Instruction::memory_size(MemIdx::new(0U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i64(413, [
      Instruction::memory_size(MemIdx::new(1U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(5U)],
    [reader, Func::new(Locals::empty(), Expr::new(start))],
    [
      Export::new(
        Name::from_string("__fuzz_memory_0"),
        ExternIdx::mem(MemIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("__fuzz_memory_1"),
        ExternIdx::mem(MemIdx::new(1U)),
      ),
    ],
    [],
    [
      MemType::new(Limits::i32(1U, Some(2U))),
      MemType::new(Limits::i64(1UL, Some(2UL))),
    ],
    [],
    [],
    [],
  )
}

///|
pub fn gen_valid_engine_state_trap_commit_family(seed : UInt64) -> String {
  match (seed % 4UL).to_int() {
    0 => "integer-division-by-zero"
    1 => "out-of-bounds-memory"
    2 => "null-function-reference"
    _ => "unreachable"
  }
}

///|
fn gen_valid_engine_state_trap_commit_matrix_module(seed : UInt64) -> Module {
  let leaf = Func::new(
    Locals::empty(),
    Expr::new([Instruction::local_get(LocalIdx::new(0U))]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(5000))
  gen_valid_engine_state_append(start, [
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 250UL)),
    Instruction::global_set(GlobalIdx::new(0U)),
    Instruction::i32_const(I32(56)),
    Instruction::i32_const(gen_valid_engine_state_seed_i32(seed, 251UL)),
    Instruction::i32_store(gen_valid_engine_state_memarg(2U, 0UL)),
    Instruction::i32_const(I32(1)),
    Instruction::ref_func(FuncIdx::new(5U)),
    Instruction::table_set(TableIdx::new(0U)),
    Instruction::i32_const(I32(0x70000000)),
    Instruction::call(FuncIdx::new(2U)),
  ])
  match (seed % 4UL).to_int() {
    0 =>
      gen_valid_engine_state_append(start, [
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(0)),
        Instruction::i32_div_s(),
        Instruction::drop(),
      ])
    1 =>
      gen_valid_engine_state_append(start, [
        Instruction::i32_const(I32(131072)),
        Instruction::i32_load(gen_valid_engine_state_memarg(2U, 0UL)),
        Instruction::drop(),
      ])
    2 =>
      gen_valid_engine_state_append(start, [
        Instruction::i32_const(I32(1)),
        Instruction::i32_const(I32(0)),
        Instruction::call_indirect(TypeIdx::new(7U), TableIdx::new(0U)),
        Instruction::drop(),
      ])
    _ => start.push(Instruction::unreachable_())
  }
  gen_valid_engine_state_base_module(
    gen_valid_engine_state_resource_imports(),
    [TypeIdx::new(7U), TypeIdx::new(5U)],
    [leaf, Func::new(Locals::empty(), Expr::new(start))],
    gen_valid_engine_state_import_exports(),
    [],
    [],
    [],
    [],
    [],
  )
}

///|
fn gen_valid_engine_state_compiler_boundaries_module(seed : UInt64) -> Module {
  let local_count = 32 + (seed % 4UL).to_int() * 32
  let function_count = 32 + ((seed >> 2) % 4UL).to_int() * 32
  let local_types : Array[ValType] = []
  let accumulator_body : Array[Instruction] = []
  for index in 0..<local_count {
    local_types.push(ValType::i32())
    accumulator_body.push(Instruction::i32_const(I32(index * 17 + 3)))
    accumulator_body.push(
      Instruction::local_set(LocalIdx::new(index.reinterpret_as_uint())),
    )
  }
  let mut nested = Instruction::nop()
  for _ in 0..<16 {
    nested = Instruction::block(BlockType::void_(), Expr::new([nested]))
  }
  accumulator_body.push(nested)
  accumulator_body.push(Instruction::i32_const(I32(0)))
  for index in 0..<local_count {
    accumulator_body.push(
      Instruction::local_get(LocalIdx::new(index.reinterpret_as_uint())),
    )
    accumulator_body.push(Instruction::i32_add())
  }
  let functions : Array[Func] = [
    Func::new(Locals::from_types(local_types), Expr::new(accumulator_body)),
  ]
  let types : Array[TypeIdx] = [TypeIdx::new(8U)]
  for index in 1..<function_count {
    functions.push(
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::i32_const(I32(index))]),
      ),
    )
    types.push(TypeIdx::new(8U))
  }
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(5100))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(420, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(421, [
      Instruction::call(
        FuncIdx::new((4 + function_count).reinterpret_as_uint()),
      ),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  functions.push(Func::new(Locals::empty(), Expr::new(start)))
  types.push(TypeIdx::new(5U))
  gen_valid_engine_state_base_module([], types, functions, [], [], [], [], [], [])
}

///|
fn gen_valid_engine_state_nan_module(seed : UInt64) -> Module {
  let f32_body : Array[Instruction] = []
  match (seed % 4UL).to_int() {
    0 =>
      gen_valid_engine_state_append(f32_body, [
        Instruction::f32_const(F32(Float::reinterpret_from_uint(0x7fc12345U))),
        Instruction::f32_const(F32(1.0)),
        Instruction::f32_add(),
      ])
    1 =>
      gen_valid_engine_state_append(f32_body, [
        Instruction::f32_const(F32(0.0)),
        Instruction::f32_const(F32(0.0)),
        Instruction::f32_div(),
      ])
    2 =>
      gen_valid_engine_state_append(f32_body, [
        Instruction::f32_const(F32(-1.0)),
        Instruction::f32_sqrt(),
      ])
    _ =>
      gen_valid_engine_state_append(f32_body, [
        Instruction::f32_const(F32(Float::reinterpret_from_uint(0x7fa00001U))),
        Instruction::f32_const(F32(2.0)),
        Instruction::f32_min(),
      ])
  }
  f32_body.push(Instruction::local_tee(LocalIdx::new(0U)))
  f32_body.push(Instruction::local_get(LocalIdx::new(0U)))
  f32_body.push(Instruction::f32_ne())
  let f32_classify = Func::new(
    Locals::from_types([ValType::f32()]),
    Expr::new(f32_body),
  )
  let f64_classify = Func::new(
    Locals::from_types([ValType::f64()]),
    Expr::new([
      Instruction::f64_const(F64(0x7ff123456789abcdUL.reinterpret_as_double())),
      Instruction::f64_const(F64(1.0)),
      Instruction::f64_add(),
      Instruction::local_tee(LocalIdx::new(0U)),
      Instruction::local_get(LocalIdx::new(0U)),
      Instruction::f64_ne(),
    ]),
  )
  let signed_zero = Func::new(
    Locals::empty(),
    Expr::new([
      Instruction::f32_const(F32(0.0)),
      Instruction::f32_const(F32(Float::reinterpret_from_uint(0x80000000U))),
      if ((seed >> 4) & 1UL) == 0UL {
        Instruction::f32_min()
      } else {
        Instruction::f32_max()
      },
      Instruction::i32_reinterpret_f32(),
    ]),
  )
  let start : Array[Instruction] = []
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(5200))
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(430, [
      Instruction::call(FuncIdx::new(5U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(431, [
      Instruction::call(FuncIdx::new(6U)),
    ]),
  )
  gen_valid_engine_state_append(
    start,
    gen_valid_engine_state_observe_i32(432, [
      Instruction::call(FuncIdx::new(7U)),
    ]),
  )
  gen_valid_engine_state_append(start, gen_valid_engine_state_mark(0x7fffffff))
  gen_valid_engine_state_base_module(
    [],
    [TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(8U), TypeIdx::new(5U)],
    [
      f32_classify,
      f64_classify,
      signed_zero,
      Func::new(Locals::empty(), Expr::new(start)),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
  )
}
