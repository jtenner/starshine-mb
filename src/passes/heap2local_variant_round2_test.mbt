///|
fn round2_heap_variant_input(kind : Int) -> @lib.Module {
  let base = @lib.TypeIdx::new(0U)
  let sub = @lib.TypeIdx::new(1U)
  let owner = @lib.LocalIdx::new(1U)
  let cast = @lib.Instruction::ref_cast(false, @lib.HeapType::new(sub))
  let read = @lib.Instruction::struct_get(base, @lib.U32(0U))
  let body : Array[@lib.Instruction] = []
  if kind == 3 {
    body.append([@lib.Instruction::local_get(owner), read, @lib.Instruction::drop()])
  }
  body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::ref_type(@lib.RefType::new(false, @lib.HeapType::new(base)))),
      [@lib.Instruction::i32_const(@lib.I32(11)), @lib.Instruction::struct_new(sub)],
      Some([@lib.Instruction::i32_const(@lib.I32(22)), @lib.Instruction::struct_new(base)]),
    ),
  ])
  match kind {
    0 => body.append([@lib.Instruction::local_tee(owner), cast, read])
    1 => body.append([@lib.Instruction::local_set(owner), @lib.Instruction::local_get(owner), cast, read])
    2 => body.append([cast, @lib.Instruction::local_set(owner), @lib.Instruction::local_get(owner), read])
    _ => body.append([@lib.Instruction::local_set(owner), @lib.Instruction::local_get(owner), read])
  }
  pass_test_module_from_wat(
    "(module (type $base (sub (struct (field i32)))) (type $sub (sub $base (struct (field i32)))) (func (param i32) (result i32) unreachable))",
  ).with_code_sec(@lib.CodeSec::new([@lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::ref_type(@lib.RefType::new(true, @lib.HeapType::new(base)))]),
    @lib.Expr::new(body),
  )]))
}

///|
test "round2 heap variant preserves cast after tee" {
  let output = audit_run_module(round2_heap_variant_input(0), "heap2local")
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.RefCast(_) || i is @lib.Unreachable }) > 0)
}

///|
test "round2 heap variant preserves cast after read" {
  let output = audit_run_module(round2_heap_variant_input(1), "heap2local")
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.RefCast(_) || i is @lib.Unreachable }) > 0)
}

///|
test "round2 heap variant preserves cast before write" {
  let output = audit_run_module(round2_heap_variant_input(2), "heap2local")
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.RefCast(_) || i is @lib.Unreachable }) > 0)
}

///|
test "round2 heap variant preserves uninitialized read trap" {
  let output = audit_run_module(round2_heap_variant_input(3), "heap2local")
  assert_true(audit_count(audit_body(output), fn(i) { i is @lib.StructGet(_) || i is @lib.Unreachable }) > 0)
}
