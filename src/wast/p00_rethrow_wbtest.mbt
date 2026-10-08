///|
test "P00 text rethrow resolves all control labels and requires a catch target" {
  let valid = "(module (tag $t) (func (try (do (throw $t)) (catch_all (if (i32.const 1) (then (rethrow 1)))))))"
  let lowered = wast_to_binary_module(valid).unwrap()
  @validate.validate_module(lowered).unwrap()
  let invalid = "(module (tag $t) (func (try (do (throw $t)) (catch_all (if (i32.const 1) (then (rethrow 0)))))))"
  assert_true(wt_lower_error_contains(invalid, "invalid legacy rethrow label"))
}
