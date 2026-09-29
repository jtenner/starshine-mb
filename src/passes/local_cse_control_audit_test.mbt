///|
test "local-cse keeps descriptor branch label owners before unreachable" {
  let base = pass_test_module_from_wat(
    "(module (rec (type $s (descriptor $d) (struct)) (type $d (describes $s) (struct))) (func (param (ref null $s)) (param (ref (exact $d))) (result (ref null $s)) unreachable))",
  )
  let ref_ = @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U)))
  for
    branch in [
      @lib.Instruction::br_on_cast_desc_eq(@lib.LabelIdx::new(0U), ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(
        @lib.LabelIdx::new(0U),
        ref_,
        ref_,
      ),
    ] {
    let input = base.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::ref_type(ref_)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                branch,
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(
                  @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                ),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
      ]),
    )
    assert_true(@validate.validate_module(input) is Ok(_))
    let output = audit_run_module(input, "local-cse")
    assert_true(@validate.validate_module(output) is Ok(_))
    assert_true(
      audit_body(output)[0] is @lib.Block(_, _),
      msg=audit_body(output).to_string(),
    )
  }
}
