///|
fn sl_effect_scan_workspace_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
  leaf : Bool,
) -> Unit {
  let func = sl_get_count_cache_fixture(width, 3)
  let roots = @ir.hot_root_span(func)
  let workspace = SimplifyLocalsEffectScanWorkspace::new()
  let expected = roots.map(fn(root) {
    sl_effect_scan_before_workspace(
      func,
      if leaf && @ir.hot_child_count(func, root) > 0 {
        @ir.hot_child_get(func, root, 0)
      } else {
        root
      },
    )
  })
  let actual = roots.map(fn(root) {
    simplify_locals_effects_mask_for_subtree_scan(
      func,
      if leaf && @ir.hot_child_count(func, root) > 0 {
        @ir.hot_child_get(func, root, 0)
      } else {
        root
      },
      workspace=Some(workspace),
    )
  })
  if actual != expected {
    abort(
      "effect-scan benchmark changed exact masks or shared-node visit counts",
    )
  }
  let revision = @ir.hot_revision_current(func)
  it.bench(fn() {
    let mut combined = 0U
    let workspace = if reference {
      None
    } else {
      Some(SimplifyLocalsEffectScanWorkspace::new())
    }
    for root in roots {
      let target = if leaf && @ir.hot_child_count(func, root) > 0 {
        @ir.hot_child_get(func, root, 0)
      } else {
        root
      }
      combined = combined |
        (if reference {
          sl_effect_scan_before_workspace(func, target)
        } else {
          simplify_locals_effects_mask_for_subtree_scan(
            func,
            target,
            workspace~,
          )
        }).0
    }
    it.keep(combined)
  })
  if @ir.hot_revision_current(func) != revision {
    abort("effect-scan benchmark mutated the function")
  }
  @ir.hot_verify_all(func).unwrap()
}

///|
test "bench SL effect queries width=1 write reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 1, true, false)
}

///|
test "bench SL effect queries width=1 write workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 1, false, false)
}

///|
test "bench SL effect queries width=1 leaf reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 1, true, true)
}

///|
test "bench SL effect queries width=1 leaf workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 1, false, true)
}

///|
test "bench SL effect queries width=128 write reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 128, true, false)
}

///|
test "bench SL effect queries width=128 write workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 128, false, false)
}

///|
test "bench SL effect queries width=128 leaf reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 128, true, true)
}

///|
test "bench SL effect queries width=128 leaf workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 128, false, true)
}

///|
test "bench SL effect queries width=4096 write reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 4096, true, false)
}

///|
test "bench SL effect queries width=4096 write workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 4096, false, false)
}

///|
test "bench SL effect queries width=4096 leaf reference" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 4096, true, true)
}

///|
test "bench SL effect queries width=4096 leaf workspace" (it : @bench.T) {
  sl_effect_scan_workspace_bench(it, 4096, false, true)
}
