///|
fn raw_structured_held_shape_compare(
  input : @lib.Module,
  expected_caller : @lib.Func,
  label : String,
  strict_gain~ : Bool = false,
  export_artifacts~ : Bool = false,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      stack_suffix_rewrite=false,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    @validate.validate_module(reference).unwrap()
    if export_artifacts {
      println("held-shape \{label} world=\{closed_world} input \{saved}")
      println(
        "held-shape \{label} world=\{closed_world} actual \{@binary.encode_module(actual).unwrap()}",
      )
      println(
        "held-shape \{label} world=\{closed_world} reference \{@binary.encode_module(reference).unwrap()}",
      )
    }
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    assert_eq(actual.type_sec, reference.type_sec)
    assert_eq(actual.func_sec, reference.func_sec)
    assert_eq(actual.code_sec.unwrap().0[1], expected_caller)
    let actual_bytes = @binary.encode_module(actual).unwrap()
    let reference_bytes = @binary.encode_module(reference).unwrap()
    // Keep the original held stack value across the control. The exact body
    // above proves the load/read still precedes the callee's global write;
    // no synthetic store/get pair is needed to preserve that value.
    if strict_gain {
      assert_true(actual_bytes.length() < reference_bytes.length(), msg=label)
    } else {
      assert_eq(actual_bytes, reference_bytes, msg=label)
    }
    let cleaned = dae2_cleanup_captures(
      run_hot_pipeline(actual, HotPipelineOptions::new(), [
        "simplify-locals", "vacuum",
      ]).unwrap(),
    )
    let reference_cleaned = dae2_cleanup_captures(
      run_hot_pipeline(reference, HotPipelineOptions::new(), [
        "simplify-locals", "vacuum",
      ]).unwrap(),
    )
    @validate.validate_module(cleaned).unwrap()
    @validate.validate_module(reference_cleaned).unwrap()
    assert_true(
      @binary.encode_module(cleaned).unwrap().length() <=
      @binary.encode_module(reference_cleaned).unwrap().length(),
      msg=label,
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 recursive replay keeps trapping held values with fewer locals and no cleanup size loss" {
  let input = pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32 i32 i64) (result i32) local.get 0 global.set $g local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) local.get 1 i32.load block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 end local.get 3 i32.add))",
  )
  let expected = pass_test_module_from_wat(
      "(module (memory 1) (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add) (func (param i32 i32 i32) (result i32) (local i32) local.get 1 i32.load local.get 0 local.get 2 call 0 local.set 3 local.get 3 i32.add))",
    ).code_sec.unwrap().0[1]
  raw_structured_held_shape_compare(
    input,
    expected,
    "trapping",
    strict_gain=true,
  )
}

///|
test "DAE2 recursive replay preserves exact HOT mutable local snapshots and cleanup size" {
  let input = pass_test_module_from_wat(
    "(module (memory (export \"memory\") 1) (global $g (export \"g\") (mut i32) (i32.const 0)) (func $h (param i32 i32 i32 i64) (result i32) local.get 0 global.set $g local.get 0 local.get 2 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32) local.get 1 block local.get 0 local.get 1 i32.const 1 i32.add local.get 2 i64.const 9 call $h local.set 3 i32.const 7 local.set 1 end local.get 1 i32.add local.get 3 i32.add))",
  )
  let expected = pass_test_module_from_wat(
      "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.add) (func (param i32 i32 i32) (result i32) (local i32) local.get 1 local.get 0 local.get 2 call 0 local.set 3 i32.const 7 local.set 1 local.get 1 i32.add local.get 3 i32.add))",
    ).code_sec.unwrap().0[1]
  raw_structured_held_shape_compare(input, expected, "mutable")
}
