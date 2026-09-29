///|
fn source_order_write_free_bench(
  it : @bench.T,
  count : Int,
  write : Bool,
  reference : Bool,
) -> Unit {
  let (func, roots, current) = source_order_write_free_fixture(count, write)
  let left = HotSourceOrderFacts::new(func)
  let right = HotSourceOrderFacts::new(func)
  for root in roots {
    if source_order_write_scan_reference(func, root, current, left) !=
      hot_lower_impl_carried_local_write_conflicts(func, root, current, right) {
      abort("write-free admission changed conflict decisions")
    }
  }
  it.bench(fn() {
    let facts = HotSourceOrderFacts::new(func)
    for root in roots {
      it.keep(
        if reference {
          source_order_write_scan_reference(func, root, current, facts)
        } else {
          hot_lower_impl_carried_local_write_conflicts(
            func, root, current, facts,
          )
        },
      )
    }
  })
}

///|
test "bench source-order write scan depth=16" (it : @bench.T) {
  source_order_write_free_bench(it, 16, false, true)
}

///|
test "bench source-order write admission depth=16" (it : @bench.T) {
  source_order_write_free_bench(it, 16, false, false)
}

///|
test "bench source-order write scan depth=128" (it : @bench.T) {
  source_order_write_free_bench(it, 128, false, true)
}

///|
test "bench source-order write admission depth=128" (it : @bench.T) {
  source_order_write_free_bench(it, 128, false, false)
}

///|
test "bench source-order mixed write scan depth=128" (it : @bench.T) {
  source_order_write_free_bench(it, 128, true, true)
}

///|
test "bench source-order mixed write admission depth=128" (it : @bench.T) {
  source_order_write_free_bench(it, 128, true, false)
}

///|
fn source_order_write_scan_reference(
  func : HotFunc,
  carried_id : NodeId,
  current_root : NodeId,
  facts : HotSourceOrderFacts,
  after_order? : Int = -1,
  before_access_order? : Int = -1,
  access_before_order? : Int? = None,
  access_visits? : Array[Int]? = None,
) -> Bool {
  // Reuse sparse local-access summaries. Allocating function-sized visited
  // and local arrays for every candidate pair makes wide constructors cubic.
  let writes = hot_source_order_local_access_nodes(func, carried_id, facts)
  let mut first_access = hot_node_count(func)
  let mut indexed_orders : @hashmap.HashMap[Int, Int]? = None
  for write_id in writes {
    let write = hot_node_get(func, write_id)
    if (write.op is HotOp::LocalSet || write.op is HotOp::LocalTee) &&
      write.order > after_order &&
      write.imm0 >= 0 &&
      write.imm0 < hot_local_count(func) {
      let accesses = hot_source_order_local_access_nodes(
        func, current_root, facts,
      )
      if writes.length() > 1 && accesses.length() > 4 {
        // Cache the minimum for each local, not merely an access that happens
        // to fall inside this query's interval. Later accesses cannot replace
        // an earlier conflicting access when applying the order bounds.
        let orders = match indexed_orders {
          Some(orders) => orders
          None => {
            let orders = hot_source_order_first_local_access_orders(
              func,
              current_root,
              accesses,
              facts,
              visits=access_visits,
            )
            indexed_orders = Some(orders)
            orders
          }
        }
        let order = orders.get(write.imm0).or(hot_node_count(func))
        if order < first_access {
          first_access = order
        }
      } else {
        for access_id in accesses {
          match access_visits {
            Some(count) => count[0] += 1
            None => ()
          }
          let access = hot_node_get(func, access_id)
          if access.imm0 == write.imm0 && access.order < first_access {
            first_access = access.order
          }
        }
      }
    }
  }
  first_access < access_before_order.or(hot_node_count(func)) &&
  first_access > before_access_order
}
