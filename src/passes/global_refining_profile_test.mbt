///|
test "global-refining generated profile refines private globals and preserves exports" {
  for
    name in [
      "global-refining-private-writes", "global-refining-export-boundaries", "global-refining-import-aliases",
      "global-refining-subtype-joins",
    ] {
    let profile = match @validate.gen_valid_profile_by_name(name) {
      Ok(profile) => profile
      Err(error) => fail(error)
    }
    let input = @validate.gen_valid_module_result_from_seed(
        17UL,
        @validate.GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "global-refining",
    ]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let old_globals = input.global_sec.unwrap().0
    let new_globals = output.global_sec.unwrap().0
    if name == "global-refining-export-boundaries" {
      @debug.assert_eq(new_globals[0].0, old_globals[0].0)
      assert_true(new_globals[1].0 != old_globals[1].0)
    } else {
      let target = if name == "global-refining-import-aliases" { 2 } else { 0 }
      assert_true(new_globals[target].0 != old_globals[target].0)
    }
  }
}
