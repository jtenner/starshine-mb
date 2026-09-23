///|
test "round2 local cse distinct signed zero" {
  let output = audit_run(
    (
      #|(module (func (result i32) (drop (i32.reinterpret_f32 (f32.const 0))) (i32.reinterpret_f32 (f32.const -0))))
    ),
    "local-cse",
  )
  assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], []), [
    -2147483648L,
  ])
}

///|
test "round2 local cse nested local writes" {
  let output = audit_run(
    (
      #|(module (func (param i32) (result i32) (drop (i32.add (local.get 0) (i32.const 1))) (block (result i32) (block (local.set 0 (i32.const 10))) (i32.add (local.get 0) (i32.const 1)))))
    ),
    "local-cse",
  )
  assert_eq(try! scalar_fixture_run(output.code_sec.unwrap().0[0], [2L]), [11L])
}

///|
test "round2 local cse nested bulk writes" {
  let output = audit_run(
    (
      #|(module (memory 1) (func (result i32) (drop (i32.load (i32.const 0))) (block (result i32) (memory.fill (i32.const 0) (i32.const 1) (i32.const 4)) (i32.load (i32.const 0)))))
    ),
    "local-cse",
  )
  assert_eq(
    audit_count(audit_body(output, index=0), fn(i) { i is @lib.I32Load(_) }),
    2,
  )
}

///|
test "round2 local cse nested struct atomic write invalidates heap reads" {
  let output = audit_run(
    (
      #|(module
      #| (type $S (struct (field (mut i32))))
      #| (func (param (ref $S)) (result i32)
      #|  (drop (struct.get $S 0 (local.get 0)))
      #|  (block (result i32)
      #|   (struct.atomic.set relaxed $S 0 (local.get 0) (i32.const 9))
      #|   (struct.get $S 0 (local.get 0)))))
    ),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(
    audit_count(audit_body(output), fn(i) { i is @lib.StructGet(_, _) }),
    2,
  )
}

///|
test "round2 local cse nested array atomic write invalidates heap reads" {
  let array_output = audit_run_module(
    local_cse_round2_array_write_module(true),
    "local-cse",
  )
  assert_true(@validate.validate_module(array_output) is Ok(_))
  assert_eq(
    audit_count(audit_body(array_output), fn(i) { i is @lib.ArrayGet(_) }),
    2,
  )
}

///|
test "round2 local cse nested array store invalidates heap reads" {
  let output = audit_run_module(
    local_cse_round2_array_write_module(false),
    "local-cse",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_eq(audit_count(audit_body(output), fn(i) { i is @lib.ArrayGet(_) }), 2)
}

///|
fn local_cse_round2_array_write_module(atomic_write : Bool) -> @lib.Module {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([array_ref], [@lib.ValType::i32()]),
    ),
  )
  let nested = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_const(9),
    if atomic_write {
      @lib.Instruction::array_atomic_set(
        @lib.AtomicOrder::relaxed(),
        array_type_idx,
      )
    } else {
      @lib.Instruction::array_store(@lib.StoreOp::i32_store(), array_type_idx)
    },
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(0),
    @lib.Instruction::array_get(array_type_idx),
  ]
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
  .with_func_sec(@lib.FuncSec::new([func_type_idx]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i32_const(0),
          @lib.Instruction::array_get(array_type_idx),
          @lib.Instruction::drop(),
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new(nested),
          ),
        ]),
      ),
    ]),
  )
}
