///|
test "Binaryen 132 compact import GenValid emits grouped bytes with stable logical indices" {
  let profile = match gen_valid_profile_by_name("binaryen132-compact-imports") {
    Ok(profile) => profile
    Err(err) => fail(err)
  }
  let selection = emit_gen_valid_batch_artifacts_until_profile_features(
    12,
    0x5eedUL,
    profile,
    [],
    [],
    12,
  ).unwrap()
  @debug.assert_eq(selection.artifacts.length(), 12)
  let mut same_type = false
  let mut same_module = false
  for index = 0; index < selection.artifacts.length(); index = index + 1 {
    let (_, bytes) = selection.artifacts[index]
    let decoded = decode_module(bytes).unwrap()
    let generated = gen_valid_module_result_from_seed(
        selection.manifest[index].case_seed,
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    @debug.assert_eq(decoded.import_sec, generated.import_sec)
    @debug.assert_eq(decoded.export_sec, generated.export_sec)
    @debug.assert_eq(decoded.code_sec, generated.code_sec)
    assert_true(validate_module(decoded) is Ok(_))
    let ordinary = encode_module(decoded).unwrap()
    assert_true(bytes.length() < ordinary.length())
    for offset = 0; offset + 1 < bytes.length(); offset = offset + 1 {
      if bytes[offset] == b'\x00' {
        same_type = same_type || bytes[offset + 1] == b'\x7e'
        same_module = same_module || bytes[offset + 1] == b'\x7f'
      }
    }
  }
  assert_true(same_type)
  assert_true(same_module)
}
