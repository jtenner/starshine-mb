///|
fn dae_s12_thin_forward_input() -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string(
    "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i32) (result i32) local.get 0) (func $f0 (param i32) (result i32) local.get 0 call $a drop local.get 0 call $b) ",
  )
  for i in 1..<6 {
    wat.write_string("(func $f")
    wat.write_string(i.to_string())
    wat.write_string(" (param i32) (result i32) local.get 0 call $f")
    wat.write_string((i - 1).to_string())
    wat.write_string(") ")
  }
  wat.write_string("(func (export \"run\") (result i32) i32.const 7 call $f5))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.thin.keep"), b"unchanged"),
  ])
}

///|
test "DAE ordered thin forwarding keeps real rewrites without duplicate-work admission" {
  let input = dae_s12_thin_forward_input()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let stats = [0, 0, 0, 0]
  let actual = dae_collect_exact_literal_candidate_defs_with_facts(
    input,
    graph.snapshot.call_facts,
    -1,
    syntax_stats=Some(stats),
  )
  let expected = dae_s10_frozen_discovery_reference(
    input,
    graph.snapshot.call_facts,
    -1,
  )
  assert_eq(actual, [0, 1, 2, 3, 4, 5, 6, 7])
  dae_s10_assert_discovery_output(input, actual, expected, saved)
  // Current admission revisits ancestors 7+7+6+5+4+3+2+1 times and trips
  // the32-visit uncertainty gate. Ordered target deferral needs8 visits.
  // The assertion follows productive output/effects/validity/ownership.
  assert_eq(stats, [0, 0, 0, 0])
}
