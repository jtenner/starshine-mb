///|
fn tuple_optimization_test_analyze(
  text : String,
) -> HotTupleOptimizationAnalysis {
  let fixture = @ir.ir_test_build_hot_from_wat(text)
  let use_def = @ir.use_def_build(fixture.hot_func)
  tuple_optimization_analyze(fixture.hot_func, use_def)
}

///|
test "tuple-optimization no-op screen rejects scalar-only functions" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (result i32) i32.const 7))",
  )
  assert_false(tuple_optimization_may_have_candidates(fixture.hot_func))
  let analysis = tuple_optimization_analyze(
    fixture.hot_func,
    @ir.use_def_build(fixture.hot_func),
  )
  assert_eq(analysis.groups.length(), 0)
}

///|
test "tuple-optimization analysis detects a direct multivalue spill group" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )

  assert_eq(analysis.groups.length(), 1)
  let group = analysis.groups[0]
  assert_eq(group.lane_locals, [0, 1, 2])
  assert_eq(group.copy_source, None)
  assert_eq(group.uses, 2)
  assert_eq(group.valid_uses, 2)
  assert_eq(group.neighbors, [])
  assert_false(group.bad)
}

///|
test "tuple-optimization analysis rejects mixed bridge and non-bridge consumers" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (result i32) (local i32) block (result i32 i32) i32.const 1 i32.const 2 end local.set 0 drop local.get 0))",
  )
  assert_true(tuple_optimization_may_have_candidates(fixture.hot_func))
  let analysis = tuple_optimization_analyze(
    fixture.hot_func,
    @ir.use_def_build(fixture.hot_func),
  )
  assert_eq(analysis.groups.length(), 0)
}

///|
test "tuple-optimization analysis links pure lane-forwarding copy groups" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 local.get 3))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.lane_locals, [0, 1, 2])
  assert_eq(source.copy_source, None)
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_eq(source.neighbors, [1])
  assert_false(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.lane_locals, [3, 4, 5])
  assert_eq(copy.copy_source, Some(0))
  assert_eq(copy.uses, 2)
  assert_eq(copy.valid_uses, 2)
  assert_eq(copy.neighbors, [0])
  assert_false(copy.bad)
}

///|
test "tuple-optimization analysis propagates badness across copy-connected groups" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (result i32) (local i32 i32 i32 i32 i32 i32) block (result i32 i32 i32) i32.const 1 i32.const 2 i32.const 3 end local.set 2 local.set 1 local.set 0 block (result i32 i32 i32) local.get 0 local.get 1 local.get 2 end local.set 5 local.set 4 local.set 3 i32.const 9 local.set 4 local.get 3))",
  )

  assert_eq(analysis.groups.length(), 2)

  let source = analysis.groups[0]
  assert_eq(source.uses, 2)
  assert_eq(source.valid_uses, 2)
  assert_true(source.bad)

  let copy = analysis.groups[1]
  assert_eq(copy.uses, 3)
  assert_eq(copy.valid_uses, 2)
  assert_true(copy.bad)
}

///|
test "tuple-optimization analysis accepts multivalue spill bridges ending in local.tee" {
  let analysis = tuple_optimization_test_analyze(
    "(module (func (local i32 i32) block (result i32 i32) i32.const 1 i32.const 2 end local.set 1 local.tee 0 drop local.get 1 drop))",
  )

  assert_eq(analysis.groups.length(), 1)
  let group = analysis.groups[0]
  assert_eq(group.lane_locals, [0, 1])
  assert_eq(group.copy_source, None)
  assert_eq(group.uses, 3)
  assert_eq(group.valid_uses, 3)
  assert_eq(group.neighbors, [])
  assert_false(group.bad)
}
