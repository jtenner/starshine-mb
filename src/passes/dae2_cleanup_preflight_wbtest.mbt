///|
test "dae2 capture cleanup returns the original candidate-free module" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (export "run") (local i32)
      #|     i32.const 1
      #|     local.set 0
      #|     local.get 0
      #|     drop
      #|     i32.const 2
      #|     local.set 0
      #|     local.get 0
      #|     drop))
      #|
    ),
  )
  assert_true(physical_equal(dae2_cleanup_captures(input), input))
}
