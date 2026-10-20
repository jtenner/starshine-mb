///|
fn dae_immutable_global_field_fixture(field : UInt32) -> @lib.Module raise {
  // The text parser does not support struct.set. Build that operation in IR.
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field (mut i32)) (field i32))) (global $g (ref $s) (struct.new $s (i32.const 0) (i32.const 9))) (func (export \"run\") (result i32) i32.const 0))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::i32_const(@lib.I32(7)),
          @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(field)),
        ]),
      ),
    ]),
  )
  match @validate.validate_module(input) {
    Ok(_) => input
    Err(err) => fail("field fixture validation error: \{err}")
  }
}

///|
test "DAEO immutable-global field helper preserves unsupported mutable-field reads after writes" {
  let input = dae_immutable_global_field_fixture(0U)
  let rewritten = run_hot_pipeline_dae_fold_immutable_global_struct_fields_touched(
    input,
    [true],
  )
  if rewritten != input {
    fail("mutable field read changed to its stale initializer after struct.set")
  }
}

///|
test "DAEO immutable-global field helper still folds immutable siblings after mutable writes" {
  let input = dae_immutable_global_field_fixture(1U)
  let rewritten = run_hot_pipeline_dae_fold_immutable_global_struct_fields_touched(
    input,
    [true],
  )
  match rewritten.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.GlobalGet(_),
                @lib.I32Const(@lib.I32(7)),
                @lib.StructSet(_, _),
                @lib.I32Const(@lib.I32(9)),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ =>
      fail(
        "expected immutable sibling literal after the unchanged mutable write",
      )
  }
  match @validate.validate_module(rewritten) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}
