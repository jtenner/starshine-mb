///|
test "tail-call respects target_features ban" {
  let source =
    #|(module
    #|  (func $callee (result i32) (i32.const 7))
    #|  (func (export "run") (result i32)
    #|    (call $callee)
    #|    return))
  let input = pass_test_module_from_wat(source)
  let disabled = input.with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::new("target_features"),
      Bytes::from_array([
        1, 0x2d, 9, 0x74, 0x61, 0x69, 0x6c, 0x2d, 0x63, 0x61, 0x6c, 0x6c,
      ]),
    ),
  ])
  let output = run_hot_pipeline(disabled, HotPipelineOptions::new(), [
    "tail-call",
  ]).unwrap()
  @debug.assert_eq(output.code_sec, disabled.code_sec)
  let enabled = run_hot_pipeline(input, HotPipelineOptions::new(), ["tail-call"]).unwrap()
  assert_eq(
    binaryen133_shared_opcode_count(
      enabled,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}
