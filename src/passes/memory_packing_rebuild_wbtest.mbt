///|
test "MemoryPacking rebuilds only data-op function bodies" {
  let source = StringBuilder::new()
  source.write_string("(module (memory 1) (data \"dead\") ")
  source.write_string("(func (data.drop 0)) ")
  for _ in 0..<128 {
    source.write_string("(func (result i32) i32.const 7) ")
  }
  source.write_string(")")
  let input = pass_test_module_from_wat(source.to_string())
  let plans = [MpSegmentPlan::new(0, [], false, false, false, 4)]
  let rebuilt = [0]
  ignore(
    mp_rewrite_code_sec_full(
      input,
      plans,
      None,
      MpMemoryAddressType::I32Address,
      mp_module_segment_op_preflight(input).func_has_data_ops,
      rebuilt_count=Some(rebuilt),
    ),
  )
  assert_eq(rebuilt[0], 1)
}
