///|
test "dispatcher tail-call respects target_features ban" {
  let source =
    #|(module
    #|  (func $callee (result i32) (i32.const 7))
    #|  (func (export "run") (result i32)
    #|    (call $callee)
    #|    return))
  let input = @passes.pass_test_module_from_wat(source).with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      Bytes::from_array([
        1, 0x2d, 9, 0x74, 0x61, 0x69, 0x6c, 0x2d, 0x63, 0x61, 0x6c, 0x6c,
      ]),
    ),
  ])
  let output = optimize_module_with_pass_flags(
    input,
    ["tail-call"],
    OptimizeOptions::new(),
  ).unwrap()
  @debug.assert_eq(output.code_sec, input.code_sec)
}
