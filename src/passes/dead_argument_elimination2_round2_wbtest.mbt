///|
test "round2 dae2 preserves indirect call runtime type mismatch" {
  let input = pass_test_module_from_wat(
    "(module (type $A (func (param i32))) (type $B (func (param i64))) (table 1 funcref) (func $a (type $A) (param i32)) (elem (i32.const 0) func $a) (func (export \"run\") i64.const 7 i32.const 0 call_indirect (type $B)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  let env = @validate.Env::new().with_module(output)
  assert_false(
    env.resolve_functype(@lib.TypeIdx::new(0U)) ==
    env.resolve_functype(@lib.TypeIdx::new(1U)),
  )
}
