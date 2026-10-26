// F05 regression copied from hunt/daybreak-starshine-r1 at
// 49b757b94b4dfd1a11394aa11081777ddf686b90.
// This invalid legacy try must fail validation: catch_all must be last.

///|
test "validator intentionally rejects catches after a legacy catch_all" {
  let input = Module::new()
    .with_type_sec(
      TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
    .with_code_sec(
      CodeSec::new([
        Func::new(
          Locals::empty(),
          Expr::new([
            Instruction::try_(
              BlockType::void_(),
              Expr::new([Instruction::nop()]),
              [
                @lib.LegacyCatch::all(Expr::new([Instruction::nop()])),
                @lib.LegacyCatch::all(Expr::new([Instruction::nop()])),
              ],
            ),
          ]),
        ),
      ]),
    )
  assert_true(validate_module(input) is Err(_))
}

///|
fn daybreak_f05_tagged_try(catches : Array[@lib.LegacyCatch]) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([RecType::new(SubType::comp_type(CompType::func([], [])))]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0U))]))
  .with_code_sec(
    CodeSec::new([
      Func::new(
        Locals::empty(),
        Expr::new([
          Instruction::try_(
            BlockType::void_(),
            Expr::new([Instruction::nop()]),
            catches,
          ),
        ]),
      ),
    ]),
  )
}

///|
test "F05 validator intentionally rejects a typed catch after a legacy catch_all" {
  let input = daybreak_f05_tagged_try([
    @lib.LegacyCatch::all(Expr::new([Instruction::nop()])),
    @lib.LegacyCatch::tagged(TagIdx::new(0U), Expr::new([Instruction::nop()])),
  ])
  match validate_module(input) {
    Err(_) => ()
    Ok(_) => fail("validator accepted a typed catch after catch_all")
  }
}

///|
test "F05 validator accepts a typed catch before a final legacy catch_all" {
  let input = daybreak_f05_tagged_try([
    @lib.LegacyCatch::tagged(TagIdx::new(0U), Expr::new([Instruction::nop()])),
    @lib.LegacyCatch::all(Expr::new([Instruction::nop()])),
  ])
  match validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("valid catch order rejected: \{err}")
  }
}
