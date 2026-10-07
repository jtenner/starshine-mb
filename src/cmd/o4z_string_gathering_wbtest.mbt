///|
test "dispatcher O4z queue gathers lowered string constants" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"get\") (result stringref) (string.const \"shared\")))",
  )
  assert_true(input.stringrefs_sec is None)
  let report = cmd_optimizer_pass_queue_report_json(
    input,
    OptimizeOptions::new(optimize_level=4, shrink_level=4),
    ["optimize"],
  ).unwrap()
  assert_true(report.contains("\"name\":\"string-gathering\""))
}
