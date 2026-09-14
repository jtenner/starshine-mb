///|
test "fourth audit command remove-unused-module-elements live empty elem.drop 0" {
  let output = cmd_deep_audit_run(
    "(module (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") elem.drop 0))",
    "remove-unused-module-elements",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "fourth audit command remove-unused-module-elements live empty i32.const 0 i32.const 0 i32.const 0 table.init 0" {
  let output = cmd_deep_audit_run(
    "(module (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") i32.const 0 i32.const 0 i32.const 0 table.init 0))",
    "remove-unused-module-elements",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "fourth audit command remove-unused-nonfunction-module-elements live empty elem.drop 0" {
  let output = cmd_deep_audit_run(
    "(module (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") elem.drop 0))",
    "remove-unused-nonfunction-module-elements",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "fourth audit command remove-unused-nonfunction-module-elements live empty i32.const 0 i32.const 0 i32.const 0 table.init 0" {
  let output = cmd_deep_audit_run(
    "(module (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") i32.const 0 i32.const 0 i32.const 0 table.init 0))",
    "remove-unused-nonfunction-module-elements",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "fourth audit command remove-unused-module-elements retains referenced empty segment for array allocation" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $a (array funcref)) (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") (result anyref) ref.null any))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_new_elem(
            @lib.TypeIdx::new(0U),
            @lib.ElemIdx::new(0U),
          ),
        ]),
      ),
    ]),
  )
  let output = cmd_deep_audit_run_module(input, "remove-unused-module-elements")
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "fourth audit command remove-unused-nonfunction-module-elements retains referenced empty segment for array allocation" {
  let input = @passes.pass_test_module_from_wat(
    "(module (type $a (array funcref)) (table 0 funcref) (elem (i32.const 0) func) (func (export \"f\") (result anyref) ref.null any))",
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::i32_const(@lib.I32(0)),
          @lib.Instruction::array_new_elem(
            @lib.TypeIdx::new(0U),
            @lib.ElemIdx::new(0U),
          ),
        ]),
      ),
    ]),
  )
  let output = cmd_deep_audit_run_module(
    input, "remove-unused-nonfunction-module-elements",
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}
