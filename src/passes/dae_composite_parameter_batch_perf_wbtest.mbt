///|
fn dae_composite_parameter_batch_bench(
  it : @bench.T,
  composite : Bool,
  targets : Int32,
) -> Unit raise {
  let definitions = Array::makei(targets, fn(index) {
    "(func $target\{index} (param i32) (result i32) local.get 0)"
  }).join(" ")
  let calls = Array::makei(targets, fn(index) {
    "i32.const \{index + 1} call $target\{index} drop"
  }).join(" ")
  let input = pass_test_module_from_wat(
    "(module \{definitions} (func (export \"run\") \{calls}))",
  )
  let candidates = Array::makei(targets, fn(index) { index })
  let saved = @binary.encode_module(input).unwrap()
  let batch = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    candidates,
  )
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    candidates,
    allow_composite_batch=false,
  )
  assert_eq(batch.productive_defs, candidates)
  assert_eq(
    @binary.encode_module(batch.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  it.bench(fn() {
    if composite {
      it.keep(
        dae_run_exact_literal_candidate_worklist_with_facts(
          input,
          [],
          false,
          candidates,
        ),
      )
    } else {
      it.keep(
        dae_run_exact_literal_candidate_worklist_with_facts(
          input,
          [],
          false,
          candidates,
          allow_composite_batch=false,
        ),
      )
    }
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal shared caller 8 scalar" (it : @bench.T) {
  dae_composite_parameter_batch_bench(it, false, 8)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal shared caller 8 composite" (it : @bench.T) {
  dae_composite_parameter_batch_bench(it, true, 8)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal shared caller 32 scalar" (it : @bench.T) {
  dae_composite_parameter_batch_bench(it, false, 32)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal shared caller 32 composite" (it : @bench.T) {
  dae_composite_parameter_batch_bench(it, true, 32)
}

///|
fn dae_composite_literal_suffix_bench(
  it : @bench.T,
  composite : Bool,
) -> Unit raise {
  let input = dae_partial_then_literal_suffix_fixture()
  let saved = @binary.encode_module(input).unwrap()
  let scalar = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    [0, 1, 2],
    allow_composite_batch=false,
  )
  let batch = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    [],
    false,
    [0, 1, 2],
  )
  assert_eq(batch.productive_defs, [0, 1, 2])
  assert_eq(
    @binary.encode_module(batch.mod_out).unwrap(),
    @binary.encode_module(scalar.mod_out).unwrap(),
  )
  it.bench(fn() {
    it.keep(
      dae_run_exact_literal_candidate_worklist_with_facts(
        input,
        [],
        false,
        [0, 1, 2],
        allow_composite_batch=composite,
      ),
    )
  })
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal partial then suffix scalar" (it : @bench.T) {
  dae_composite_literal_suffix_bench(it, false)
}

///|
#skip("paired native controls; dedicated performance lane")
test "bench dae literal partial then suffix composite" (it : @bench.T) {
  dae_composite_literal_suffix_bench(it, true)
}
