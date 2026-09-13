///|
test "round2 heap2local preserves failing subtype cast before struct read" {
  let input = pass_test_module_from_wat(
    "(module (type $base (sub (struct (field i32)))) (type $sub (sub $base (struct (field i32)))) (func (result i32) unreachable))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
          @lib.Instruction::ref_cast(
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          ),
          @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(0U)),
        ]),
      ),
    ]),
  )
  let output = audit_run_module(input, "heap2local")
  assert_true(
    audit_count(audit_body(output), fn(i) {
      i is @lib.RefCast(_) || i is @lib.Unreachable
    }) >
    0,
  )
}

///|
test "round2 heap2local nullable descriptor trap struct.new_desc" {
  let output = audit_run(
    (
      #|(module (rec (type $node (descriptor $desc) (struct)) (type $desc (describes $node) (struct))) (func (param (ref null (exact $desc))) (result (ref $desc)) (ref.get_desc $node (struct.new_desc $node (local.get 0)))))
    ),
    "heap2local",
  )
  assert_true(@validate.validate_module(output).is_ok())
  assert_true(
    audit_count(audit_body(output, index=0), fn(i) {
      i is @lib.RefAsNonNull ||
      i is @lib.StructNewDesc(_) ||
      i is @lib.StructNewDefaultDesc(_)
    }) >
    0,
  )
}

///|
test "round2 heap2local nullable descriptor trap struct.new_default_desc" {
  let output = audit_run(
    (
      #|(module (rec (type $node (descriptor $desc) (struct)) (type $desc (describes $node) (struct))) (func (param (ref null (exact $desc))) (result (ref $desc)) (ref.get_desc $node (struct.new_default_desc $node (local.get 0)))))
    ),
    "heap2local",
  )
  assert_true(@validate.validate_module(output).is_ok())
  assert_true(
    audit_count(audit_body(output, index=0), fn(i) {
      i is @lib.RefAsNonNull ||
      i is @lib.StructNewDesc(_) ||
      i is @lib.StructNewDefaultDesc(_)
    }) >
    0,
  )
}
