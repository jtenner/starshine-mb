// A module with many tiny functions isolates per-function raw preflight work.
// Validation and expected-output checks happen outside timed pass runs.

///|
fn ssa_type_table_bench(it : @bench.T, function_count : Int) -> Unit {
  let fixture = opportunity_imports(function_count, 0)
  let expected = opportunity_run(fixture, "ssa-nomerge", true)
  let original_code = fixture.code_sec
  it.bench(fn() { it.keep(opportunity_run(fixture, "ssa-nomerge", false)) })
  if opportunity_run(fixture, "ssa-nomerge", false) != expected ||
    fixture.code_sec != original_code {
    abort("SSA type-table fixture changed across runs")
  }
}

///|
test "bench SSA type table functions=64" (it : @bench.T) {
  ssa_type_table_bench(it, 64)
}

///|
test "bench SSA type table functions=256" (it : @bench.T) {
  ssa_type_table_bench(it, 256)
}
