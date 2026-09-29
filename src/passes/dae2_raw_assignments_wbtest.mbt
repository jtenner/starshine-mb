///|
test "DAE2 raw flat assignments distinguish entry values from replacement and tee values" {
  for
    body in [
      "i32.const 11 local.set 0 local.get 0 global.set $g", "local.get 1 i32.const 7 i32.add local.tee 0 global.set $g local.get 0 drop",
      "local.get 0 local.get 1 local.set 0 global.set $g", "local.get 1 local.set 3 i32.const 11 local.set 1 local.get 3 global.set $g",
    ] {
    let wat = "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32 i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 call $h))"
    let input = pass_test_module_from_wat(wat)
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(lifts[0], 0)
  }
}
