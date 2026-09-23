///|
test "proposal fixtures satisfy machine-readable feature floors" {
  let cases = [
    (
      "rume-continuations-descriptors",
      0x52554D45UL,
      ["descriptors", "continuations"],
    ),
    ("binaryen132-waitqueue", 0UL, ["waitqueues"]),
    ("binaryen132-array-memory", 0UL, ["array_memory"]),
    // Seed 1 selects struct atomics, ensuring the existing atomics floor covers
    // aggregate atomics as well as linear-memory opcodes.
    ("binaryen132-atomic-orders", 1UL, ["atomics"]),
  ]
  for case in cases {
    let profile = match gen_valid_profile_by_name(case.0) {
      Ok(value) => value
      Err(message) => fail(message)
    }
    let generated = match
      gen_valid_module_result_from_seed(
        case.1,
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    let stats = GenValidFeatureStats::empty(generated.facts.mode).record(
      generated.facts,
    )
    for label in case.2 {
      let floor = match validate_valid_feature_floor_by_label(label, 1) {
        Ok(value) => value
        Err(message) => fail(message)
      }
      @debug.assert_eq(validate_valid_feature_actual_count(stats, floor.key), 1)
      assert_true(
        validate_valid_feature_ledger(stats, [floor]).any(fn(entry) {
          entry.label == label &&
          entry.actual_count == 1 &&
          entry.required_min == 1
        }),
      )
    }
  }
}

///|
test "empty modules do not satisfy proposal feature floors" {
  let facts = gen_valid_feature_facts(Module::new(), GenValidMode::Natural)
  let stats = GenValidFeatureStats::empty(facts.mode).record(facts)
  for
    label in [
      "descriptors", "continuations", "waitqueues", "atomics", "array_memory",
    ] {
    match validate_valid_feature_actual_count_by_label(stats, label) {
      Ok(actual) => @debug.assert_eq(actual, 0)
      Err(message) => fail(message)
    }
  }
}

///|
test "proposal heap types satisfy continuation and waitqueue floors" {
  let mod_ = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(
          CompType::func(
            [
              ValType::ref_null(HeapType::abs(AbsHeapType::cont())),
              ValType::ref_null(HeapType::shared_abs(AbsHeapType::waitqueue())),
            ],
            [],
          ),
        ),
      ),
    ]),
  )
  let facts = gen_valid_feature_facts(mod_, GenValidMode::Natural)
  let stats = GenValidFeatureStats::empty(facts.mode).record(facts)
  for label in ["continuations", "waitqueues"] {
    match validate_valid_feature_actual_count_by_label(stats, label) {
      Ok(actual) => @debug.assert_eq(actual, 1)
      Err(message) => fail(message)
    }
  }
}

///|
test "aggregate atomics do not satisfy shared linear memory atomic floor" {
  let profile = gen_valid_profile_by_name("binaryen132-atomic-orders").unwrap()
  let generated = gen_valid_module_result_from_seed(
    1UL,
    GenValidConfig::for_profile(profile),
  ).unwrap()
  let shared = true
  let mod_ = generated.wasm_module.with_mem_sec(
    MemSec::new([MemType::new(Limits::i32(1U, Some(1U)), shared~)]),
  )
  let facts = gen_valid_feature_facts(mod_, generated.facts.mode)
  let stats = GenValidFeatureStats::empty(facts.mode).record(facts)
  @debug.assert_eq(
    validate_valid_feature_actual_count_by_label(stats, "atomics").unwrap(),
    1,
  )
  @debug.assert_eq(
    validate_valid_feature_actual_count_by_label(stats, "shared_memory_atomics").unwrap(),
    0,
  )
}
