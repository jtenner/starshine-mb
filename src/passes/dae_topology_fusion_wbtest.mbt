///|
fn dae_topology_fusion_fixture() -> @lib.Module raise {
  let source =
    #|(module
    #| (type $t (func (param i32) (result i32)))
    #| (import "m" "external" (func (type $t)))
    #| (table 1 funcref)
    #| (func $target (type $t) local.get 0)
    #| (elem (i32.const 0) $target)
    #| (func (type $t) local.get 0 return_call $target)
    #| (func (type $t) local.get 0 i32.const 0 call_indirect (type $t))
    #| (func (type $t) local.get 0 ref.func $target call_ref $t)
    #| (func (type $t) local.get 0 i32.const 0 return_call_indirect (type $t))
    #| (func (type $t) local.get 0 ref.func $target return_call_ref $t)
    #| (func (export "run") (type $t)
    #|   local.get 0 if (result i32)
    #|     local.get 0 return_call $target
    #|   else block (result i32) local.get 0 call $target end end)
    #| (func (type $t) unreachable local.get 0 return_call $target)
    #| (func (type $t)
    #|   (try (result i32) (do local.get 0 return_call $target)
    #|    (catch_all local.get 0 call $target))))
  match @wast.wast_to_binary_module(source) {
    Ok(module_) => module_
    Err(err) => fail("topology fixture: \{err}")
  }
}

///|
fn dae_topology_fusion_assert_equal(
  left : DaeCurrentTopologyExtras,
  right : DaeCurrentTopologyExtras,
) -> Unit raise {
  assert_eq(left.direct_return_callers, right.direct_return_callers)
  assert_eq(
    left.direct_return_callees_by_caller,
    right.direct_return_callees_by_caller,
  )
  assert_eq(left.has_outgoing_call_indirect, right.has_outgoing_call_indirect)
  assert_eq(left.has_outgoing_call_ref, right.has_outgoing_call_ref)
  assert_eq(left.has_outgoing_return_call, right.has_outgoing_return_call)
  assert_eq(
    left.has_outgoing_return_call_indirect,
    right.has_outgoing_return_call_indirect,
  )
  assert_eq(
    left.has_outgoing_return_call_ref,
    right.has_outgoing_return_call_ref,
  )
}

///|
test "DAE boundary construction fuses topology into its required call scan" {
  let input = dae_topology_fusion_fixture()
  @validate.validate_module(input).unwrap()
  let visits = [0]
  let graph = dae_current_boundary_graph_new(
    input,
    topology_walk_visits=Some(visits),
  )
  let reference = dae_collect_current_topology_extras(input, graph.snapshot)
  dae_topology_fusion_assert_equal(graph.topology, reference)
  assert_eq(graph.topology.direct_return_callers[1], [2, 7, 9])
  assert_true(graph.topology.has_outgoing_call_indirect[3])
  assert_true(graph.topology.has_outgoing_call_ref[4])
  assert_true(graph.topology.has_outgoing_return_call_indirect[5])
  assert_true(graph.topology.has_outgoing_return_call_ref[6])
  assert_false(graph.topology.has_outgoing_return_call[8])
  assert_eq(visits[0], 0)
}

///|
test "DAE boundary refresh rebuilds topology alongside changed call facts" {
  let input = dae_topology_fusion_fixture()
  let graph = dae_current_boundary_graph_new(input)
  let bodies = input.code_sec.unwrap().0.copy()
  bodies[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
  )
  let changed = input.with_code_sec(@lib.CodeSec::new(bodies))
  @validate.validate_module(changed).unwrap()
  let visits = [0]
  dae_current_boundary_graph_refresh(
    graph,
    changed,
    topology_walk_visits=Some(visits),
  )
  let fresh = dae_current_boundary_graph_new(changed)
  dae_topology_fusion_assert_equal(graph.topology, fresh.topology)
  assert_true(
    dae_current_call_facts_equal(
      graph.snapshot.call_facts,
      fresh.snapshot.call_facts,
    ),
  )
  assert_eq(graph.topology.direct_return_callers[1], [7, 9])
  assert_false(graph.topology.has_outgoing_return_call[2])
  assert_true(graph.function_epochs[1].body_epoch > 0)
  assert_eq(visits[0], 0)
}

///|
test "DAE supplied topology stays borrowed and typed-only batches omit extras" {
  let input = dae_topology_fusion_fixture()
  let initial = dae_current_boundary_graph_new(input)
  let supplied = initial.topology
  let reused = dae_current_boundary_graph_new(input, topology=Some(supplied))
  assert_true(physical_equal(supplied, reused.topology))
  assert_eq(supplied.direct_return_callers[1], [2, 7, 9])
  let rebuilt = dae_current_boundary_graph_new(
    input,
    topology=Some(dae_empty_topology_extras(0)),
  )
  dae_topology_fusion_assert_equal(rebuilt.topology, supplied)
  let typed = dae_typed_batch_boundary_graph_new(input)
  assert_true(
    dae_current_call_facts_equal(
      initial.snapshot.call_facts,
      typed.snapshot.call_facts,
    ),
  )
  dae_topology_fusion_assert_equal(
    typed.topology,
    dae_empty_topology_extras(initial.snapshot.total),
  )
  assert_eq(supplied.direct_return_callers[1], [2, 7, 9])
}
