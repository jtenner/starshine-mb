///|
test "fifth audit command multivalue allocation return" {
  let input = @passes.pass_test_module_from_wat("(module (type $A (array (mut i32))) (type $B (func (result (ref $A) i32))) (func (result (ref $A)) unreachable))")
  let input = input.with_code_sec(@lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([
    @lib.Instruction::block(@lib.BlockType::type_idx(@lib.TypeIdx::new(1U)), @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::array_new_default(@lib.TypeIdx::new(0U)),
      @lib.Instruction::return_(),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    ])), @lib.Instruction::drop(),
  ]))]))
  let output = cmd_deep_audit_run_module(input, "heap2local")
  assert_true(@validate.validate_module(output).is_ok())
}
