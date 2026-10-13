///|
fn gen_valid_undersampled_pass_profile_config(
  profile : GenValidProfile,
) -> GenValidConfig {
  let base = GenValidConfig::binaryen_oracle_coverage_forced_default()
  let family_id = match profile {
    LocalCseTriggerProfile => 1
    DuplicateFunctionEliminationTriggerProfile => 2
    _ => 1
  }
  GenValidConfig::{
    ..base,
    max_type_defs: if family_id == 2 {
      5
    } else {
      2
    },
    max_defined_funcs: 4,
    max_params: 2,
    max_results: 1,
    max_locals: 0,
    max_body_statements: 240 + family_id,
    max_body_depth: 2,
  }
}

///|
fn gen_valid_is_undersampled_pass_profile_config(
  config : GenValidConfig,
) -> Bool {
  config == gen_valid_undersampled_pass_profile_config(LocalCseTriggerProfile) ||
  config ==
  gen_valid_undersampled_pass_profile_config(
    DuplicateFunctionEliminationTriggerProfile,
  )
}

///|
fn gen_valid_undersampled_pass_profile_kind(
  config : GenValidConfig,
) -> GenValidProfile {
  if config ==
    gen_valid_undersampled_pass_profile_config(
      DuplicateFunctionEliminationTriggerProfile,
    ) {
    DuplicateFunctionEliminationTriggerProfile
  } else {
    LocalCseTriggerProfile
  }
}

///|
pub fn gen_valid_undersampled_pass_profile_case_label(
  profile : GenValidProfile,
  seed : UInt64,
) -> String? {
  match profile {
    LocalCseTriggerProfile =>
      match (seed % 3UL).to_int() {
        0 => Some("local-cse:repeated-add")
        1 => Some("local-cse:repeated-sub")
        _ => Some("local-cse:repeated-xor")
      }
    DuplicateFunctionEliminationTriggerProfile =>
      match (seed % 3UL).to_int() {
        0 => Some("duplicate-function-elimination:exact-pair")
        1 => Some("duplicate-function-elimination:fixed-point-callers")
        _ => Some("duplicate-function-elimination:canonical-primitive-roots")
      }
    _ => None
  }
}

///|
fn gen_valid_undersampled_lcse_module(seed : UInt64) -> Module {
  let op = match (seed % 3UL).to_int() {
    0 => Instruction::i32_add()
    1 => Instruction::i32_sub()
    _ => Instruction::i32_xor()
  }
  let body = [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
    op,
    Instruction::drop(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
    op,
    Instruction::drop(),
  ]
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(CompType::func([ValType::i32(), ValType::i32()], [])),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
}

///|
fn gen_valid_undersampled_dfe_module(seed : UInt64) -> Module {
  if seed % 3UL == 2UL {
    return gen_valid_undersampled_dfe_gc_module(seed)
  }
  let type_idx = TypeIdx::new(0U)
  let value = 1 + ((seed >> 1) % 1000003UL).to_int()
  let funcs : Array[Func] = [
    Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(value))])),
    Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(value))])),
  ]
  let type_idxs : Array[TypeIdx] = [type_idx, type_idx]
  if seed % 3UL == 0UL {
    funcs.push(
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::i32_const(I32(value + 1))]),
      ),
    )
    type_idxs.push(type_idx)
  } else {
    funcs.push(
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::call(FuncIdx::new(0U))]),
      ),
    )
    funcs.push(
      Func::new(
        Locals::empty(),
        Expr::new([Instruction::call(FuncIdx::new(1U))]),
      ),
    )
    type_idxs.push(type_idx)
    type_idxs.push(type_idx)
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
    ]),
  )
  .with_func_sec(FuncSec::new(type_idxs))
  .with_code_sec(CodeSec::new(funcs))
}

///|
fn gen_valid_undersampled_pass_profile_module(ctx : GenValidContext) -> Module {
  match gen_valid_undersampled_pass_profile_kind(ctx.config) {
    DuplicateFunctionEliminationTriggerProfile =>
      gen_valid_undersampled_dfe_module(ctx.root_seed)
    _ => gen_valid_undersampled_lcse_module(ctx.root_seed)
  }
}

///|
// Distinct function bodies and a scalar entry ensure the type-only trigger is
// exercised independently of whole-function merging and GC host arguments.
fn gen_valid_undersampled_dfe_gc_module(seed : UInt64) -> Module {
  let first = TypeIdx::new(0U)
  let alias = TypeIdx::new(1U)
  let root = RecType::new(
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(StorageType::val_type(ValType::i32()), Mut::const_()),
      ]),
    ),
  )
  let value = 1 + (seed / 3UL % 1000003UL).to_int()
  Module::new()
  .with_type_sec(
    TypeSec::new([
      root,
      root,
      RecType::new(
        SubType::comp_type(
          CompType::func([], [
            ValType::ref_type(RefType::new(false, HeapType::new(alias))),
          ]),
        ),
      ),
      RecType::new(
        SubType::comp_type(
          CompType::func(
            [ValType::ref_type(RefType::new(false, HeapType::new(first)))],
            [ValType::i32()],
          ),
        ),
      ),
      RecType::new(SubType::comp_type(CompType::func([], [ValType::i32()]))),
    ]),
  )
  .with_func_sec(
    FuncSec::new([TypeIdx::new(2U), TypeIdx::new(3U), TypeIdx::new(4U)]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(2U))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::i32_const(I32(value)),
          Instruction::struct_new(alias),
        ]),
      ),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::local_get(LocalIdx::new(0U)),
          Instruction::struct_get(first, U32(0U)),
        ]),
      ),
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::call(FuncIdx::new(0U)),
          Instruction::call(FuncIdx::new(1U)),
        ]),
      ),
    ]),
  )
}
