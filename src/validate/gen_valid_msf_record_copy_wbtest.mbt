///|
test "MSF record-copy GenValid registers an observable triggering profile" {
  let profile = gen_valid_profile_by_name("merge-similar-functions-record-copy").unwrap()
  assert_eq(
    gen_valid_profile_name(profile),
    "merge-similar-functions-record-copy",
  )
  for seed in 0..<24 {
    let generated = gen_valid_module_result_from_seed(
      seed.to_uint64(),
      GenValidConfig::for_profile(profile),
    ).unwrap()
    validate_module(generated.wasm_module).unwrap()
    let bytes = @binary.encode_module(generated.wasm_module).unwrap()
    let decoded = @binary.decode_module(bytes).unwrap()
    validate_module(decoded).unwrap()
    let @lib.TypeSec(types) = generated.wasm_module.type_sec.unwrap()
    let fields = match types[0] {
      @lib.SingleRecType(subtype) =>
        match subtype.get_comptype() {
          @lib.StructCompType(fields) => fields
          _ => abort("missing record")
        }
      _ => abort("missing singleton record")
    }
    assert_eq(fields.length(), 12 + seed % 21)
    let @lib.Func(_, @lib.Expr(body)) = generated.wasm_module.code_sec.unwrap().0[1]
    let mut cursor = body
    let mut copies = 0
    for _ in 0..<32 {
      match cursor.last() {
        Some(@lib.If(_, arm, Some(rest))) => {
          assert_true(arm.last() is Some(@lib.StructNew(@lib.TypeIdx(0U))))
          assert_eq(arm.length(), fields.length() * 2)
          copies += 1
          cursor = rest
        }
        _ => break
      }
    }
    assert_eq(copies, 8 + seed % 5)
    assert_eq(
      gen_valid_msf_profile_case_label(profile, seed.to_uint64()),
      Some("msf:record-copy:fields-\{fields.length()}:arms-\{copies}"),
    )
    assert_eq(generated.wasm_module.import_sec.unwrap().0.length(), 1)
    assert_true(generated.wasm_module.export_sec.unwrap().0.length() >= 5)
  }
}
