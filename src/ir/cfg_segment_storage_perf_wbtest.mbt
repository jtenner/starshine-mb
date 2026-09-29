///|
fn cfg_segment_storage_rows_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  it.bench(fn() {
    let mut sum = 0
    if reference {
      let rows : Array[CfgSegmentBoxedReference] = []
      for i in 0..<count {
        rows.push({ block_id: i, end_slot: i * 2, last_node: i * 3, })
      }
      for row in rows {
        sum += row.block_id + row.end_slot + row.last_node
      }
      it.keep(rows)
    } else {
      let rows = CfgRegionSegments::new()
      for i in 0..<count {
        rows.push(i, i * 2, i * 3)
      }
      for i in 0..<rows.length() {
        let row = rows.get(i)
        sum += row.block_id + row.end_slot + row.last_node
      }
      it.keep(rows.rows)
    }
    it.keep(sum)
  })
}

///|
fn cfg_segment_storage_region_bench(
  it : @bench.T,
  count : Int,
  reference : Bool,
) -> Unit {
  let func = cfg_segment_storage_fixture(count)
  it.bench(fn() {
    // A fresh builder prevents accumulated block/root arenas. Both paths
    // include source facts, ordering, segmentation and CFG metadata creation.
    let builder = cfg_builder_new(func, true, true)
    if reference {
      it.keep(
        cfg_segment_storage_reference(builder, func, HotRegionRef::root()),
      )
    } else {
      it.keep(
        cfg_builder_region_segments(builder, func, HotRegionRef::root()).rows,
      )
    }
    it.keep(builder.cfg)
  })
}

///|
test "bench CFG segment rows=128 boxed" (it : @bench.T) {
  cfg_segment_storage_rows_bench(it, 128, true)
}

///|
test "bench CFG segment rows=128 packed" (it : @bench.T) {
  cfg_segment_storage_rows_bench(it, 128, false)
}

///|
test "bench CFG segment rows=1024 boxed" (it : @bench.T) {
  cfg_segment_storage_rows_bench(it, 1024, true)
}

///|
test "bench CFG segment rows=1024 packed" (it : @bench.T) {
  cfg_segment_storage_rows_bench(it, 1024, false)
}

///|
test "bench CFG region segments=64 boxed" (it : @bench.T) {
  cfg_segment_storage_region_bench(it, 64, true)
}

///|
test "bench CFG region segments=64 packed" (it : @bench.T) {
  cfg_segment_storage_region_bench(it, 64, false)
}

///|
test "bench CFG region segments=512 boxed" (it : @bench.T) {
  cfg_segment_storage_region_bench(it, 512, true)
}

///|
test "bench CFG region segments=512 packed" (it : @bench.T) {
  cfg_segment_storage_region_bench(it, 512, false)
}
