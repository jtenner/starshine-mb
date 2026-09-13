///|
test "audit import name pairs retain embedded NUL identity" {
  let wat =
    #|(module
    #|  (import "a" "b\00c" (func $a))
    #|  (import "a\00b" "c" (func $b))
    #|  (func (export "run") call $a call $b))
  let input = pass_test_module_from_wat(wat).with_import_sec(
    @lib.ImportSec::new([
      @lib.Import::new(
        @lib.Name::from_string("a"),
        @lib.Name::from_string("b\u{0}c"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
      @lib.Import::new(
        @lib.Name::from_string("a\u{0}b"),
        @lib.Name::from_string("c"),
        @lib.ExternType::func(@lib.TypeIdx::new(0U)),
      ),
    ]),
  )
  let output = audit_run_module(input, "duplicate-import-elimination")
  @debug.assert_eq(output.import_sec.unwrap().0.length(), 2)
  @debug.assert_eq(audit_body(output), [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
  ])
}

///|
test "audit duplicate imports retain concrete function subtype" {
  let wat =
    #|(module
    #|  (type $parent (sub (func)))
    #|  (type $child (sub $parent (func)))
    #|  (import "env" "f" (func $a (type $parent)))
    #|  (import "env" "f" (func $b (type $child)))
    #|  (global (export "g") (ref $child) (ref.func $b)))
  let output = audit_run(wat, "duplicate-import-elimination")
  ignore(@validate.validate_module(output).unwrap())
  @debug.assert_eq(output.import_sec.unwrap().0.length(), 2)
}
