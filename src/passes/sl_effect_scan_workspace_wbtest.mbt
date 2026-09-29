///|
test "SL effect queries reuse a visited row while preserving repeated local-write effects" {
  let func = sl_get_count_cache_fixture(64, 3)
  let root = @ir.hot_root_get(func, 0)
  let baseline = simplify_locals_effects_mask_for_subtree_scan(func, root)
  assert_true((baseline.0 & @ir.EFFECT_MASK_LOCAL_STATE) != 0U)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      root,
      workspace=Some(workspace),
    ),
    baseline,
  )
  let first = workspace.marks
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      root,
      workspace=Some(workspace),
    ),
    baseline,
  )
  assert_true(physical_equal(first, workspace.marks))
  assert_eq(workspace.epoch, 2)
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL effect scan epochs do not retain stale facts after replacement or arena growth" {
  let func = sl_get_count_cache_fixture(32, 1)
  let root = @ir.hot_root_get(func, 0)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  let initial = simplify_locals_effects_mask_for_subtree_scan(
    func,
    root,
    workspace=Some(workspace),
  )
  assert_true((initial.0 & @ir.EFFECT_MASK_LOCAL_STATE) != 0U)
  @ir.hot_replace_node(
    func,
    root,
    @ir.hot_node_get(func, @ir.hot_child_get(func, root, 0)),
  )
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      root,
      workspace=Some(workspace),
    ),
    simplify_locals_effects_mask_for_subtree_scan(func, root),
  )
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      root,
      workspace=Some(workspace),
    ).0,
    0U,
  )
  let local = @ir.hot_append_body_local(func, @lib.ValType::i32())
  let read = @ir.hot_build_local_get(func, local)
  let appended = @ir.hot_build_drop(func, read)
  @ir.hot_root_append(func, appended)
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      appended,
      workspace=Some(workspace),
    ),
    simplify_locals_effects_mask_for_subtree_scan(func, appended),
  )
  assert_true(workspace.marks.length() >= @ir.hot_node_count(func))
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL effect scan epoch exhaustion clears visited marks before restarting" {
  let func = sl_get_count_cache_fixture(32, 1)
  let root = @ir.hot_root_get(func, 0)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  ignore(workspace.begin(func))
  workspace.epoch = 0x3fffffff
  workspace.marks[root] = 1
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      root,
      workspace=Some(workspace),
    ),
    simplify_locals_effects_mask_for_subtree_scan(func, root),
  )
  assert_eq(workspace.epoch, 1)
}

///|
test "SL leaf effect queries avoid arena-sized visited allocation" {
  let func = sl_get_count_cache_fixture(64, 3)
  let root = @ir.hot_root_get(func, 0)
  let value = @ir.hot_child_get(func, root, 0)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  let expected = simplify_locals_effects_mask_for_subtree_scan(func, value)
  assert_eq(expected, (0U, 1))
  assert_eq(
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      value,
      workspace=Some(workspace),
    ),
    expected,
  )
  assert_true(workspace.marks.is_empty())
  @ir.hot_verify_all(func).unwrap()
}

///|
test "SL stamped effect scans visit shared operands once without changing their effects" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let first = @ir.hot_child_get(func, root, 0)
  @ir.hot_child_set(func, root, 1, first)
  let expected = sl_effect_scan_before_workspace(func, root)
  assert_eq(expected.1, 2)
  assert_true((expected.0 & @ir.EFFECT_MASK_LOCAL_STATE) != 0U)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  for _ in 0..<3 {
    assert_eq(
      simplify_locals_effects_mask_for_subtree_scan(
        func,
        root,
        workspace=Some(workspace),
      ),
      expected,
    )
  }
  @ir.hot_verify_all(func).unwrap()
}
