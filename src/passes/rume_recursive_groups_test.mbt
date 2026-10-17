///|
test "RUME removes dead recursive groups and retains sibling dependencies" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $dead (struct (field i64)))
      #|  (rec
      #|    (type $dead_a (struct (field (ref null $dead_b))))
      #|    (type $dead_b (struct (field (ref null $dead_a)))))
      #|  (type $outside (struct (field i32)))
      #|  (rec
      #|    (type $node (struct (field (ref null $tail)) (field (ref null $outside))))
      #|    (type $tail (struct (field (ref null $node)))))
      #|  (type $signature (func (param (ref null $tail)) (result i32)))
      #|  (func (export "run") (type $signature) (param (ref null $tail)) (result i32)
      #|    local.get 0 ref.is_null))
    ),
  )
  let expected = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $outside (struct (field i32)))
      #|  (rec
      #|    (type $node (struct (field (ref null $tail)) (field (ref null $outside))))
      #|    (type $tail (struct (field (ref null $node)))))
      #|  (type $signature (func (param (ref null $tail)) (result i32)))
      #|  (func (export "run") (type $signature) (param (ref null $tail)) (result i32)
      #|    local.get 0 ref.is_null))
    ),
  )
  let before = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "remove-unused-module-elements",
  ]).unwrap()
  // The signature roots only the group's final member. Its unrooted sibling
  // depends on $outside, so whole-group retention must close that dependency.
  @debug.assert_eq(output.type_sec.unwrap().0.length(), 3)
  @debug.assert_eq(output.type_sec, expected.type_sec)
  @debug.assert_eq(output.func_sec, expected.func_sec)
  @debug.assert_eq(output.code_sec, expected.code_sec)
  @debug.assert_eq(output.export_sec, input.export_sec)
  assert_true(@validate.validate_module(output) is Ok(_))
  assert_true(@binary.encode_module(output).unwrap().length() < before.length())
  @debug.assert_eq(@binary.encode_module(input).unwrap(), before)
}
