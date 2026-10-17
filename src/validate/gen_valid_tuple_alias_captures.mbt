///|
fn gen_valid_tuple_alias_captures_config() -> GenValidConfig {
  let base = gen_valid_tuple_optimization_profile_config(
    TupleOptimizationSpillProfile,
  )
  GenValidConfig::{
    ..base,
    max_defined_funcs: 2,
    max_params: 1,
    max_results: 2,
    max_locals: 9,
    max_body_statements: 16,
    max_body_depth: 3,
  }
}

///|
fn gen_valid_tuple_alias_captures_body(
  seed : UInt64,
  delayed : Bool,
) -> Array[Instruction] {
  let first = 11 + (seed & 31UL).to_int()
  let second = 100 + ((seed >> 5) & 31UL).to_int()
  let variant = seed % 3UL
  let capture = [
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::local_set(LocalIdx::new(3U)),
    Instruction::local_get(LocalIdx::new(2U)),
    Instruction::local_set(LocalIdx::new(4U)),
  ]
  if variant == 2UL {
    capture.append([
      Instruction::local_get(LocalIdx::new(3U)),
      Instruction::local_set(LocalIdx::new(5U)),
      Instruction::local_get(LocalIdx::new(4U)),
      Instruction::local_set(LocalIdx::new(6U)),
    ])
  }
  let saved_first = LocalIdx::new(if variant == 2UL { 5U } else { 3U })
  let saved_second = LocalIdx::new(if variant == 2UL { 6U } else { 4U })
  let copy_body = if variant == 1UL {
    [
      Instruction::local_get(saved_first),
      Instruction::local_get(saved_second),
      Instruction::local_set(LocalIdx::new(8U)),
    ]
  } else {
    [
      Instruction::local_get(saved_second),
      Instruction::local_set(LocalIdx::new(8U)),
      Instruction::local_get(saved_first),
    ]
  }
  let copy = [
    Instruction::block(
      BlockType::val_type(ValType::i32()),
      Expr::new(copy_body),
    ),
    Instruction::local_set(LocalIdx::new(7U)),
  ]
  let loop_body = [
    Instruction::block(
      BlockType::type_idx(TypeIdx::new(1U)),
      Expr::new([
        Instruction::local_get(LocalIdx::new(9U)),
        Instruction::i32_const(I32(first)),
        Instruction::i32_add(),
        Instruction::local_get(LocalIdx::new(9U)),
        Instruction::i32_const(I32(second)),
        Instruction::i32_add(),
      ]),
    ),
    Instruction::local_set(LocalIdx::new(2U)),
    Instruction::local_set(LocalIdx::new(1U)),
  ]
  // Every captured/output lane has one lexical write. Extra initializers
  // would hide the alias resolver's stale-capture trigger from this profile.
  if delayed {
    loop_body.append(copy)
    loop_body.append(capture)
  } else {
    loop_body.append([
      Instruction::local_get(LocalIdx::new(9U)),
      Instruction::i32_eqz(),
      Instruction::if_(BlockType::void_(), capture, None),
    ])
    loop_body.append(copy)
  }
  loop_body.append([
    Instruction::local_get(LocalIdx::new(9U)),
    Instruction::i32_const(I32(1)),
    Instruction::i32_add(),
    Instruction::local_tee(LocalIdx::new(9U)),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_lt_s(),
    Instruction::br_if(LabelIdx::new(0U)),
  ])
  [
    // Bound every host argument to 1..4 iterations, including negative values.
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_const(I32(3)),
    Instruction::i32_and(),
    Instruction::i32_const(I32(1)),
    Instruction::i32_add(),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::loop_(BlockType::void_(), Expr::new(loop_body)),
    Instruction::local_get(LocalIdx::new(7U)),
    Instruction::local_get(LocalIdx::new(8U)),
  ]
}

///|
fn gen_valid_tuple_alias_captures_module(seed : UInt64) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(
          CompType::func([ValType::i32()], [ValType::i32(), ValType::i32()]),
        ),
      ),
      RecType::new(
        SubType::comp_type(CompType::func([], [ValType::i32(), ValType::i32()])),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U), TypeIdx::new(0U)]))
  .with_export_sec(
    ExportSec::new([
      Export::new(
        Name::from_string("snapshot"),
        ExternIdx::func(FuncIdx::new(0U)),
      ),
      Export::new(
        Name::from_string("delayed"),
        ExternIdx::func(FuncIdx::new(1U)),
      ),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::single(9U, ValType::i32()),
        Expr::new(gen_valid_tuple_alias_captures_body(seed, false)),
      ),
      Func::new(
        Locals::single(9U, ValType::i32()),
        Expr::new(gen_valid_tuple_alias_captures_body(seed, true)),
      ),
    ]),
  )
}
