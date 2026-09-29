///|
fn dae2_branchless_fixture_sources() -> Array[String] {
  [
    "(module (func $h (param i32 i32 i32) (result i32) block (result i32) local.get 1 end) (func (export \"run\") (param i32) (result i32) block (result i32) i32.const 9 local.get 0 i32.const 8 call $h end))",
    "(module (func $h (param i32 i32 i32) (result i32) block (result i32) block (result i32) local.get 1 i32.const 7 i32.add end end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    "(module (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32 i32) block local.get 0 local.get 2 i32.add drop block local.get 1 global.set $g end end) (func (export \"run\") (param i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    "(module (func $h (param i32 i32 i32) (result i32) local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    "(module (memory 1) (func $h (param i32 i32 i32) (result i32) (local i32) block (result i32) local.get 1 i32.load local.tee 3 end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    "(module (import \"m\" \"value\" (func $v (result i32))) (func $h (param i32 i32 i32) (result i32) block (result i32) call $v local.get 1 i32.add end) (func (export \"run\") (param i32) i32.const 9 local.get 0 i32.const 8 call $h drop))",
    "(module (func $h (param i32 i32 i32) (result i32) block (result i32) i32.const 9 local.get 1 i32.const 8 call $h end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    "(module (memory 1) (func $h (param i32 i32 i32) block local.get 1 i32.load drop end) (func (export \"run\") (param i32) i32.const 9 local.get 0 i32.const 8 call $h))",
  ]
}

///|
test "DAE2 directly analyzes and rewrites branchless scalar blocks with exact HOT output" {
  for source in dae2_branchless_fixture_sources() {
    for closed_world in [false, true] {
      let input = pass_test_module_from_wat(source)
      @validate.validate_module(input).unwrap()
      let saved = @binary.encode_module(input).unwrap()
      let analysis = [0]
      let rewrite = [0]
      let output = dae2_run_module_pass(
        input,
        closed_world,
        analysis_lifts=Some(analysis),
        rewrite_lifts=Some(rewrite),
      ).unwrap()
      let reference = dae2_run_module_pass(
        input,
        closed_world,
        raw_analysis=false,
        raw_rewrite=false,
      ).unwrap()
      @validate.validate_module(output).unwrap()
      assert_eq(
        @binary.encode_module(output).unwrap(),
        @binary.encode_module(reference).unwrap(),
      )
      assert_true(
        output.type_sec != input.type_sec || output.func_sec != input.func_sec,
      )
      assert_eq(analysis[0], 0)
      assert_eq(rewrite[0], 0)
      assert_eq(@binary.encode_module(input).unwrap(), saved)
    }
  }
}

///|
test "DAE2 branchless admission retains HOT for intentionally unsupported indexed multivalue branched and early-return control" {
  for
    source in [
      "(module (type $s (func (param i32) (result i32))) (func $h (param i32 i32 i32) (result i32) local.get 1 block (type $s) i32.const 7 i32.add end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      "(module (func $h (param i32 i32 i32) (result i32) block (result i32 i32) local.get 1 local.get 1 end i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      "(module (func $h (param i32 i32 i32) (result i32) block (result i32) local.get 1 br 0 end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
      "(module (func $h (param i32 i32 i32) (result i32) block (result i32) local.get 1 return end) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    let reference = dae2_run_module_pass(
      input,
      false,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_true(lifts[0] > 0)
  }
}
