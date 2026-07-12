///|
fn optimize_instructions_closeout_manifest_selected_profiles(
  requested_profile : String,
) -> (EmitGenValidBatchArgs, EmitGenValidBatchSelection, Array[String]) {
  let args = EmitGenValidBatchArgs::new(
    18,
    0x5eedUL,
    "tmp/gen-valid-optimize-instructions-closeout",
    profile=requested_profile,
    max_attempts=72,
  )
  let selection = match emit_gen_valid_batch_selection(args) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  @debug.assert_eq(selection.manifest.length(), 18)
  let all_profile = match @validate.gen_valid_profile_by_name(requested_profile) {
    Ok(v) => v
    Err(msg) => fail(msg)
  }
  let selected_profiles : Array[String] = []
  for item in selection.manifest {
    @debug.assert_eq(item.config_label, @validate.gen_valid_profile_name(all_profile))
    @debug.assert_eq(
      item.selected_profile,
      @validate.gen_valid_profile_name(
        @validate.gen_valid_profile_leaf_for_case(
          all_profile,
          0x5eedUL,
          item.index,
        ),
      ),
    )
    assert_true(
      item.selected_profile.starts_with("pass-oi-"),
      msg="expected OI selected profile, got \{item.selected_profile}",
    )
    if !selected_profiles.contains(item.selected_profile) {
      selected_profiles.push(item.selected_profile)
    }
  }
  (args, selection, selected_profiles)
}

///|
test "emit gen-valid optimize-instructions aggregate manifest keeps pass-oi-all labels" {
  let (args, selection, selected_profiles) =
    optimize_instructions_closeout_manifest_selected_profiles("pass-oi-all")
  let _ = selection
  assert_true(selected_profiles.length() > 1)
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(manifest.contains("\"config_label\":\"pass-oi-all\""))
  assert_true(manifest.contains("\"selected_profile\":\"pass-oi-"))
}

///|
test "emit gen-valid optimize-instructions closeout alias keeps aggregate manifest labels" {
  let (args, selection, selected_profiles) =
    optimize_instructions_closeout_manifest_selected_profiles(
      "optimize-instructions-closeout",
    )
  let _ = selection
  assert_true(selected_profiles.length() > 1)
  let manifest = format_gen_valid_batch_manifest_json(args, selection)
  assert_true(manifest.contains("\"config_label\":\"pass-oi-all\""))
  assert_true(manifest.contains("\"selected_profile\":\"pass-oi-"))
}
