// Frozen pre-fusion constructor; common snapshot work uses the same current implementation.

///|
fn dae_boundary_graph_before_topology_fusion(
  mod_ : @lib.Module,
  topology? : DaeCurrentTopologyExtras? = None,
  topology_walk_visits? : Array[Int]? = None,
) -> DaeCurrentBoundaryGraph {
  let snapshot = dae_collect_module_boundary_snapshot(mod_)
  {
    mod_,
    snapshot,
    topology: match topology {
      Some(value) if dae_current_topology_extras_shape_matches(
          value,
          snapshot.total,
        ) => value
      _ =>
        dae_collect_current_topology_extras(
          mod_,
          snapshot,
          walk_visits=topology_walk_visits,
        )
    },
    function_epochs: dae_make_function_epochs(snapshot.defined, 0, 0),
    module_epoch: 0,
    call_epoch: 0,
    type_epoch: 0,
    dependency_cache: None,
  }
}

///|
fn dae_topology_bench_fixture(
  count : Int,
  width : Int,
  depth : Int,
) -> @lib.Module {
  let wat = ["(module (func $target (param i32) (result i32) local.get 0)"]
  for index in 0..<count {
    wat.push("(func (param i32) (result i32)")
    for _ in 0..<depth {
      wat.push("block (result i32)")
    }
    for _ in 0..<width {
      wat.push("local.get 0 call $target drop")
    }
    wat.push("local.get 0 return_call $target")
    for _ in 0..<depth {
      wat.push("end")
    }
    wat.push(")")
  }
  wat.push(")")
  pass_test_module_from_wat(wat.join(" "))
}

///|
fn dae_topology_fusion_bench(
  it : @bench.T,
  count : Int,
  width : Int,
  depth : Int,
  fused : Bool,
) -> Unit {
  let input = dae_topology_bench_fixture(count, width, depth)
  @validate.validate_module(input).unwrap()
  let before = dae_boundary_graph_before_topology_fusion(input)
  let after = dae_current_boundary_graph_new(input)
  if !dae_current_call_facts_equal(
      before.snapshot.call_facts,
      after.snapshot.call_facts,
    ) ||
    before.topology.direct_return_callers !=
    after.topology.direct_return_callers ||
    before.topology.direct_return_callees_by_caller !=
    after.topology.direct_return_callees_by_caller ||
    before.topology.has_outgoing_return_call !=
    after.topology.has_outgoing_return_call ||
    after.topology.direct_return_callers[0].length() != count {
    abort(
      "fused topology benchmark changed call facts or active return callers",
    )
  }
  if fused {
    it.bench(fn() { it.keep(dae_current_boundary_graph_new(input)) })
  } else {
    it.bench(fn() { it.keep(dae_boundary_graph_before_topology_fusion(input)) })
  }
}

///|
test "bench DAE topology separate funcs=1 calls=8 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 8, 0, false)
}

///|
test "bench DAE topology fused funcs=1 calls=8 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 8, 0, true)
}

///|
test "bench DAE topology separate funcs=1 calls=8 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 8, 8, false)
}

///|
test "bench DAE topology fused funcs=1 calls=8 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 8, 8, true)
}

///|
test "bench DAE topology separate funcs=1 calls=128 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 128, 0, false)
}

///|
test "bench DAE topology fused funcs=1 calls=128 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 128, 0, true)
}

///|
test "bench DAE topology separate funcs=1 calls=128 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 128, 8, false)
}

///|
test "bench DAE topology fused funcs=1 calls=128 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 1, 128, 8, true)
}

///|
test "bench DAE topology separate funcs=128 calls=8 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 8, 0, false)
}

///|
test "bench DAE topology fused funcs=128 calls=8 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 8, 0, true)
}

///|
test "bench DAE topology separate funcs=128 calls=8 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 8, 8, false)
}

///|
test "bench DAE topology fused funcs=128 calls=8 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 8, 8, true)
}

///|
test "bench DAE topology separate funcs=128 calls=128 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 128, 0, false)
}

///|
test "bench DAE topology fused funcs=128 calls=128 depth=0" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 128, 0, true)
}

///|
test "bench DAE topology separate funcs=128 calls=128 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 128, 8, false)
}

///|
test "bench DAE topology fused funcs=128 calls=128 depth=8" (it : @bench.T) {
  dae_topology_fusion_bench(it, 128, 128, 8, true)
}
