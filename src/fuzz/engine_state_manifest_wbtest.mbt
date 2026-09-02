///|
fn engine_state_manifest_test_selection(
  profile : String,
  count : Int,
  seed : UInt64,
) -> (EmitGenValidBatchArgs, GenValidCoverageSelection) raise {
  let args = EmitGenValidBatchArgs::new(
    count,
    seed,
    ".",
    profile~,
    max_attempts=count,
  )
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(value) => value
    Err(msg) => fail(msg)
  }
  (args, selection)
}

///|
test "engine-state aggregate manifest records complete deterministic case contracts" {
  let (args, selection) = engine_state_manifest_test_selection(
    "engine-state-all", 80, 0xE651A7EUL,
  )
  @debug.assert_eq(selection.manifest.length(), 80)
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(
    manifest.contains("\"schema\":\"starshine.gen-valid.batch.v2\""),
    msg=manifest,
  )
  assert_true(manifest.contains("\"case_seed\":"), msg=manifest)
  assert_true(manifest.contains("\"wasm_hash\":\"fnv1a64-"), msg=manifest)
  assert_true(
    manifest.contains(
      "\"generator_build_identity\":\"starshine-gen-valid-engine-state-v3\"",
    ),
    msg=manifest,
  )
  assert_true(
    manifest.contains(
      "\"engine_state_schema\":\"starshine.gen-valid.engine-state.v3\"",
    ),
    msg=manifest,
  )
  assert_true(
    manifest.contains("\"fuzz_abi\":{\"module\":\"__fuzz\""),
    msg=manifest,
  )
  assert_true(manifest.contains("\"input_i32\":\"(i32)->i32\""), msg=manifest)
  assert_true(
    manifest.contains("\"observe_i64\":\"(i32,i64)->()\""),
    msg=manifest,
  )
  assert_true(manifest.contains("\"observation_map\":["), msg=manifest)
  assert_true(manifest.contains("\"function_index\":"), msg=manifest)
  assert_true(manifest.contains("\"result_index\":"), msg=manifest)
  assert_true(manifest.contains("\"wasm_type\":"), msg=manifest)
  assert_true(manifest.contains("\"encoding\":"), msg=manifest)
  assert_true(manifest.contains("\"present_in_module\":true"), msg=manifest)
  assert_true(manifest.contains("\"reachable_from_start\":true"), msg=manifest)
  assert_true(manifest.contains("\"executed_by_driver\":true"), msg=manifest)
  assert_true(
    manifest.contains("\"observable_after_execution\":true"),
    msg=manifest,
  )
  assert_true(
    manifest.contains("\"static_instruction_limit\":1024"),
    msg=manifest,
  )
  assert_true(
    manifest.contains("\"dynamic_instruction_limit\":5000"),
    msg=manifest,
  )
  assert_true(manifest.contains("\"encoded_size_limit\":131072"), msg=manifest)
  assert_true(manifest.contains("\"nan_policy\":\"strict-bits\""), msg=manifest)
  assert_true(
    manifest.contains("\"relaxed_operation_policy\":\"disabled\""),
    msg=manifest,
  )
  for
    profile in [
      "engine-state-scalar-control", "engine-state-calls", "engine-state-memory",
      "engine-state-table", "engine-state-simd", "engine-state-imports", "engine-state-initialization",
      "engine-state-trap", "engine-state-mixed", "engine-state-topology", "engine-state-effects",
      "engine-state-resources", "engine-state-boundaries", "engine-state-optimizer-shapes",
      "engine-state-equivalent-families", "engine-state-passive-segments", "engine-state-instantiation-boundaries",
      "engine-state-multi-resource", "engine-state-stack-pressure", "engine-state-memory-aliasing",
      "engine-state-indirect-traps", "engine-state-trap-placement", "engine-state-cross-instance",
      "engine-state-resource-exhaustion", "engine-state-decoder-topology", "engine-state-tail-calls",
      "engine-state-typed-function-references", "engine-state-memory64", "engine-state-exceptions",
      "engine-state-gc",
    ] {
    assert_true(
      manifest.contains("\"selected_leaf\":\"\{profile}\""),
      msg=profile,
    )
  }
}

///|
test "engine-state profiles reject generic metamorphic transforms fail closed" {
  let profile = match
    @validate.gen_valid_profile_by_name("engine-state-memory") {
    Ok(value) => value
    Err(msg) => fail(msg)
  }
  match
    emit_gen_valid_batch_artifacts_until_profile_features(
      1,
      0xE651A7EUL,
      profile,
      [],
      [],
      1,
      metamorphic_transform_ids=["add-passive-data-segment"],
    ) {
    Ok(_) => fail("engine-state transform request should be rejected")
    Err(msg) =>
      assert_true(msg.contains("engine-state profiles do not support"))
  }
}

///|
test "engine-state trap manifest records one intended frontier and committed-prefix semantics" {
  let (args, selection) = engine_state_manifest_test_selection(
    "engine-state-trap", 1, 4UL,
  )
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(
    manifest.contains("\"intended_outcome\":\"runtime-trap\""),
    msg=manifest,
  )
  assert_true(
    manifest.contains(
      "\"trap_observation_contract\":\"complete-externally-committed-prefix\"",
    ),
    msg=manifest,
  )
  assert_true(manifest.contains("\"pre_trap_marker\":1879048192"), msg=manifest)
  assert_true(manifest.contains("\"completion_marker\":null"), msg=manifest)
  assert_true(manifest.contains("\"trap_class\":"), msg=manifest)
  assert_false(manifest.contains("\"trap_class\":null"), msg=manifest)
}
