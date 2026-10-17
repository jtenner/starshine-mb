///|
test "full O4z presets merge private equal helpers across host boundaries" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "host" "tick" (func $tick (param i32) (result i32)))
      #|  (func $first (param i32) (result i32) local.get 0 call $tick local.get 0 i32.mul local.get 0 i32.add)
      #|  (func $second (param i32) (result i32) local.get 0 call $tick local.get 0 i32.mul local.get 0 i32.add)
      #|  (func (export "run") (param i32) (result i32)
      #|    local.get 0 call $first local.get 0 call $second i32.add))
    ),
  )
  let options = HotPipelineOptions::new(
    optimize_level=4,
    shrink_level=4,
    inlining_always_inline_max_size=0,
    inlining_one_caller_inline_max_size=0,
    inlining_flexible_inline_max_size=0,
  )
  let input_bytes = @binary.encode_module(input).unwrap()
  for preset in ["optimize", "shrink"] {
    let output = run_hot_pipeline(input, options, [preset]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let funcs = match output.code_sec {
      Some(@lib.CodeSec(funcs)) => funcs
      None => fail("expected private helper and exported caller")
    }
    @debug.assert_eq(funcs.length(), 2)
    let output_bytes = @binary.encode_module(output).unwrap()
    assert_true(output_bytes.length() < input_bytes.length())
  }
}

///|
test "full O4z presets keep equal exported table global and body-reference identities" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $export_first (export "first") (result i32) i32.const 7)
      #|  (func $export_second (export "second") (result i32) i32.const 7)
      #|  (func $table_first (result i32) i32.const 7)
      #|  (func $table_second (result i32) i32.const 7)
      #|  (func $global_first (result i32) i32.const 7)
      #|  (func $global_second (result i32) i32.const 7)
      #|  (func $body_first (result i32) i32.const 7)
      #|  (func $body_second (result i32) i32.const 7)
      #|  (table (export "refs") 2 funcref)
      #|  (elem (i32.const 0) func $table_first $table_second)
      #|  (elem declare func $global_first $global_second $body_first $body_second)
      #|  (global (export "first_ref") funcref (ref.func $global_first))
      #|  (global (export "second_ref") funcref (ref.func $global_second))
      #|  (func (export "body_first") (result funcref) ref.func $body_first)
      #|  (func (export "body_second") (result funcref) ref.func $body_second))
    ),
  )
  let options = HotPipelineOptions::new(optimize_level=4, shrink_level=4)
  for preset in ["optimize", "shrink"] {
    let output = run_hot_pipeline(input, options, [preset]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let funcs = match output.code_sec {
      Some(@lib.CodeSec(funcs)) => funcs
      None => fail("expected visible function definitions")
    }
    @debug.assert_eq(funcs.length(), 10)
  }
}
