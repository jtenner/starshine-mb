///|
fn gen_valid_dae2_family(profile : GenValidProfile) -> Int {
  match profile {
    Dae2CyclesProfile => 1
    Dae2ControlFlowProfile => 2
    Dae2EffectfulArgumentsProfile => 3
    Dae2TupleResultsProfile => 4
    Dae2TailCallsProfile => 5
    Dae2IndirectProfile => 6
    Dae2OpenWorldProfile => 7
    Dae2ReferenceTypesProfile => 8
    Dae2LocalsProfile => 9
    Dae2ContinuationsProfile => 10
    Dae2ExceptionsProfile => 11
    Dae2CallRefProfile => 12
    Dae2IntrinsicsProfile => 13
    _ => 0
  }
}

///|
fn gen_valid_dae2_profile_config(profile : GenValidProfile) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_name_custom_sections: profile is Dae2TupleResultsProfile,
    },
    max_type_defs: 12,
    max_imports: 4,
    max_defined_funcs: 12,
    max_tables: 2,
    max_mems: 1,
    max_globals: 2,
    max_tags: 1,
    max_elems: 2,
    max_datas: 0,
    max_params: 4,
    max_results: if profile is Dae2TupleResultsProfile {
      3
    } else {
      2
    },
    max_locals: if profile is Dae2TupleResultsProfile {
      11
    } else {
      8
    },
    max_body_statements: 420 + gen_valid_dae2_family(profile),
    max_body_depth: 12,
  }
}

///|
fn gen_valid_is_dae2_profile_config(config : GenValidConfig) -> Bool {
  for
    profile in [
      Dae2ForwardedResultsProfile,
      Dae2CyclesProfile,
      Dae2ControlFlowProfile,
      Dae2EffectfulArgumentsProfile,
      Dae2TupleResultsProfile,
      Dae2TailCallsProfile,
      Dae2IndirectProfile,
      Dae2OpenWorldProfile,
      Dae2ReferenceTypesProfile,
      Dae2LocalsProfile,
      Dae2ContinuationsProfile,
      Dae2ExceptionsProfile,
      Dae2CallRefProfile,
      Dae2IntrinsicsProfile,
    ] {
    if config == gen_valid_dae2_profile_config(profile) {
      return true
    }
  }
  false
}

///|
fn gen_valid_dae2_profile_module(ctx : GenValidContext) -> Module {
  let family = ctx.config.max_body_statements - 420
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  if family == 4 && ((seed & 15UL) == 8UL || (seed & 15UL) == 9UL) {
    return gen_valid_dae2_overlap_module(
      seed,
      ctx.config.features.allow_name_custom_sections && (seed & 16UL) != 0UL,
    )
  }
  if family == 9 && seed % 12UL == 3UL {
    return gen_valid_dae2_derived_pointer_module(seed)
  }
  if family == 9 && seed % 6UL == 0UL {
    return gen_valid_dae2_inserted_control_module(seed)
  }
  if family == 9 && seed % 3UL != 0UL {
    return gen_valid_dae2_local_state_module(seed, seed % 3UL == 2UL)
  }
  if family == 3 && (seed & 1UL) != 0UL {
    return gen_valid_dae2_pending_memory_module(seed)
  }
  let literal = (seed ^ (seed >> 32)).to_int()
  let i32 = ValType::i32()
  let i64 = ValType::i64()
  let get0 = Instruction::local_get(LocalIdx::new(0U))
  let constant = Instruction::i32_const(I32(literal))
  let types : Array[RecType] = []
  let type_indices : Array[TypeIdx] = []
  let bodies : Array[Func] = []
  let add = fn(
    params : Array[ValType],
    results : Array[ValType],
    locals : Array[ValType],
    body : Array[Instruction],
  ) {
    type_indices.push(TypeIdx::new(types.length().reinterpret_as_uint()))
    types.push(
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    )
    bodies.push(Func::new(Locals::from_types(locals), Expr::new(body)))
  }
  let mut module_ = Module::new()
  let counter = GlobalIdx::new(0U)
  let effect = fn(amount : Int) {
    [
      Instruction::global_get(counter),
      Instruction::i32_const(I32(amount)),
      Instruction::i32_add(),
      Instruction::global_set(counter),
    ]
  }
  if family == 4 || family == 11 {
    module_ = module_.with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(i32, true),
          Expr::new([Instruction::i32_const(I32(0))]),
        ),
      ]),
    )
  }
  match family {
    10 => {
      let variant = (seed % 6UL).to_int()
      add([i32], [i32], [], [get0])
      let cont = TypeIdx::new(1U)
      types.push(
        RecType::new(SubType::comp_type(CompType::cont(TypeIdx::new(0U)))),
      )
      let bound_signature = TypeIdx::new(2U)
      types.push(RecType::new(SubType::comp_type(CompType::func([], [i32]))))
      let bound_cont = TypeIdx::new(3U)
      types.push(
        RecType::new(SubType::comp_type(CompType::cont(bound_signature))),
      )
      add([], [i32], [], [constant])
      let tag_signature = TypeIdx::new(5U)
      types.push(
        RecType::new(
          SubType::comp_type(
            CompType::func([], if variant == 3 { [] } else { [i32] }),
          ),
        ),
      )
      let tag = TagIdx::new(0U)
      module_ = module_.with_tag_sec(TagSec::new([TagType::new(tag_signature)]))
      let create = [
        Instruction::ref_func(FuncIdx::new(0U)),
        Instruction::cont_new(cont),
      ]
      let body = [Instruction::call(FuncIdx::new(1U)), Instruction::drop()]
      match variant {
        0 => {
          body.append(create)
          body.append([Instruction::drop(), constant])
        }
        1 => {
          body.push(constant)
          body.append(create)
          body.append([
            Instruction::cont_bind(cont, bound_cont),
            Instruction::drop(),
            constant,
          ])
        }
        2 => {
          body.push(constant)
          body.append(create)
          body.push(Instruction::resume_(cont, []))
        }
        3 => {
          body.append(create)
          body.push(Instruction::resume_throw(cont, tag, []))
        }
        4 => body.push(Instruction::suspend(tag))
        _ => {
          bodies[0] = Func::new(
            Locals::from_types([]),
            Expr::new([get0, Instruction::suspend(tag), Instruction::i32_add()]),
          )
          let reference = RefType::new(true, HeapType::new(cont))
          let resumed = [constant]
          resumed.append(create)
          resumed.append([
            Instruction::resume_(cont, [
              @lib.ResumeHandler::on_label(tag, LabelIdx::new(0U)),
            ]),
            Instruction::drop(),
            Instruction::ref_null(HeapType::new(cont)),
          ])
          body.append([
            Instruction::block(
              BlockType::val_type(ValType::ref_type(reference)),
              Expr::new(resumed),
            ),
            Instruction::drop(),
            constant,
          ])
        }
      }
      add([], [i32], [], body)
      module_ = module_.with_elem_sec(
        ElemSec::new([
          Elem::new(
            ElemMode::declarative(),
            if (seed & 8UL) == 0UL {
              ElemKind::funcs([FuncIdx::new(0U)])
            } else {
              ElemKind::typed_exprs(
                RefType::new(true, HeapType::abs(AbsHeapType::func())),
                [Expr::new([Instruction::ref_func(FuncIdx::new(0U))])],
              )
            },
          ),
        ]),
      )
    }
    11 => {
      let producer = effect(1)
      producer.push(get0)
      add([i32], [i32], [], producer)
      add([i32], [], [], effect(2))
      module_ = module_.with_tag_sec(
        TagSec::new([TagType::new(TypeIdx::new(1U))]),
      )
      add([], [i32], [], [
        Instruction::try_(
          BlockType::val_type(i32),
          Expr::new([constant, Instruction::throw_(TagIdx::new(0U))]),
          [
            @lib.LegacyCatch::tagged(
              TagIdx::new(0U),
              Expr::new([
                Instruction::call(FuncIdx::new(0U)),
                Instruction::call(FuncIdx::new(1U)),
                constant,
              ]),
            ),
            @lib.LegacyCatch::all(
              Expr::new([Instruction::i32_const(I32(literal ^ 1))]),
            ),
          ],
        ),
      ])
    }
    12 => {
      add([i32], [i32], [], [get0])
      add([], [], [], [
        constant,
        Instruction::ref_func(FuncIdx::new(0U)),
        Instruction::call_ref(TypeIdx::new(0U)),
        Instruction::drop(),
      ])
      add([], [], [], [Instruction::call(FuncIdx::new(1U))])
      module_ = module_.with_elem_sec(
        ElemSec::new([
          Elem::new(
            ElemMode::declarative(),
            ElemKind::funcs([FuncIdx::new(0U)]),
          ),
        ]),
      )
    }
    13 => {
      types.push(
        RecType::new(
          SubType::comp_type(
            CompType::func(
              [ValType::ref_type(RefType::abs(AbsHeapType::func()))],
              [i32],
            ),
          ),
        ),
      )
      module_ = module_.with_import_sec(
        ImportSec::new([
          Import::new(
            Name::from_string("binaryen-intrinsics"),
            Name::from_string("call.without.effects"),
            ExternType::func(TypeIdx::new(0U)),
          ),
        ]),
      )
      add([], [i32], [], [constant])
      add([], [], [], [
        Instruction::ref_func(FuncIdx::new(1U)),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::drop(),
      ])
      add([], [], [], [Instruction::call(FuncIdx::new(2U))])
      module_ = module_.with_elem_sec(
        ElemSec::new([
          Elem::new(
            ElemMode::declarative(),
            ElemKind::funcs([FuncIdx::new(1U)]),
          ),
        ]),
      )
    }
    1 => {
      // The live countdown bounds execution; the second parameter and result
      // form an unused cycle, including arithmetic in the forwarding path.
      for callee in [1U, 0U] {
        add([i32, i32], [i32], [], [
          get0,
          Instruction::if_(
            BlockType::val_type(i32),
            [
              get0,
              Instruction::i32_const(I32(1)),
              Instruction::i32_sub(),
              Instruction::local_get(LocalIdx::new(1U)),
              constant,
              Instruction::i32_add(),
              Instruction::call(FuncIdx::new(callee)),
            ],
            Some([Instruction::local_get(LocalIdx::new(1U))]),
          ),
        ])
      }
      add([], [], [], [
        Instruction::i32_const(I32(1 + (seed % 8UL).to_int())),
        constant,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::drop(),
      ])
    }
    2 => {
      add([i32, i32], [i32], [], [
        get0,
        Instruction::if_(
          BlockType::val_type(i32),
          [Instruction::local_get(LocalIdx::new(1U)), Instruction::return_()],
          Some([constant]),
        ),
      ])
      add([i32], [], [], [])
      add([i32], [], [], [
        get0,
        constant,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ])
    }
    3 => {
      module_ = module_.with_global_sec(
        GlobalSec::new([
          Global::new(
            GlobalType::new(i32, true),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
        ]),
      )
      add([i32], [i32], [], [
        get0,
        Instruction::global_set(GlobalIdx::new(0U)),
        get0,
      ])
      add([i32, i32, i32], [i32], [], [get0])
      add([], [i32], [], [
        constant,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::i32_const(I32(2)),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::i32_const(I32(3)),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ])
    }
    4 => {
      let variant = (seed % 4UL).to_int()
      let producer = effect(1)
      let nested = (seed & 4UL) != 0UL
      let locals = if nested { [i32] } else { [] }
      if nested {
        let tuple_type = TypeIdx::new(types.length().reinterpret_as_uint())
        types.push(
          RecType::new(SubType::comp_type(CompType::func([], [i32, i64]))),
        )
        let mut value = [
          get0,
          Instruction::i64_const(I64(seed.reinterpret_as_int64())),
        ]
        for depth = 0; depth < 2 + (seed % 4UL).to_int(); depth = depth + 1 {
          value = [
            get0,
            Instruction::i32_const(I32(depth)),
            Instruction::i32_eq(),
            Instruction::if_(
              BlockType::type_idx(tuple_type),
              [
                Instruction::local_get(LocalIdx::new(1U)),
                Instruction::i32_const(I32(literal ^ depth)),
                Instruction::local_set(LocalIdx::new(1U)),
                Instruction::i64_const(I64(depth.to_int64())),
              ],
              Some(value),
            ),
          ]
        }
        producer.append(value)
        producer.append([
          Instruction::local_get(LocalIdx::new(1U)),
          Instruction::global_set(counter),
        ])
      } else {
        producer.append([
          get0,
          Instruction::i64_const(I64(seed.reinterpret_as_int64())),
        ])
      }
      add([i32], [i32, i64], locals, producer)
      let sink = effect(2)
      let results = match variant {
        0 => []
        1 => {
          sink.push(get0)
          [i32]
        }
        2 => {
          sink.push(Instruction::local_get(LocalIdx::new(1U)))
          [i64]
        }
        _ => {
          sink.append([get0, Instruction::local_get(LocalIdx::new(1U))])
          [i32, i64]
        }
      }
      add([i32, i64], results, [], sink)
      let caller = [
        constant,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ]
      add([], results, [], caller)
    }
    5 => {
      add([i32], [i32], [], [get0])
      add([i32], [i32], [], [get0, Instruction::return_call(FuncIdx::new(0U))])
      add([], [], [], [
        constant,
        Instruction::call(FuncIdx::new(1U)),
        Instruction::drop(),
      ])
    }
    6 | 7 => {
      add([i32], [i32], [], [get0])
      let call = if family == 7 {
        Instruction::return_call_indirect(TypeIdx::new(0U), TableIdx::new(0U))
      } else {
        Instruction::call_indirect(TypeIdx::new(0U), TableIdx::new(0U))
      }
      add([i32], [i32], [], [get0, Instruction::i32_const(I32(0)), call])
      add([], [], [], [
        constant,
        Instruction::call(FuncIdx::new(1U)),
        Instruction::drop(),
      ])
      module_ = module_
        .with_table_sec(
          TableSec::new([
            Table::new(
              TableType::new(
                RefType::abs(AbsHeapType::func()),
                Limits::i32(1U, None),
              ),
              None,
            ),
          ]),
        )
        .with_elem_sec(
          ElemSec::new([
            Elem::new(
              ElemMode::active(
                TableIdx::new(0U),
                Expr::new([Instruction::i32_const(I32(0))]),
              ),
              ElemKind::funcs([FuncIdx::new(0U)]),
            ),
          ]),
        )
    }
    8 => {
      types.push(
        RecType::new(
          SubType::comp_type(
            CompType::struct_([
              FieldType::new(StorageType::val_type(i32), Mut::const_()),
            ]),
          ),
        ),
      )
      let ref_type = ValType::ref_type(
        RefType::new(false, HeapType::new(TypeIdx::new(0U))),
      )
      add([ref_type], [], [], [])
      add([ref_type], [], [], [get0, Instruction::call(FuncIdx::new(0U))])
      add([], [], [], [
        constant,
        Instruction::struct_new(TypeIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ])
    }
    9 => {
      add([i32], [i32], [], [
        constant,
        Instruction::local_set(LocalIdx::new(0U)),
        get0,
      ])
      add([i32], [], [i32], [
        get0,
        Instruction::local_tee(LocalIdx::new(1U)),
        Instruction::drop(),
      ])
      add([], [], [], [
        constant,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ])
    }
    _ => {
      add([i32], [i32], [], [get0, constant, Instruction::i32_xor()])
      add([i32], [], [], [])
      add([i32], [], [], [
        get0,
        Instruction::call(FuncIdx::new(0U)),
        Instruction::call(FuncIdx::new(1U)),
      ])
    }
  }
  let exports = [
    Export::new(
      Name::from_string("run"),
      ExternIdx::func(FuncIdx::new(if family == 13 { 3U } else { 2U })),
    ),
  ]
  if family == 3 || family == 4 || family == 11 {
    exports.push(
      Export::new(Name::from_string("effects"), ExternIdx::global(counter)),
    )
  }
  module_
  .with_type_sec(TypeSec::new(types))
  .with_func_sec(FuncSec::new(type_indices))
  .with_code_sec(CodeSec::new(bodies))
  .with_export_sec(ExportSec::new(exports))
}

///|
fn gen_valid_dae2_pending_memory_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let address = if (seed & 2UL) == 0UL { 0 } else { 65532 }
  let addr = Instruction::i32_const(I32(address))
  let memarg = @lib.MemArg::new(2U, None, 0UL)
  let initial = (seed.to_uint() ^ 0x12345678U).reinterpret_as_int()
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], []))),
      RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([], [i32]))),
    ]),
  )
  .with_func_sec(
    FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(2U)]),
  )
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::from_types([]),
        Expr::new([
          addr,
          Instruction::i32_const(I32(initial ^ 1)),
          Instruction::i32_store(memarg),
        ]),
      ),
      Func::new(
        Locals::from_types([]),
        Expr::new([Instruction::local_get(LocalIdx::new(0U))]),
      ),
      Func::new(
        Locals::from_types([]),
        Expr::new([
          addr,
          Instruction::i32_const(I32(initial)),
          Instruction::i32_store(memarg),
          addr,
          Instruction::i32_load(memarg),
          Instruction::call(FuncIdx::new(0U)),
          Instruction::i32_const(I32(7)),
          Instruction::call(FuncIdx::new(1U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
      Export::new(Name::from_string("memory"), ExternIdx::mem(MemIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_dae2_local_state_module(seed : UInt64, capture : Bool) -> Module {
  let i32 = ValType::i32()
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let number = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let initial = (seed.to_uint() ^ 0x1234U).reinterpret_as_int()
  let ma = MemArg::new(2U, None, 0UL)
  let body = if capture {
    [
      Instruction::memory_size(MemIdx::new(0U)),
      Instruction::local_tee(LocalIdx::new(1U)),
      number(0),
      Instruction::i32_load(ma),
      get(1U),
      Instruction::i32_add(),
      Instruction::i32_add(),
    ]
  } else {
    [
      get(0U),
      Instruction::if_(
        BlockType::val_type(i32),
        [number(initial), Instruction::local_set(LocalIdx::new(1U)), number(0)],
        Some([
          number(initial ^ 1),
          Instruction::local_set(LocalIdx::new(1U)),
          number(1),
        ]),
      ),
      Instruction::local_set(LocalIdx::new(2U)),
      get(1U),
    ]
  }
  let module_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
        RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(0U)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::from_types([i32, i32]), Expr::new(body)),
        Func::new(Locals::from_types([]), Expr::new([get(0U)])),
        Func::new(
          Locals::from_types([]),
          Expr::new([
            get(0U),
            Instruction::call(FuncIdx::new(0U)),
            number(7),
            Instruction::call(FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
      ]),
    )
  if capture {
    module_.with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
  } else {
    module_
  }
}

///|
fn gen_valid_dae2_overlap_module(seed : UInt64, named : Bool) -> Module {
  let i32 = ValType::i32()
  let literal = (seed ^ (seed >> 32)).to_int()
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let set = fn(index : UInt) { Instruction::local_set(LocalIdx::new(index)) }
  let constant = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let producer = [
    Instruction::global_get(GlobalIdx::new(0U)),
    constant(1),
    Instruction::i32_add(),
    Instruction::global_set(GlobalIdx::new(0U)),
    constant(literal),
    constant(literal ^ 101),
    constant(literal ^ 202),
  ]
  let consumer = [
    get(0U),
    get(1U),
    constant(31),
    Instruction::i32_mul(),
    Instruction::i32_add(),
    get(2U),
    constant(997),
    Instruction::i32_mul(),
    Instruction::i32_add(),
  ]
  let runner = [
    constant(literal),
    Instruction::call(FuncIdx::new(0U)),
    set(6U),
    set(5U),
    Instruction::local_tee(LocalIdx::new(4U)),
    set(8U),
    get(5U),
    set(7U),
    Instruction::block(
      BlockType::type_idx(TypeIdx::new(3U)),
      Expr::new([get(8U), get(7U), get(6U)]),
    ),
  ]
  if (seed & 1UL) == 0UL {
    runner.append([set(6U), set(10U)])
  } else {
    runner.append([set(10U), set(6U)])
  }
  runner.append([
    set(9U),
    get(9U),
    get(10U),
    get(6U),
    Instruction::call(FuncIdx::new(1U)),
  ])
  let module_ = Module::new()
    .with_type_sec(
      TypeSec::new([
        RecType::new(SubType::comp_type(CompType::func([i32], [i32, i32, i32]))),
        RecType::new(SubType::comp_type(CompType::func([i32, i32, i32], [i32]))),
        RecType::new(SubType::comp_type(CompType::func([], [i32]))),
        RecType::new(SubType::comp_type(CompType::func([], [i32, i32, i32]))),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(2U)]),
    )
    .with_code_sec(
      CodeSec::new([
        Func::new(Locals::empty(), Expr::new(producer)),
        Func::new(Locals::empty(), Expr::new(consumer)),
        Func::new(Locals::from_types(Array::make(11, i32)), Expr::new(runner)),
      ]),
    )
    .with_global_sec(
      GlobalSec::new([
        Global::new(GlobalType::new(i32, true), Expr::new([constant(0)])),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
        Export::new(
          Name::from_string("effects"),
          ExternIdx::global(GlobalIdx::new(0U)),
        ),
      ]),
    )
  if named {
    module_.with_name_sec(
      NameSec::new(
        label_names=Some(
          IndirectNameMap::new([
            IndirectNameAssoc::new(
              2U,
              NameMap::new([
                NameAssoc::new(0U, Name::from_string("forwarded-tuple")),
              ]),
            ),
          ]),
        ),
      ),
    )
  } else {
    module_
  }
}

///|
fn gen_valid_dae2_inserted_control_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let number = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let state = GlobalIdx::new(0U)
  let observed = GlobalIdx::new(1U)
  let signature = TypeIdx::new(0U)
  let literal = (seed ^ (seed >> 32)).to_int() | 1
  // Read the exposed state inside the observer, so moving it across a global
  // write is observable as well as moving the later parameter tee before it.
  let observer = [
    Instruction::global_get(observed),
    number(31),
    Instruction::i32_mul(),
    get(0U),
    number(997),
    Instruction::i32_mul(),
    Instruction::i32_add(),
    get(1U),
    Instruction::i32_add(),
    Instruction::global_get(state),
    number(3571),
    Instruction::i32_mul(),
    Instruction::i32_add(),
    Instruction::global_set(observed),
    number(literal),
  ]
  let runner = [
    get(1U),
    Instruction::if_(
      BlockType::void_(),
      [
        get(0U),
        get(1U),
        Instruction::call(FuncIdx::new(0U)),
        Instruction::drop(),
        get(1U),
        Instruction::local_set(LocalIdx::new(2U)),
      ],
      None,
    ),
  ]
  if seed % 12UL == 0UL {
    runner.append([
      number(3),
      number(4),
      Instruction::call(FuncIdx::new(0U)),
      Instruction::drop(),
    ])
  } else {
    runner.append([number(0), Instruction::global_set(state)])
  }
  runner.append([
    get(2U),
    Instruction::if_(
      BlockType::void_(),
      [get(2U), Instruction::global_set(state)],
      None,
    ),
    number(literal),
    Instruction::local_tee(LocalIdx::new(0U)),
    get(0U),
    Instruction::i32_add(),
  ])
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
    ]),
  )
  .with_func_sec(FuncSec::new([signature, signature, signature]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(GlobalType::new(i32, true), Expr::new([number(literal)])),
      Global::new(GlobalType::new(i32, true), Expr::new([number(0)])),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::empty(), Expr::new(observer)),
      Func::new(Locals::from_types([i32]), Expr::new(runner)),
      Func::new(
        Locals::empty(),
        Expr::new([get(0U), get(1U), Instruction::call(FuncIdx::new(1U))]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
      Export::new(Name::from_string("state"), ExternIdx::global(state)),
      Export::new(Name::from_string("observed"), ExternIdx::global(observed)),
    ]),
  )
}

///|
fn gen_valid_dae2_derived_pointer_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let set = fn(index : UInt) { Instruction::local_set(LocalIdx::new(index)) }
  let number = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let base = ((seed >> 32) % 256UL).to_int() + 32
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
    ]),
  )
  .with_func_sec(
    FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(1U)]),
  )
  .with_mem_sec(MemSec::new([MemType::new(Limits::i32(1U, None))]))
  .with_code_sec(
    CodeSec::new([
      // The second allocation argument is unused; DAE2 can remove it. Mask the
      // returned address so every generated invocation has an in-bounds header.
      Func::new(
        Locals::empty(),
        Expr::new([
          get(0U),
          number(255),
          Instruction::i32_and(),
          number(base),
          Instruction::i32_add(),
        ]),
      ),
      Func::new(
        Locals::from_types([i32, i32]),
        Expr::new([
          number(8),
          get(0U),
          Instruction::i32_add(),
          number(seed.to_int()),
          Instruction::call(FuncIdx::new(0U)),
          set(1U),
          get(1U),
          number(8),
          Instruction::i32_add(),
          set(2U),
          get(1U),
          number(4),
          Instruction::i32_store(MemArg::new(0U, None, 0UL)),
          get(2U),
        ]),
      ),
      Func::new(
        Locals::empty(),
        Expr::new([get(0U), Instruction::call(FuncIdx::new(1U))]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
      Export::new(Name::from_string("memory"), ExternIdx::mem(MemIdx::new(0U))),
    ]),
  )
}
