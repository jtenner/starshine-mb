///|
fn control_review_legacy_global_hazard(func : @ir.HotFunc) -> Bool {
  let region = @ir.HotRegionRef::root()
  for later in 1..<@ir.hot_region_root_count(func, region) {
    let later_id = @ir.hot_region_get(func, region, later)
    match @ir.hot_node_get(func, later_id).op {
      @ir.HotOp::GlobalSet => ()
      _ => continue
    }
    for earlier in 0..<later {
      let earlier_id = @ir.hot_region_get(func, region, earlier)
      match @ir.hot_node_get(func, earlier_id).op {
        @ir.HotOp::GlobalSet =>
          if flatten_subtree_has_source_older_rich_scalar(
              func, later_id, earlier_id,
            ) {
            return true
          }
        _ => ()
      }
    }
  }
  false
}

///|
#skip("manual control-review native release benchmark")
test "control review global write hazard scan benchmark" {
  let source = StringBuilder::new()
  source.write_string("(module (global (mut i32) (i32.const 0)) (func ")
  for value in 0..<2048 {
    source.write_string("i32.const \{value} global.set 0 ")
  }
  source.write_string("))")
  let func = pass_test_lift_first_func(source.to_string())
  for sample in 0..<9 {
    let start_old = @lib.trace_now_us()
    let old = control_review_legacy_global_hazard(func)
    let old_us = @lib.trace_elapsed_us_since(start_old)
    let start_new = @lib.trace_now_us()
    let new = FlattenCarriedScalarAcrossGlobalWriteFact::from_func(func).has_hazard
    let new_us = @lib.trace_elapsed_us_since(start_new)
    assert_eq(old, new)
    println(
      "global-write sample=\{sample} old_us=\{old_us} new_us=\{new_us} roots=2048",
    )
  }
}

///|
#skip("manual control-review native release benchmark")
test "control review sparse sequencing cache benchmark" {
  for sample in 0..<9 {
    let old_holders : Array[Int32] = []
    let old_nodes : Array[Int32] = []
    let start_old = @lib.trace_now_us()
    for node = 8191; node >= 0; node = node - 1 {
      old_holders.insert(0, 4)
      old_nodes.insert(0, node)
    }
    let old_us = @lib.trace_elapsed_us_since(start_old)
    let roots = FlattenSparseMembership::new()
    let start_new = @lib.trace_now_us()
    for node = 8191; node >= 0; node = node - 1 {
      assert_true(flatten_sequenced_root_record(roots, 4, node))
    }
    let new_us = @lib.trace_elapsed_us_since(start_new)
    assert_eq(roots.length(), old_nodes.length())
    assert_true(flatten_sequenced_root_contains(roots, 4, 8191))
    assert_false(flatten_sequenced_root_contains(roots, 0, 8191))
    println(
      "sequenced-cache sample=\{sample} old_us=\{old_us} new_us=\{new_us} entries=8192 map_capacity=\{roots.capacity()}",
    )
  }
}

///|
fn control_review_legacy_consumer_span(
  func : @ir.HotFunc,
  child : Int32,
) -> Bool {
  let arity = @ir.hot_node_result_arity(func, child)
  let mut parent = -1
  let mut first_slot = -1
  let mut count = 0
  for node in 0..<@ir.hot_node_count(func) {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    for slot in 0..<@ir.hot_child_count(func, node) {
      if @ir.hot_child_get(func, node, slot) == child {
        if parent == -1 {
          parent = node
          first_slot = slot
        }
        if parent != node || slot != first_slot + count {
          return false
        }
        count += 1
      }
    }
  }
  for slot in 0..<@ir.hot_root_count(func) {
    if @ir.hot_root_get(func, slot) == child {
      return false
    }
  }
  parent >= 0 && count == arity
}

///|
#skip("manual control-review native release benchmark")
test "control review multivalue ownership benchmark" {
  for consumer in [false, true] {
    let source = StringBuilder::new()
    source.write_string(
      if consumer {
        "(module (func $consume (param i32 i32)) (func "
      } else {
        "(module (func "
      },
    )
    for value in 0..<512 {
      source.write_string(
        "block (result i32 i32) i32.const \{value} i32.const 2 end ",
      )
      source.write_string(
        if consumer {
          "call $consume "
        } else {
          "drop drop "
        },
      )
    }
    source.write_string("))")
    let input = pass_test_module_from_wat(source.to_string())
    let func = @ir.hot_lift_func(
      input,
      @lib.FuncIdx::new(if consumer { 1U } else { 0U }),
    )
    let candidates : Array[Int32] = []
    for node in 0..<@ir.hot_node_count(func) {
      if @ir.hot_node_is_live(func, node) &&
        @ir.hot_node_result_arity(func, node) == 2 &&
        @ir.hot_node_kind_is_control(func, node) {
        candidates.push(node)
      }
    }
    for sample in 0..<9 {
      let start_old = @lib.trace_now_us()
      let old = candidates.map(fn(child) {
        control_review_legacy_consumer_span(func, child)
      })
      let old_us = @lib.trace_elapsed_us_since(start_old)
      let state = FlattenRewriteState::new(func)
      let start_new = @lib.trace_now_us()
      let new = candidates.map(fn(child) {
        flatten_multivalue_control_has_exclusive_consumer_span(
          func,
          child,
          state=Some(state),
        )
      })
      let new_us = @lib.trace_elapsed_us_since(start_new)
      assert_eq(old, new)
      assert_true(new.all(fn(value) { value == consumer }))
      println(
        "ownership sample=\{sample} consumer=\{consumer} old_us=\{old_us} new_us=\{new_us} candidates=\{candidates.length()} nodes=\{@ir.hot_node_count(func)}",
      )
    }
  }
}

///|
#skip("manual control-review native release benchmark")
test "control review loop cache across splices benchmark" {
  for has_loop in [false, true] {
    let source = StringBuilder::new()
    source.write_string("(module (func ")
    for _ in 0..<128 {
      source.write_string("block ")
    }
    source.write_string(if has_loop { "loop nop end " } else { "nop " })
    for _ in 0..<128 {
      source.write_string("end ")
    }
    source.write_string("block nop end))")
    let text = source.to_string()
    for sample in 0..<9 {
      for monotone in [false, true] {
        let func = pass_test_lift_first_func(text)
        let workspace = MergeBlocksBranchScanWorkspace::new(
          loop_changes_are_removals=monotone,
        )
        let region = @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 0))
        let sibling = @ir.hot_region_body_ref(func, @ir.hot_root_get(func, 1))
        let visits = [0]
        let start = @lib.trace_now_us()
        for _ in 0..<128 {
          assert_eq(
            merge_blocks_region_contains_loop(
              func,
              region,
              workspace=Some(workspace),
              visits=Some(visits),
            ),
            has_loop,
          )
          @ir.hot_region_replace_body(func, sibling, [@ir.hot_build_nop(func)])
        }
        let elapsed = @lib.trace_elapsed_us_since(start)
        println(
          "merge-loop-cache sample=\{sample} has_loop=\{has_loop} monotone=\{monotone} us=\{elapsed} visits=\{visits[0]} depth=128 queries=128",
        )
      }
    }
  }
}
