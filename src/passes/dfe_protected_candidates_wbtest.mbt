///|
test "DFE excludes protected identities before normalizing duplicate candidates" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $a (result i32) i32.const 42)
      #|  (func $b (result i32) i32.const 42)
      #|  (func (export "first") (result i32) i32.const 42)
      #|  (func (export "second") (result i32) i32.const 42)
      #|  (func $ref_a (result i32) i32.const 42)
      #|  (func $ref_b (result i32) i32.const 42)
      #|  (table 2 funcref)
      #|  (elem (i32.const 0) func $ref_a $ref_b))
    ),
  )
  let visits = [0]
  let output = dfe_eliminate_duplicate_functions(
    input,
    normalization_visits=Some(visits),
  )
  @validate.validate_module(output.mod_).unwrap()
  assert_true(output.changed)
  assert_eq(output.mod_.code_sec.unwrap().0.length(), 5)
  // The two private bodies are candidates. The four protected bodies must
  // never reach normalization or collision-pair enumeration.
  assert_eq(visits[0], 2)
}
