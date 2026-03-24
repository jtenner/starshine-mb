///|
using @lib {type Expr, type Instruction}

///|
test "hot revision current reflects direct hot func mutations" {
  let func = hot_lift_body(
    Expr::new([Instruction::nop()]),
    HotLocals::new(param_count=0, locals=[]),
  )
  let root = hot_root_get(func, 0)
  let rev0 = hot_revision_current(func)

  hot_append_root(func, root)
  assert_eq(hot_revision_current(func), rev0 + 1)

  let rev1 = hot_revision_current(func)
  hot_root_set(func, 1, root)
  assert_eq(hot_revision_current(func), rev1 + 1)

  let rev2 = hot_revision_current(func)
  hot_node_set(func, root, hot_node_get(func, root))
  assert_eq(hot_revision_current(func), rev2 + 1)
}

///|
test "hot pass descriptors expose required analyses and invalidations" {
  let descriptor = HotPassDescriptor::new(
    "const-fold",
    requires=[HotAnalysis::cfg(), HotAnalysis::dominance()],
    invalidates=[HotAnalysis::liveness(), HotAnalysis::use_def()],
  )
  assert_eq(hot_pass_requires(descriptor), [
    HotAnalysis::cfg(),
    HotAnalysis::dominance(),
  ])
  assert_eq(hot_pass_invalidates(descriptor), [
    HotAnalysis::liveness(),
    HotAnalysis::use_def(),
  ])
}

///|
test "hot pass descriptor defaults to no requirements or invalidations" {
  let descriptor = HotPassDescriptor::new("verify")
  assert_eq(hot_pass_requires(descriptor), [])
  assert_eq(hot_pass_invalidates(descriptor), [])
}
