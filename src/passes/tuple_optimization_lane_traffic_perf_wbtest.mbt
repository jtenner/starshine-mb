///|
fn tuple_lane_traffic_perf_fixture(
  count : Int,
) -> (@ir.HotFunc, @ir.HotUseDef, HotTupleOptimizationAnalysis) {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (import \"env\" \"pair\" (func (result i32 i32))) (func (local i32 i32 i32 i32) call 0 local.set 1 local.set 0 block (result i32 i32) local.get 0 local.get 1 end local.set 3 local.tee 2 drop",
  )
  for _ in 0..<count {
    wat.write_string(" local.get 2 local.set 0")
  }
  wat.write_string("))")
  let fixture = pass_test_module_from_wat(wat.to_string())
  let func = @ir.hot_lift_func(fixture, @lib.FuncIdx::new(1U))
  let use_def = @ir.use_def_build(func)
  let analysis = tuple_optimization_analyze(func, use_def)
  (func, use_def, analysis)
}

///|
fn tuple_lane_traffic_perf_bench(it : @bench.T, count : Int) -> Unit {
  let (func, use_def, analysis) = tuple_lane_traffic_perf_fixture(count)
  let mut matched = false
  for group in analysis.groups {
    if group.copy_source is Some(_) && group.lane_locals.contains(2) {
      let lane = group.lane_locals.find_index(fn(local_id) { local_id == 2 })
      match lane {
        Some(lane) => {
          let write = group.defining_nodes[lane]
          let sites = @ir.node_use_sites_borrowed(use_def, write)
          if sites.length() == 1 &&
            sites[0].kind is @ir.HotUseSlotKind::ChildUseSlot &&
            @ir.local_read_nodes_borrowed(use_def, 2).length() == count {
            matched = true
          }
        }
        None => ()
      }
    }
  }
  if !matched {
    abort("tuple lane-traffic fixture lacks child-only copied lane")
  }
  let copy_write_nodes = @bitset.BitSet::new(@ir.hot_node_count(func))
  it.bench(fn() {
    tuple_optimization_count_lane_traffic(
      func,
      use_def,
      analysis.query_summary,
      analysis.groups,
      analysis.local_group_ids,
      analysis.copy_read_nodes,
      copy_write_nodes,
    )
    it.keep(copy_write_nodes)
  })
}

///|
test "tuple lane traffic leaves child-only captured write unclassified" {
  let (func, use_def, analysis) = tuple_lane_traffic_perf_fixture(4)
  let copy_write_nodes = @bitset.BitSet::new(@ir.hot_node_count(func))
  tuple_optimization_count_lane_traffic(
    func,
    use_def,
    analysis.query_summary,
    analysis.groups,
    analysis.local_group_ids,
    analysis.copy_read_nodes,
    copy_write_nodes,
  )
  for read in @ir.local_read_nodes_borrowed(use_def, 2) {
    let sites = @ir.node_use_sites_borrowed(use_def, read)
    assert_eq(sites.length(), 1)
    assert_false(copy_write_nodes[sites[0].user])
  }
}

///|
test "bench tuple lane traffic child-only write count=128" (it : @bench.T) {
  tuple_lane_traffic_perf_bench(it, 128)
}

///|
test "bench tuple lane traffic child-only write count=256" (it : @bench.T) {
  tuple_lane_traffic_perf_bench(it, 256)
}
