///|
fn gen_valid_heap2local_owner_updates_config() -> GenValidConfig {
  let base = gen_valid_heap2local_profile_config(Heap2LocalStructProfile)
  GenValidConfig::{
    ..base,
    max_type_defs: 2,
    max_params: 3,
    max_results: 3,
    max_locals: 1,
    max_body_statements: 4,
    features: GenValidFeatureToggles::{
      ..base.features,
      allow_heap2local_body_generator: false,
    },
  }
}

///|
fn gen_valid_heap2local_owner_append_read(
  body : Array[Instruction],
  field : UInt32,
  delta : Int32,
) -> Unit {
  body.push(Instruction::local_get(LocalIdx::new(3U)))
  body.push(Instruction::struct_get(TypeIdx::new(0U), U32::new(field)))
  if delta != 0 {
    body.push(Instruction::i32_const(I32(delta)))
    body.push(Instruction::i32_add())
  }
}

///|
fn gen_valid_heap2local_owner_arm(
  seed : UInt64,
  epoch : Int32,
  branch : Int32,
) -> Array[Instruction] {
  let body : Array[Instruction] = []
  let base = 10 + ((seed >> 8) & 255UL).to_int()
  // Each condition changes an exported field. Keep the numbers small so
  // numeric observations do not depend on overflow or host conversions.
  let delta = 1 + branch * (1 + ((seed >> 16) & 15UL).to_int())
  if epoch == 0 {
    for field = 0; field < 3; field = field + 1 {
      body.push(Instruction::i32_const(I32(base + field * 100 + delta)))
    }
  } else if epoch == 1 {
    match seed % 3UL {
      0UL => {
        // Swapped fields must both read the owner from the preceding epoch.
        gen_valid_heap2local_owner_append_read(body, 1U, delta)
        gen_valid_heap2local_owner_append_read(body, 0U, 0)
        gen_valid_heap2local_owner_append_read(body, 2U, 0)
      }
      1UL => {
        // A three-field cycle requires staging all operands before publication.
        gen_valid_heap2local_owner_append_read(body, 1U, delta)
        gen_valid_heap2local_owner_append_read(body, 2U, 0)
        gen_valid_heap2local_owner_append_read(body, 0U, 0)
      }
      _ => {
        // The new first field must not replace the old field while the later
        // operands still read it. This is the read-after-write regression.
        body.push(Instruction::i32_const(I32(base + 500 + delta)))
        gen_valid_heap2local_owner_append_read(body, 0U, 0)
        gen_valid_heap2local_owner_append_read(body, 1U, 0)
      }
    }
  } else {
    gen_valid_heap2local_owner_append_read(body, 2U, delta)
    gen_valid_heap2local_owner_append_read(body, 0U, 0)
    gen_valid_heap2local_owner_append_read(body, 1U, 0)
  }
  body.push(Instruction::struct_new(TypeIdx::new(0U)))
  body
}

///|
fn gen_valid_heap2local_owner_updates_module(seed : UInt64) -> Module {
  let owner_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0U))),
  )
  let fresh_ref = ValType::ref_type(
    RefType::new(false, HeapType::new(TypeIdx::new(0U))),
  )
  let body : Array[Instruction] = []
  for epoch = 0; epoch < 3; epoch = epoch + 1 {
    body.push(Instruction::local_get(LocalIdx::new(epoch.to_uint())))
    body.push(
      Instruction::if_(
        BlockType::val_type(fresh_ref),
        gen_valid_heap2local_owner_arm(seed, epoch, 0),
        Some(gen_valid_heap2local_owner_arm(seed, epoch, 1)),
      ),
    )
    body.push(Instruction::local_set(LocalIdx::new(3U)))
  }
  for field = 0U; field < 3U; field = field + 1U {
    gen_valid_heap2local_owner_append_read(body, field, 0)
  }
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(
          CompType::struct_([
            FieldType::new(StorageType::val_type(ValType::i32()), Const),
            FieldType::new(StorageType::val_type(ValType::i32()), Const),
            FieldType::new(StorageType::val_type(ValType::i32()), Const),
          ]),
        ),
      ),
      RecType::new(
        SubType::comp_type(
          CompType::func([ValType::i32(), ValType::i32(), ValType::i32()], [
            ValType::i32(),
            ValType::i32(),
            ValType::i32(),
          ]),
        ),
      ),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(1U)]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::from_string("run"), ExternIdx::func(FuncIdx::new(0U))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([Func::new(Locals::single(1U, owner_ref), Expr::new(body))]),
  )
}
