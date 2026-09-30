///|
fn region_fields_bench(
  it : @bench.T,
  width : Int,
  deleted : Int,
  query : Int,
  reference : Bool,
) -> Unit {
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(7))
  let body = hot_build_drop(func, value)
  let ids : Array[NodeId] = []
  for slot in 0..<width {
    ids.push(
      if slot % 2 == 0 {
        hot_build_block(func, @lib.BlockType::void_(), [body, body])
      } else {
        hot_build_loop(func, @lib.BlockType::void_(), [body, body])
      },
    )
  }
  for slot in 0..<deleted {
    hot_delete_node(func, ids[slot])
  }
  let regions = ids[deleted:].map(fn(id) { hot_region_body_ref(func, id) })
  for region in regions {
    if hot_control_node_label(func, region.holder) !=
      region_fields_header_label(func, region.holder) ||
      hot_region_body_base(func, region.holder) !=
      region_fields_header_base(func, region.holder) ||
      hot_region_root_count(func, region) !=
      region_fields_header_count(func, region) ||
      hot_region_get(func, region, 1) !=
      region_fields_header_get(func, region, 1) {
      abort("region fields changed label or body selection")
    }
  }
  let revision = hot_revision_current(func)
  it.bench(fn() {
    for step in 0..<4096 {
      let region = regions[step * 73 % regions.length()]
      let id = region.holder
      it.keep(
        if query == 0 {
          if reference {
            region_fields_header_label(func, id)
          } else {
            hot_control_node_label(func, id)
          }
        } else if query == 1 {
          if reference {
            region_fields_header_base(func, id)
          } else {
            hot_region_body_base(func, id)
          }
        } else if reference {
          region_fields_header_get(func, region, step % 2)
        } else {
          hot_region_get(func, region, step % 2)
        },
      )
    }
  })
  if hot_revision_current(func) != revision {
    abort("region field queries mutated their reusable arena")
  }
}

///|
test "bench region label width=16 deleted=0 header" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 0, true)
}

///|
test "bench region label width=16 deleted=0 fields" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 0, false)
}

///|
test "bench region base width=16 deleted=0 header" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 1, true)
}

///|
test "bench region base width=16 deleted=0 fields" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 1, false)
}

///|
test "bench region get width=16 deleted=0 header" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 2, true)
}

///|
test "bench region get width=16 deleted=0 fields" (it : @bench.T) {
  region_fields_bench(it, 16, 0, 2, false)
}

///|
test "bench region label width=4096 deleted=128 header" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 0, true)
}

///|
test "bench region label width=4096 deleted=128 fields" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 0, false)
}

///|
test "bench region base width=4096 deleted=128 header" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 1, true)
}

///|
test "bench region base width=4096 deleted=128 fields" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 1, false)
}

///|
test "bench region get width=4096 deleted=128 header" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 2, true)
}

///|
test "bench region get width=4096 deleted=128 fields" (it : @bench.T) {
  region_fields_bench(it, 4096, 128, 2, false)
}
