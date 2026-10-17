///|
test "DAE callsite row copies retain independent flags paths and dropped records" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (import "host" "mark" (func $mark (param i32) (result i32)))
      #|   (func (param i32) (result i32)
      #|     local.get 0 call $mark drop local.get 0 call $mark)
      #|   (func (param i32) (result i32) local.get 0 return_call $mark)
      #|   (func unreachable i32.const 1 call $mark drop))
    ),
  )
  let snapshot = dae_collect_module_boundary_snapshot(input)
  let info = snapshot.function_infos[0]
  assert_eq(info.calls.length(), 4)
  assert_eq(info.dropped_calls.length(), 1)
  assert_eq(snapshot.call_facts.direct_calls[0], 3)
  assert_eq(snapshot.call_facts.dropped_calls[0], 1)
  let copied = info.calls.copy()
  let dropped = info.dropped_calls.copy()
  copied[0] = {
    ..copied[0],
    caller_def: 9,
    path: copied[0].path.append(0),
    active: false,
    dropped: false,
    tail: true,
  }
  dropped[0] = { ..dropped[0], callee_abs: 99, }
  assert_eq(info.calls[0].caller_def, 0)
  assert_eq(info.calls[0].callee_abs, 0)
  assert_true(info.calls[0].active)
  assert_true(info.calls[0].dropped)
  assert_false(info.calls[0].tail)
  assert_eq(info.calls[0].path.to_array(), [1])
  assert_eq(info.dropped_calls[0].callee_abs, 0)
  assert_eq(info.dropped_calls[0].path.to_array(), [1])
  assert_eq(copied[0].path.to_array(), [1, 0])
  assert_true(
    physical_equal(copied[0].path.workspace, info.calls[0].path.workspace),
  )
  assert_false(info.calls[1].dropped)
  assert_eq(info.calls[1].path.to_array(), [4])
  assert_eq(info.calls[2].caller_def, 1)
  assert_true(info.calls[2].tail)
  assert_true(info.calls[2].active)
  assert_eq(info.calls[3].caller_def, 2)
  assert_false(info.calls[3].active)
  assert_false(info.calls[3].dropped)
}

///|
test "DAE rebased callsite rows retain caller order and input ownership" {
  let source = pass_test_module_from_wat(
    "(module (import \"host\" \"mark\" (func $mark (result i32))) (func call $mark drop) (func call $mark drop))",
  )
  let changed = pass_test_module_from_wat(
    "(module (import \"host\" \"mark\" (func $mark (result i32))) (func (local i32) call $mark local.set 0 call $mark drop) (func call $mark drop))",
  )
  let before = dae_collect_module_boundary_snapshot(source).function_infos[0].calls
  let refreshed = dae_collect_module_boundary_snapshot(changed).function_infos[0].calls
  let merged = dae_merge_rebased_stable_calls(before, refreshed, [true, false])
  assert_eq(merged.length(), 3)
  assert_eq(merged[0].caller_def, 0)
  assert_false(merged[0].dropped)
  assert_eq(merged[0].path.to_array(), [0])
  assert_eq(merged[1].caller_def, 0)
  assert_true(merged[1].dropped)
  assert_eq(merged[1].path.to_array(), [2])
  assert_eq(merged[2].caller_def, 1)
  assert_true(merged[2].dropped)
  merged[0] = { ..merged[0], active: false, }
  assert_true(refreshed[0].active)
  assert_eq(before.length(), 2)
  assert_true(before[0].dropped)
  assert_eq(before[0].path.to_array(), [0])
}
