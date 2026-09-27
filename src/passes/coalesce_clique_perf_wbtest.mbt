///|
fn cl_clique_bench(
  it : @bench.T,
  width : Int,
  members : Int,
  stride : Int,
  reference : Bool,
) -> Unit {
  let live = Array::makei(members, fn(i) { i * stride })
  let expected = CLCfgSparseInterferences::new(width)
  let actual = CLCfgSparseInterferences::new(width)
  ignore(cl_clique_reference(expected, live))
  ignore(cl_cfg_sparse_add_live_member_interferences(actual, live))
  if expected.rows != actual.rows {
    abort("clique benchmark interference mismatch")
  }
  // Adding the same clique is idempotent. Both controls retain identical rows.
  it.bench(fn() {
    it.keep(
      if reference {
        cl_clique_reference(actual, live)
      } else {
        cl_cfg_sparse_add_live_member_interferences(actual, live)
      },
    )
  })
}

///|
test "bench coalesce pair clique locals=128 live=64" (it : @bench.T) {
  cl_clique_bench(it, 128, 64, 1, true)
}

///|
test "bench coalesce word clique locals=128 live=64" (it : @bench.T) {
  cl_clique_bench(it, 128, 64, 1, false)
}

///|
test "bench coalesce pair clique locals=4096 live=64" (it : @bench.T) {
  cl_clique_bench(it, 4096, 64, 64, true)
}

///|
test "bench coalesce word clique locals=4096 live=64" (it : @bench.T) {
  cl_clique_bench(it, 4096, 64, 64, false)
}

///|
test "bench coalesce pair clique locals=512 live=256" (it : @bench.T) {
  cl_clique_bench(it, 512, 256, 1, true)
}

///|
test "bench coalesce word clique locals=512 live=256" (it : @bench.T) {
  cl_clique_bench(it, 512, 256, 1, false)
}
