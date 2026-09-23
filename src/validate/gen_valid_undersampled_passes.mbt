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
    max_type_defs: 2,
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
      if seed % 2UL == 0UL {
        Some("duplicate-function-elimination:exact-pair")
      } else {
        Some("duplicate-function-elimination:fixed-point-callers")
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
  let type_idx = TypeIdx::new(0U)
  let value = 1 + ((seed >> 1) % 1000003UL).to_int()
  let funcs : Array[Func] = [
    Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(value))])),
    Func::new(Locals::empty(), Expr::new([Instruction::i32_const(I32(value))])),
  ]
  let type_idxs : Array[TypeIdx] = [type_idx, type_idx]
  if seed % 2UL == 0UL {
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
