///|
fn inl_padding_paired_bench(
  it : @bench.T,
  case_ : String,
  reference : Bool,
) -> Unit {
  let input = if case_ == "multiple" {
    inl_padding_regression_fixture()
  } else {
    inl_padding_shared_signature_fixture(128, 2048)
  }
  let predicted : @hashmap.HashMap[String, Int32] = @hashmap.new()
  match case_ {
    "empty" => ()
    "zero" => predicted.set("p:r:", 0)
    "satisfied" => predicted.set("p:r:", 2048)
    "missing" => predicted.set("p:r:", 2050)
    "ineligible" =>
      predicted.set(inl_func_type_signature_key([], [@lib.ValType::i64()]), 2)
    "multiple" => {
      predicted.set("p:r:", 4)
      predicted.set(
        inl_func_type_signature_key([@lib.ValType::i32()], [@lib.ValType::i32()]),
        3,
      )
      predicted.set(inl_func_type_signature_key([], [@lib.ValType::i64()]), 1)
      predicted.set(inl_func_type_signature_key([], [@lib.ValType::f64()]), 5)
    }
    _ => abort("unknown padding benchmark case")
  }
  let before = @binary.encode_module(input).unwrap()
  let expected = inl_padding_frozen_reference(input, predicted)
  let actual = inl_pad_unreachable_to_predicted_counts(input, predicted)
  if @binary.encode_module(actual).unwrap() !=
    @binary.encode_module(expected).unwrap() ||
    @binary.encode_module(input).unwrap() != before {
    abort("padding benchmark changed output or source ownership")
  }
  ignore(@validate.validate_module(input).unwrap())
  ignore(@validate.validate_module(actual).unwrap())
  // A count of one keeps each calibrated sample visible without winsorization.
  for sample in 0..<7 {
    it.bench(
      fn() {
        it.keep(
          if reference {
            inl_padding_frozen_reference(input, predicted)
          } else {
            inl_pad_unreachable_to_predicted_counts(input, predicted)
          },
        )
      },
      name="raw-\{sample}",
      count=1,
    )
  }
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding empty reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "empty", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding empty candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "empty", false)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding zero reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "zero", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding zero candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "zero", false)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding satisfied reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "satisfied", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding satisfied candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "satisfied", false)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding missing reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "missing", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding missing candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "missing", false)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding ineligible reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "ineligible", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding ineligible candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "ineligible", false)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding multiple signatures reference" (it : @bench.T) {
  inl_padding_paired_bench(it, "multiple", true)
}

///|
#skip("paired native padding benchmark; run in the dedicated performance lane")
test "bench padding multiple signatures candidate" (it : @bench.T) {
  inl_padding_paired_bench(it, "multiple", false)
}
