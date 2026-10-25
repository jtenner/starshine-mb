///|
// Round 2 source-review reproduction of name loss, not desired behavior.
test "merge-similar-functions accepted merge deletes the name section" {
  let input = pass_test_module_from_wat(
    #|(module
    #|  (global (mut i32) (i32.const 0))
    #|  (func $left (result i32)
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    i32.const 42)
    #|  (func $right (result i32)
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    global.get 0 i32.const 1 i32.add global.set 0
    #|    i32.const 43))
  ).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(@lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("left")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("right")),
      ])),
    ),
  )
  assert_true(input.name_sec is Some(_))
  @debug.assert_eq(input.code_sec.unwrap().0.length(), 2)
  let output = merge_similar_functions_run_module_pass(input)
  // A third function proves that sharing was accepted, rather than a no-op.
  @debug.assert_eq(output.code_sec.unwrap().0.length(), 3)
  assert_true(@validate.validate_module(output) is Ok(_))
  // Confirmed defect: without_name_sec removes both original function names.
  @debug.assert_eq(output.name_sec, None)
}
