///|
fn gen_valid_msf_profile_config(profile : GenValidProfile) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let family_id = match profile {
    MergeSimilarFunctionsLiteralsProfile => 1
    MergeSimilarFunctionsRepeatedDiffProfile => 2
    MergeSimilarFunctionsLocalsProfile => 3
    MergeSimilarFunctionsNestedProfile => 4
    MergeSimilarFunctionsCallTargetsProfile => 5
    MergeSimilarFunctionsTailCallsProfile => 6
    MergeSimilarFunctionsExactDuplicatesProfile => 7
    MergeSimilarFunctionsDuplicateTypesProfile => 8
    _ => 1
  }
  GenValidConfig::{
    ..base,
    max_type_defs: 4,
    max_imports: 0,
    max_defined_funcs: 10,
    max_tables: 0,
    max_mems: 0,
    max_globals: 0,
    max_tags: 0,
    max_elems: 2,
    max_datas: 0,
    max_params: 2,
    max_results: 1,
    max_locals: 4,
    max_body_statements: 160 + family_id,
    max_body_depth: 8,
  }
}

///|
fn gen_valid_is_msf_profile_config(config : GenValidConfig) -> Bool {
  config == gen_valid_msf_profile_config(MergeSimilarFunctionsLiteralsProfile) ||
  config ==
  gen_valid_msf_profile_config(MergeSimilarFunctionsRepeatedDiffProfile) ||
  config ==
  gen_valid_msf_profile_config(MergeSimilarFunctionsExactDuplicatesProfile) ||
  config ==
  gen_valid_msf_profile_config(MergeSimilarFunctionsDuplicateTypesProfile) ||
  config == gen_valid_msf_profile_config(MergeSimilarFunctionsLocalsProfile) ||
  config == gen_valid_msf_profile_config(MergeSimilarFunctionsNestedProfile) ||
  config ==
  gen_valid_msf_profile_config(MergeSimilarFunctionsCallTargetsProfile) ||
  config == gen_valid_msf_profile_config(MergeSimilarFunctionsTailCallsProfile)
}

///|
fn gen_valid_msf_profile_kind(config : GenValidConfig) -> GenValidProfile {
  for
    profile in [
      MergeSimilarFunctionsLiteralsProfile,
      MergeSimilarFunctionsRepeatedDiffProfile,
      MergeSimilarFunctionsExactDuplicatesProfile,
      MergeSimilarFunctionsDuplicateTypesProfile,
      MergeSimilarFunctionsLocalsProfile,
      MergeSimilarFunctionsNestedProfile,
      MergeSimilarFunctionsCallTargetsProfile,
      MergeSimilarFunctionsTailCallsProfile,
    ] {
    if config == gen_valid_msf_profile_config(profile) {
      return profile
    }
  }
  MergeSimilarFunctionsLiteralsProfile
}

///|
pub fn gen_valid_msf_profile_case_label(
  profile : GenValidProfile,
  seed : UInt64,
) -> String? {
  let class_size = 2 + (seed % 4UL).to_int()
  let suffix = "class-\{class_size}"
  match profile {
    MergeSimilarFunctionsLiteralsProfile => Some("msf:literals:\{suffix}")
    MergeSimilarFunctionsRepeatedDiffProfile =>
      Some("msf:repeated-diff-vector:\{suffix}")
    MergeSimilarFunctionsExactDuplicatesProfile =>
      Some("msf:exact-duplicates:\{suffix}")
    MergeSimilarFunctionsDuplicateTypesProfile =>
      Some("msf:duplicate-types:\{suffix}")
    MergeSimilarFunctionsLocalsProfile => Some("msf:local-shift:\{suffix}")
    MergeSimilarFunctionsNestedProfile => Some("msf:nested-control:\{suffix}")
    MergeSimilarFunctionsCallTargetsProfile =>
      Some("msf:call-targets:\{suffix}")
    MergeSimilarFunctionsTailCallsProfile =>
      Some("msf:tail-call-targets:\{suffix}")
    _ => None
  }
}

///|
fn gen_valid_msf_nops(count : Int) -> Array[Instruction] {
  let out : Array[Instruction] = []
  for idx = 0; idx < count; idx = idx + 1 {
    out.push(Instruction::i32_const(I32(1000 + idx)))
    out.push(Instruction::drop())
  }
  out
}

///|
fn gen_valid_msf_i32_func_type(params : Array[ValType]) -> RecType {
  RecType::new(SubType::comp_type(CompType::func(params, [ValType::i32()])))
}

///|
fn gen_valid_msf_literal_value(seed : UInt64, ordinal : Int, lane : Int) -> Int {
  let mixed = seed ^
    ((ordinal + 1).to_uint64() * 0x9e3779b97f4a7c15UL) ^
    ((lane + 1).to_uint64() * 0xbf58476d1ce4e5b9UL)
  1 + (mixed % 1000003UL).to_int()
}

///|
fn gen_valid_msf_literal_module(seed : UInt64) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let nop_count = 16 + ((seed >> 3) % 9UL).to_int()
  let diff_count = 1 + ((seed >> 7) % 4UL).to_int()
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let body = gen_valid_msf_nops(nop_count)
    for lane = 0; lane < diff_count - 1; lane = lane + 1 {
      body.push(
        Instruction::i32_const(
          I32(gen_valid_msf_literal_value(seed, ordinal, lane)),
        ),
      )
      body.push(Instruction::drop())
    }
    body.push(
      Instruction::i32_const(
        I32(gen_valid_msf_literal_value(seed, ordinal, diff_count - 1)),
      ),
    )
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_repeated_diff_module(seed : UInt64) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let nop_count = 16 + ((seed >> 5) % 7UL).to_int()
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let value = gen_valid_msf_literal_value(seed, ordinal, 0)
    let body = gen_valid_msf_nops(nop_count)
    body.push(Instruction::i32_const(I32(value)))
    body.push(Instruction::i32_const(I32(value)))
    body.push(Instruction::i32_add())
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_exact_duplicates_module(seed : UInt64) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let filler_count = 16 + ((seed >> 5) % 7UL).to_int()
  let shared_value = gen_valid_msf_literal_value(seed, 0, 0)
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    ignore(ordinal)
    let body = gen_valid_msf_nops(filler_count)
    body.push(Instruction::i32_const(I32(shared_value)))
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_duplicate_types_module(seed : UInt64) -> Module {
  let class_size = 2 + (seed % 4UL).to_int()
  let filler_count = 16 + ((seed >> 5) % 7UL).to_int()
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let body = gen_valid_msf_nops(filler_count)
    body.push(
      Instruction::i32_const(I32(gen_valid_msf_literal_value(seed, ordinal, 0))),
    )
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(TypeIdx::new((ordinal % 2).reinterpret_as_uint()))
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      gen_valid_msf_i32_func_type([]),
      gen_valid_msf_i32_func_type([]),
    ]),
  )
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_locals_module(seed : UInt64) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let nop_count = 18 + ((seed >> 5) % 7UL).to_int()
  let local_count = 1 + ((seed >> 9) % 4UL).to_int()
  let locals = Locals::single(local_count.reinterpret_as_uint(), ValType::i32())
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let body = gen_valid_msf_nops(nop_count)
    body.push(
      Instruction::i32_const(I32(gen_valid_msf_literal_value(seed, ordinal, 0))),
    )
    body.push(Instruction::local_get(LocalIdx::new(0U)))
    body.push(Instruction::i32_add())
    for local_idx = 0; local_idx < local_count; local_idx = local_idx + 1 {
      body.push(
        Instruction::local_get(
          LocalIdx::new((1 + local_idx).reinterpret_as_uint()),
        ),
      )
      body.push(Instruction::i32_add())
    }
    funcs.push(Func::new(locals.copy(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([ValType::i32()])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_nested_module(seed : UInt64) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let nop_count = 16 + ((seed >> 4) % 7UL).to_int()
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let value = gen_valid_msf_literal_value(seed, ordinal, 0)
    let body = gen_valid_msf_nops(nop_count)
    let nested = if ((seed >> 10) & 1UL) == 0UL {
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([Instruction::i32_const(I32(value))]),
      )
    } else {
      body.push(Instruction::i32_const(I32(1)))
      Instruction::if_(
        BlockType::val_type(ValType::i32()),
        [Instruction::i32_const(I32(value))],
        Some([Instruction::i32_const(I32(value + 1))]),
      )
    }
    body.push(nested)
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
}

///|
fn gen_valid_msf_call_target_module(seed : UInt64, tail_calls : Bool) -> Module {
  let type_idx = TypeIdx::new(0U)
  let class_size = 2 + (seed % 4UL).to_int()
  let nop_count = 18 + ((seed >> 5) % 7UL).to_int()
  let funcs : Array[Func] = []
  let type_idxs : Array[TypeIdx] = []
  let declared : Array[FuncIdx] = []
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    funcs.push(
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(
            I32(gen_valid_msf_literal_value(seed, ordinal, 0)),
          ),
        ]),
      ),
    )
    type_idxs.push(type_idx)
    declared.push(FuncIdx::new(ordinal.reinterpret_as_uint()))
  }
  for ordinal = 0; ordinal < class_size; ordinal = ordinal + 1 {
    let body = gen_valid_msf_nops(nop_count)
    if !tail_calls {
      body.push(
        Instruction::i32_const(
          I32(gen_valid_msf_literal_value(seed, ordinal, 1)),
        ),
      )
      body.push(Instruction::drop())
    }
    body.push(
      if tail_calls {
        Instruction::return_call(FuncIdx::new(ordinal.reinterpret_as_uint()))
      } else {
        Instruction::call(FuncIdx::new(ordinal.reinterpret_as_uint()))
      },
    )
    funcs.push(Func::new(Locals::empty(), Expr::new(body)))
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(TypeSec::new([gen_valid_msf_i32_func_type([])]))
  .with_func_sec(FuncSec::new(type_idxs))
  .with_elem_sec(
    ElemSec::new([Elem::new(ElemMode::declarative(), ElemKind::funcs(declared))]),
  )
  .with_code_sec(CodeSec::new(funcs))
  .with_export_sec(
    ExportSec::new([
      Export::new(
        Name::from_string("run"),
        ExternIdx::func(FuncIdx::new(class_size.reinterpret_as_uint())),
      ),
    ]),
  )
}

///|
fn gen_valid_msf_profile_module(ctx : GenValidContext) -> Module {
  match gen_valid_msf_profile_kind(ctx.config) {
    MergeSimilarFunctionsLiteralsProfile =>
      gen_valid_msf_literal_module(ctx.root_seed)
    MergeSimilarFunctionsRepeatedDiffProfile =>
      gen_valid_msf_repeated_diff_module(ctx.root_seed)
    MergeSimilarFunctionsExactDuplicatesProfile =>
      gen_valid_msf_exact_duplicates_module(ctx.root_seed)
    MergeSimilarFunctionsDuplicateTypesProfile =>
      gen_valid_msf_duplicate_types_module(ctx.root_seed)
    MergeSimilarFunctionsLocalsProfile =>
      gen_valid_msf_locals_module(ctx.root_seed)
    MergeSimilarFunctionsNestedProfile =>
      gen_valid_msf_nested_module(ctx.root_seed)
    MergeSimilarFunctionsCallTargetsProfile =>
      gen_valid_msf_call_target_module(ctx.root_seed, false)
    MergeSimilarFunctionsTailCallsProfile =>
      gen_valid_msf_call_target_module(ctx.root_seed, true)
    _ => gen_valid_msf_literal_module(ctx.root_seed)
  }
}
