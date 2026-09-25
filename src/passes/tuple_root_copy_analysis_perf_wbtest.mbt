///|
fn tuple_root_copy_analysis_perf_fixture(count : Int) -> String {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0",
  )
  for _ in 0..<count {
    wat.write_string(" block (result i32) i32.const 7 end drop")
  }
  wat.write_string(" local.get 0))")
  wat.to_string()
}

///|
fn tuple_root_copy_analysis_perf_bench(it : @bench.T, count : Int) -> Unit {
  let func = @ir.ir_test_build_hot_from_wat(
      tuple_root_copy_analysis_perf_fixture(count),
    ).hot_func
  let use_def = @ir.use_def_build(func)
  let analysis = tuple_optimization_analyze(func, use_def)
  if analysis.groups.is_empty() {
    abort("tuple root-copy benchmark lost its multivalue group")
  }
  let candidates : Array[Int] = []
  for node_id in 0..<@ir.hot_node_count(func) {
    if @ir.hot_node_get(func, node_id).op is @ir.HotOp::Block &&
      @ir.hot_node_result_arity(func, node_id) == 1 {
      let sites = @ir.node_use_sites_borrowed(use_def, node_id)
      if sites.length() == 1 &&
        sites[0].kind is @ir.HotUseSlotKind::ChildUseSlot {
        candidates.push(node_id)
      }
    }
  }
  if candidates.length() != count {
    abort("tuple root-copy benchmark did not lift child-only blocks")
  }
  let local_group_ids = tuple_optimization_build_local_group_ids(
    func,
    analysis.groups,
  )
  let marks = Array::make(@ir.hot_local_count(func), 0)
  match
    tuple_optimization_collect_result_block_copy_group(
      func,
      use_def,
      analysis.query_summary,
      analysis.groups,
      local_group_ids,
      candidates[0],
      marks,
      1,
    ) {
    None => ()
    Some(_) => abort("child-only dropped scalar block became a copy group")
  }
  it.bench(fn() {
    for carrier_id in candidates {
      it.keep(
        tuple_optimization_collect_result_block_copy_group(
          func,
          use_def,
          analysis.query_summary,
          analysis.groups,
          local_group_ids,
          carrier_id,
          marks,
          1,
        ),
      )
    }
  })
}

///|
test "TupleOptimization child-only scalar blocks preserve valid output" {
  let optimized = match
    pass_test_run_pipeline(tuple_root_copy_analysis_perf_fixture(8), [
      "tuple-optimization",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected tuple child-only scalar-block success: \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple child-only scalar-block validation: \{err}")
  }
}

///|
test "bench TupleOptimization child-only result blocks count=64" (it : @bench.T) {
  tuple_root_copy_analysis_perf_bench(it, 64)
}

///|
test "bench TupleOptimization child-only result blocks count=128" (
  it : @bench.T,
) {
  tuple_root_copy_analysis_perf_bench(it, 128)
}
