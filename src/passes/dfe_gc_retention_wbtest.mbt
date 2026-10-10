///|
test "GC type compaction reuses unmoved typed body and subtype storage" {
  // Independently assembled retained-prefix fixture; WAT is kept with evidence.
  let mod_ = @binary.decode_module(b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x11\x03\x5f\x01\x7f\x01\x60\x01\x63\x00\x01\x7f\x60\x01\x63\x00\x01\x7f\x03\x02\x01\x01\x07\x08\x01\x04\x72\x65\x61\x64\x00\x00\x0a\x10\x01\x0e\x01\x01\x63\x00\x20\x00\xfb\x16\x00\xfb\x02\x00\x00\x0b\x00\x17\x04\x6e\x61\x6d\x65\x04\x10\x03\x00\x01\x61\x01\x03\x73\x69\x67\x02\x05\x61\x6c\x69\x61\x73").unwrap()
  let before_bytes = @binary.encode_module(mod_).unwrap()
  assert_true(@validate.validate_module(mod_) is Ok(_))
  let before_func = mod_.code_sec.unwrap().0[0]
  let before_type = mod_.type_sec.unwrap().0[1]
  let after = dfe_canonicalize_duplicate_simple_type_indices(mod_)
  assert_true(@validate.validate_module(after) is Ok(_))
  assert_eq(after.type_sec.unwrap().0.length(), 2)
  assert_true(physical_equal(after.code_sec.unwrap().0[0], before_func))
  assert_true(physical_equal(after.type_sec.unwrap().0[1], before_type))
  assert_eq(@binary.encode_module(mod_).unwrap(), before_bytes)
  assert_true(@binary.encode_module(after).unwrap().length() < before_bytes.length())
}
