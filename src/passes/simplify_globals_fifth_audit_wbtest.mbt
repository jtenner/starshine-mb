///|
test "fifth audit simplify globals preserves continuation target arity" {
  let input = pass_test_module_from_wat(
    "(module (type $s (func)) (type $c (func)) (tag $e) (func (param (ref $c))))",
  )
  let types = input.type_sec.unwrap().0.copy()
  types[1] = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
  )
  let cont = @lib.TypeIdx::new(1U)
  let ref_ = @lib.ValType::ref_null(@lib.HeapType::new(cont))
  let bt = @lib.BlockType::val_type(ref_)
  let input = input
    .with_type_sec(@lib.TypeSec::new(types))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              bt,
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::resume_(cont, [
                      @lib.ResumeHandler::on_label(
                        @lib.TagIdx::new(0U),
                        @lib.LabelIdx::new(1U),
                      ),
                    ]),
                  ]),
                ),
                @lib.Instruction::ref_null(@lib.HeapType::new(cont)),
                @lib.Instruction::br(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("continuation fixture: \{err}")
  }
  let output = sgo_apply_void_dropped_terminal_result_blocks(input)
  assert_true(@validate.validate_module(output).is_ok())
}
