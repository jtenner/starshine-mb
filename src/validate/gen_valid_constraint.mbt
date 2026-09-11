///|
fn gen_valid_constraint_family(profile : GenValidProfile) -> Int {
  match profile {
    ConstraintIntegerProfile => 0
    ConstraintJoinsProfile => 1
    ConstraintLoopsProfile => 2
    ConstraintTeesProfile => 3
    ConstraintWraparoundProfile => 4
    ConstraintI64Profile => 5
    ConstraintLogicalProfile => 6
    ConstraintReferencesProfile => 7
    ConstraintUnreachableProfile => 8
    ConstraintRelationsProfile => 9
    ConstraintEffectsProfile => 10
    ConstraintFloatBoundaryProfile => 11
    _ => 0
  }
}

///|
fn gen_valid_constraint_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  GenValidConfig::{
    ..base,
    max_type_defs: 4,
    max_imports: 0,
    max_defined_funcs: if profile == ConstraintEffectsProfile {
      3
    } else {
      2
    },
    max_tables: 0,
    max_mems: 0,
    max_globals: 1,
    max_tags: if profile == ConstraintEffectsProfile {
      1
    } else {
      0
    },
    max_elems: 0,
    max_datas: 0,
    max_params: 2,
    max_results: 1,
    max_locals: 4,
    max_body_statements: 440 + gen_valid_constraint_family(profile),
    max_body_depth: 12,
  }
}

///|
fn gen_valid_is_constraint_profile_config(config : GenValidConfig) -> Bool {
  [
    ConstraintIntegerProfile,
    ConstraintJoinsProfile,
    ConstraintLoopsProfile,
    ConstraintTeesProfile,
    ConstraintWraparoundProfile,
    ConstraintI64Profile,
    ConstraintLogicalProfile,
    ConstraintReferencesProfile,
    ConstraintUnreachableProfile,
    ConstraintRelationsProfile,
    ConstraintEffectsProfile,
    ConstraintFloatBoundaryProfile,
  ].any(fn(profile) { config == gen_valid_constraint_profile_config(profile) })
}

///|
fn gen_valid_constraint_profile_module(ctx : GenValidContext) -> Module {
  let family = ctx.config.max_body_statements - 440
  let seed = if ctx.use_named_streams {
    ctx.root_seed
  } else {
    ctx.rnd.next_uint64()
  }
  if family == 2 && (seed & 6UL) == 4UL {
    return gen_valid_constraint_parameter_loop_module(seed)
  }
  if family == 2 && (seed & 2UL) != 0UL {
    return gen_valid_constraint_tuple_loop_module(seed)
  }
  if family == 10 {
    if seed % 8UL == 5UL {
      return gen_valid_constraint_throwing_stack_module(seed)
    }
    if seed % 4UL == 3UL {
      return gen_valid_constraint_copied_control_module(seed)
    }
    if seed % 3UL == 1UL {
      return gen_valid_constraint_handler_module(seed)
    }
    if seed % 3UL == 2UL {
      return gen_valid_constraint_pending_call_module(seed)
    }
  }
  let wide = family == 5 ||
    ((seed & 8UL) != 0UL && family != 6 && family != 7 && family != 11)
  let bits = if wide { 64 } else { 32 }
  let ty = if wide { ValType::i64() } else { ValType::i32() }
  let bool_ty = ValType::i32()
  let limits = [
    0UL, 1UL, 0x7fffffffUL, 0x80000000UL, 0xffffffffUL, 0x100000000UL, 0x7fffffffffffffffUL,
    0x8000000000000000UL, 0xffffffffffffffffUL,
  ]
  let value = limits[(seed % limits.length().to_uint64()).to_int()]
  let constant = fn(value : UInt64) {
    if wide {
      Instruction::i64_const(I64(value.reinterpret_as_int64()))
    } else {
      Instruction::i32_const(I32(value.to_uint().reinterpret_as_int()))
    }
  }
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let eq = if wide { Instruction::i64_eq() } else { Instruction::i32_eq() }
  let ne = if wide { Instruction::i64_ne() } else { Instruction::i32_ne() }
  let lt_s = if wide {
    Instruction::i64_lt_s()
  } else {
    Instruction::i32_lt_s()
  }
  let lt_u = if wide {
    Instruction::i64_lt_u()
  } else {
    Instruction::i32_lt_u()
  }
  let gt_s = if wide {
    Instruction::i64_gt_s()
  } else {
    Instruction::i32_gt_s()
  }
  let ge_u = if wide {
    Instruction::i64_ge_u()
  } else {
    Instruction::i32_ge_u()
  }
  let add = if wide { Instruction::i64_add() } else { Instruction::i32_add() }
  let eqz = if wide { Instruction::i64_eqz() } else { Instruction::i32_eqz() }
  let result_if = fn(yes : Array[Instruction], no : Array[Instruction]) {
    Instruction::if_(BlockType::val_type(bool_ty), yes, Some(no))
  }
  let zero = Instruction::i32_const(I32(0))
  let one = Instruction::i32_const(I32(1))
  let mut params = [ty, ty]
  let mut locals : Array[ValType] = [ty]
  let mut module_ = Module::new()
  let body : Array[Instruction] = match family {
    1 =>
      [
        get(0U),
        eqz,
        Instruction::if_(
          BlockType::void_(),
          [constant(3UL), Instruction::local_set(LocalIdx::new(2U))],
          Some([constant(5UL), Instruction::local_set(LocalIdx::new(2U))]),
        ),
        get(2U),
        constant(0UL),
        ne,
      ]
    2 => {
      // Bounded loops retain a live guard and expose a fact on their exit.
      let bound = 1UL + seed % 31UL
      [
        Instruction::block(
          BlockType::void_(),
          Expr::new([
            Instruction::loop_(
              BlockType::void_(),
              Expr::new([
                get(2U),
                constant(bound),
                ge_u,
                Instruction::br_if(LabelIdx::new(1U)),
                get(2U),
                constant(1UL),
                add,
                Instruction::local_set(LocalIdx::new(2U)),
                Instruction::br(LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        get(2U),
        constant(bound),
        ge_u,
      ]
    }
    3 =>
      [
        get(0U),
        constant(value),
        Instruction::local_tee(LocalIdx::new(0U)),
        eq,
        result_if([get(0U), constant(value), eq], [get(0U), constant(value), eq]),
      ]
    4 => {
      let maximum = if bits == 64 { 0xffffffffffffffffUL } else { 0xffffffffUL }
      [
        get(0U),
        constant(maximum),
        eq,
        result_if(
          [
            get(0U),
            constant(1UL),
            add,
            Instruction::local_set(LocalIdx::new(0U)),
            get(0U),
            eqz,
          ],
          [zero],
        ),
      ]
    }
    5 =>
      [
        get(0U),
        constant(0x100000000UL + seed % 1024UL),
        eq,
        result_if([get(0U), constant(0xffffffffUL), Instruction::i64_gt_u()], [
          zero,
        ]),
      ]
    6 =>
      [
        get(0U),
        constant(10UL),
        ge_u,
        get(0U),
        constant(20UL),
        Instruction::i32_le_u(),
        if (seed & 1UL) == 0UL {
          Instruction::i32_and()
        } else {
          Instruction::i32_or()
        },
        Instruction::i32_eqz(),
        Instruction::i32_eqz(),
        result_if([get(0U), constant(0UL), ne], [get(0U), constant(30UL), lt_u]),
      ]
    7 => {
      params = [ValType::ref_type(RefType::abs(AbsHeapType::extern_()))]
      locals = []
      [
        get(0U),
        Instruction::ref_is_null(),
        result_if([get(0U), Instruction::ref_is_null()], [
          get(0U),
          Instruction::ref_is_null(),
        ]),
      ]
    }
    8 =>
      [
        get(0U),
        eqz,
        Instruction::if_(
          BlockType::void_(),
          [one, Instruction::return_()],
          Some([constant(value), Instruction::local_set(LocalIdx::new(2U))]),
        ),
        get(2U),
        constant(value),
        eq,
      ]
    9 =>
      [
        get(0U),
        get(1U),
        lt_s,
        result_if([get(1U), get(0U), gt_s], [get(0U), get(1U), lt_u]),
      ]
    10 => {
      module_ = module_.with_global_sec(
        GlobalSec::new([
          Global::new(GlobalType::new(bool_ty, true), Expr::new([zero])),
        ]),
      )
      [
        constant(value),
        Instruction::local_tee(LocalIdx::new(0U)),
        constant(value),
        eq,
        result_if(
          [
            one,
            Instruction::global_set(GlobalIdx::new(0U)),
            get(0U),
            constant(value),
            eq,
          ],
          [zero],
        ),
      ]
    }
    11 => {
      params = [ValType::f64()]
      locals = []
      [
        get(0U),
        Instruction::f64_const(F64(1.0)),
        Instruction::f64_ne(),
        result_if([get(0U), get(0U), Instruction::f64_eq()], [one]),
      ]
    }
    _ =>
      // Half the cases expose a provable equality; half retain the signed /
      // unsigned distinction at negative and sign-boundary bit patterns.
      [
        get(0U),
        constant(value),
        if (seed & 1UL) == 0UL {
          eq
        } else {
          lt_s
        },
        result_if(
          [
            get(0U),
            constant(value),
            if (seed & 1UL) == 0UL {
              ne
            } else {
              lt_u
            },
          ],
          [one],
        ),
      ]
  }
  module_
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func(params, [bool_ty]))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types(locals), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_constraint_handler_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let before = (seed.to_uint() ^ 0x12345678U).reinterpret_as_int()
  let initial = Instruction::i32_const(I32(before))
  let after = Instruction::i32_const(I32(before ^ 1))
  let tag = TagIdx::new(0U)
  let thrower = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::if_(BlockType::void_(), [Instruction::throw_(tag)], None),
  ]
  let body = [
    initial,
    Instruction::local_set(LocalIdx::new(1U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::try_table(
          BlockType::val_type(i32),
          [Catch::all(LabelIdx::new(0U))],
          Expr::new([
            Instruction::local_get(LocalIdx::new(0U)),
            Instruction::call(FuncIdx::new(0U)),
            Instruction::i32_const(I32(9)),
          ]),
        ),
        after,
        Instruction::local_tee(LocalIdx::new(1U)),
        Instruction::i32_add(),
        Instruction::drop(),
      ]),
    ),
    Instruction::local_get(LocalIdx::new(1U)),
    initial,
    Instruction::i32_eq(),
  ]
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32], []))),
      RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  .with_code_sec(
    CodeSec::new([
      Func::new(Locals::from_types([]), Expr::new(thrower)),
      Func::new(Locals::from_types([i32]), Expr::new(body)),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(1U))),
    ]),
  )
}

///|
fn gen_valid_constraint_pending_call_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let initial = (seed.to_uint() ^ 0x5342U).reinterpret_as_int()
  let number = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let call = Instruction::call(FuncIdx::new(1U))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_func_sec(
    FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U), TypeIdx::new(0U)]),
  )
  .with_global_sec(
    GlobalSec::new([
      Global::new(GlobalType::new(i32, true), Expr::new([number(initial)])),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::from_types([]),
        Expr::new([Instruction::global_get(GlobalIdx::new(0U))]),
      ),
      Func::new(
        Locals::from_types([]),
        Expr::new([
          number(initial ^ 1),
          Instruction::global_set(GlobalIdx::new(0U)),
        ]),
      ),
      Func::new(
        Locals::from_types([i32, i32]),
        Expr::new([
          number(0),
          Instruction::local_set(LocalIdx::new(0U)),
          Instruction::call(FuncIdx::new(0U)),
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::if_(BlockType::void_(), [call], None),
          number(1),
          Instruction::if_(BlockType::void_(), [call], None),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::local_get(LocalIdx::new(1U)),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
      Export::new(
        Name::from_string("state"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn gen_valid_constraint_tuple_loop_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let f64 = ValType::f64()
  let tuple = BlockType::type_idx(TypeIdx::new(0U))
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let c = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let bound = 1 + (seed % 7UL).to_int()
  let body = [
    Instruction::loop_(
      tuple,
      Expr::new([
        get(0U),
        Instruction::local_tee(LocalIdx::new(2U)),
        c(seed.to_int()),
        Instruction::i32_eq(),
        Instruction::if_(
          tuple,
          [get(2U), Instruction::f64_const(F64(1.25)), Instruction::return_()],
          Some([
            get(1U),
            c(bound),
            Instruction::i32_lt_u(),
            Instruction::if_(
              BlockType::val_type(i32),
              [
                get(1U),
                c(1),
                Instruction::i32_add(),
                Instruction::local_tee(LocalIdx::new(1U)),
                Instruction::drop(),
                c(1),
              ],
              Some([c(0)]),
            ),
            Instruction::if_(
              tuple,
              [Instruction::br(LabelIdx::new(2U))],
              Some([
                get(2U),
                Instruction::f64_const(F64(2.5)),
                Instruction::return_(),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ]
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], [i32, f64]))),
      RecType::new(SubType::comp_type(CompType::func([i32], [i32, f64]))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types([i32, i32]), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_constraint_parameter_loop_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let tuple = BlockType::type_idx(TypeIdx::new(0U))
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  let c = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let variant = ((seed >> 3) % 4UL).to_int()
  let mut loop_body = [
    Instruction::local_tee(LocalIdx::new(1U)),
    get(0U),
    Instruction::i32_lt_u(),
    Instruction::if_(
      BlockType::void_(),
      [
        get(1U),
        c(1),
        Instruction::i32_add(),
        Instruction::br(LabelIdx::new(1U)),
      ],
      None,
    ),
  ]
  if variant == 1 {
    loop_body = [
      Instruction::local_set(LocalIdx::new(1U)),
      get(1U),
      c(1),
      Instruction::i32_add(),
      get(1U),
      get(0U),
      Instruction::i32_lt_u(),
      Instruction::br_if(LabelIdx::new(0U)),
      Instruction::drop(),
    ]
  }
  if variant == 3 {
    // Both loops deliberately share the initial producer. Only the inner
    // loop carries a changing value; its facts must shadow the outer binding.
    loop_body = [Instruction::loop_(tuple, Expr::new(loop_body))]
  }
  let body = [
    get(0U),
    c(1 + (seed % 31UL).to_int()),
    Instruction::i32_and(),
    Instruction::local_set(LocalIdx::new(0U)),
  ]
  if variant == 2 {
    body.push(
      Instruction::block(
        BlockType::val_type(i32),
        Expr::new([
          c(0),
          Instruction::loop_(
            BlockType::type_idx(TypeIdx::new(1U)),
            Expr::new([
              Instruction::local_set(LocalIdx::new(1U)),
              get(1U),
              c(1),
              Instruction::i32_add(),
              get(1U),
              get(0U),
              Instruction::i32_ge_u(),
              Instruction::br_table([LabelIdx::new(0U)], LabelIdx::new(1U)),
            ]),
          ),
        ]),
      ),
    )
    body.push(Instruction::local_set(LocalIdx::new(1U)))
  } else {
    body.push(c(0))
    body.push(Instruction::loop_(tuple, Expr::new(loop_body)))
  }
  body.push(get(1U))
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32], []))),
      RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_code_sec(
    CodeSec::new([Func::new(Locals::from_types([i32]), Expr::new(body))]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_constraint_copied_control_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let c = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let get = fn(index : UInt) { Instruction::local_get(LocalIdx::new(index)) }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_global_sec(
    GlobalSec::new([Global::new(GlobalType::new(i32, true), Expr::new([c(0)]))]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::from_types([i32]),
        Expr::new([
          Instruction::block(
            BlockType::val_type(i32),
            Expr::new([
              get(0U),
              Instruction::if_(
                BlockType::void_(),
                [
                  Instruction::global_get(GlobalIdx::new(0U)),
                  c(1 + (seed % 255UL).to_int()),
                  Instruction::i32_add(),
                  Instruction::global_set(GlobalIdx::new(0U)),
                ],
                None,
              ),
              get(1U),
            ]),
          ),
          Instruction::local_set(LocalIdx::new(2U)),
          get(2U),
          Instruction::i32_eqz(),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
      Export::new(
        Name::from_string("state"),
        ExternIdx::global(GlobalIdx::new(0U)),
      ),
    ]),
  )
}

///|
fn gen_valid_constraint_throwing_stack_module(seed : UInt64) -> Module {
  let i32 = ValType::i32()
  let before = seed.to_uint().reinterpret_as_int() ^ 0x4312
  let c = fn(value : Int) { Instruction::i32_const(I32(value)) }
  let get = fn(slot : UInt) { Instruction::local_get(LocalIdx::new(slot)) }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([i32, i32], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([i32], [i32]))),
      RecType::new(SubType::comp_type(CompType::func([], []))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(1U)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(2U))]))
  .with_code_sec(
    CodeSec::new([
      // The unused argument also exercises DAE2 signature rewriting when this
      // generated shape is passed through that direct-pass lane.
      Func::new(
        Locals::empty(),
        Expr::new([
          get(0U),
          Instruction::if_(
            BlockType::void_(),
            [Instruction::throw_(TagIdx::new(0U))],
            None,
          ),
          c(7),
        ]),
      ),
      Func::new(
        Locals::from_types([i32]),
        Expr::new([
          c(before),
          Instruction::local_set(LocalIdx::new(1U)),
          Instruction::try_(
            BlockType::val_type(i32),
            Expr::new([
              get(0U),
              c(19),
              Instruction::call(FuncIdx::new(0U)),
              get(1U),
              c(before ^ 1),
              Instruction::local_set(LocalIdx::new(1U)),
              Instruction::i32_add(),
            ]),
            [@lib.LegacyCatch::all(Expr::new([get(1U)]))],
          ),
          // This provable fact forces constraint rewriting while keeping the
          // result and handler-visible local observable.
          get(1U),
          get(1U),
          Instruction::i32_eq(),
          Instruction::i32_add(),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(1U))),
    ]),
  )
}
