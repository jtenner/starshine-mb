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

///|
test "round2 dae2 preserves equivalent indirect call types with unequal liveness" {
  let input = pass_test_module_from_wat(
    "(module (type $A (func (param i32))) (type $B (func (param i32))) (global $side (export \"side\") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) local.get 0 global.set $side) (elem (i32.const 0) func $a) (func (export \"run\") i32.const 7 i32.const 0 call_indirect (type $B)))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let env = @validate.Env::new().with_module(output)
  assert_true(
    env.resolve_functype(@lib.TypeIdx::new(0U)) ==
    env.resolve_functype(@lib.TypeIdx::new(1U)),
  )
}

///|
test "round2 dae2 preserves recursive group identity collapse" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $A (func (param i32))) (type $AX (struct (field (ref null $A))))) (rec (type $B (func (param i64))) (type $BX (struct (field (ref null $B))))) (global $side (export \"side\") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) ) (elem (i32.const 0) func $a) (func (export \"main\") i64.const 7 i32.const 0 call_indirect (type $B)))",
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let env = @validate.Env::new().with_module(output)
  assert_false(
    env.resolve_functype(@lib.TypeIdx::new(0U)) ==
    env.resolve_functype(@lib.TypeIdx::new(2U)),
  )
}

///|
test "round2 dae2 preserves recursive group identity split" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $A (func (param i32))) (type $AX (struct (field (ref null $A))))) (rec (type $B (func (param i32))) (type $BX (struct (field (ref null $B))))) (global $side (export \"side\") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) local.get 0 global.set $side) (elem (i32.const 0) func $a) (func (export \"main\") i32.const 7 i32.const 0 call_indirect (type $B)))",
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(closed_world=true),
    ["dae2"],
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let env = @validate.Env::new().with_module(output)
  assert_true(
    env.resolve_functype(@lib.TypeIdx::new(0U)) ==
    env.resolve_functype(@lib.TypeIdx::new(2U)),
  )
}
