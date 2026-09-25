///|
fn tuple_rewritten_consumer_perf_fixture(
  group_count : Int,
) -> (Array[HotTupleOptimizationGroup], @bitset.BitSet) {
  let groups : Array[HotTupleOptimizationGroup] = []
  let rewrite_mask = @bitset.BitSet::new(group_count)
  for group_id in 0..<group_count {
    groups.push({
      producer: -1,
      lane_locals: [],
      defining_nodes: [],
      host_lane: if group_id % 2 == 0 {
        Some(0)
      } else {
        None
      },
      copy_source: if group_id == 0 {
        None
      } else {
        Some(group_id - 1)
      },
      copy_payload_locals: None,
      has_copy_payload_candidate: false,
      uses: 0,
      valid_uses: 0,
      neighbors: [],
      bad: false,
    })
    rewrite_mask[group_id] = true
  }
  (groups, rewrite_mask)
}

///|
fn tuple_rewritten_consumer_perf_bench(
  it : @bench.T,
  group_count : Int,
) -> Unit {
  let (groups, rewrite_mask) = tuple_rewritten_consumer_perf_fixture(
    group_count,
  )
  it.bench(fn() {
    let (consumers, host_consumers) = tuple_optimization_build_rewritten_consumer_facts(
      groups, rewrite_mask,
    )
    let mut count = 0
    for source in 0..<group_count {
      if consumers[source] {
        count += 1
      }
      if host_consumers[source] {
        count += 1
      }
    }
    it.keep(count)
  })
}

///|
test "TupleOptimization rewritten consumers honor mask and source bounds" {
  let (groups, rewrite_mask) = tuple_rewritten_consumer_perf_fixture(4)
  groups[0].copy_source = Some(0)
  groups[1].copy_source = Some(0)
  groups[2].copy_source = Some(0)
  groups[3].copy_source = Some(99)
  rewrite_mask[1] = false
  let (consumers, host_consumers) = tuple_optimization_build_rewritten_consumer_facts(
    groups, rewrite_mask,
  )
  assert_true(consumers[0])
  assert_true(host_consumers[0])
  assert_false(consumers[3])
  rewrite_mask[2] = false
  let (masked_consumers, masked_host_consumers) = tuple_optimization_build_rewritten_consumer_facts(
    groups, rewrite_mask,
  )
  assert_false(masked_consumers[0])
  assert_false(masked_host_consumers[0])
}

///|
test "bench TupleOptimization rewritten consumers groups=512" (it : @bench.T) {
  tuple_rewritten_consumer_perf_bench(it, 512)
}

///|
test "bench TupleOptimization rewritten consumers groups=1024" (it : @bench.T) {
  tuple_rewritten_consumer_perf_bench(it, 1024)
}
