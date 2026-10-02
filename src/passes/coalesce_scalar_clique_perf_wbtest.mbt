///|
fn cl_scalar_clique_bench(
  it : @bench.T,
  width : Int,
  count : Int,
  original : Bool,
) -> Unit raise {
  let members = Array::makei(count, fn(i) {
    if width == 64 && count == 15 {
      if i == 14 {
        63
      } else {
        i * 4
      }
    } else {
      i
    }
  })
  let saved = members.copy()
  let actual = CLCfgSparseInterferences::new(width)
  let expected = CLCfgSparseInterferences::new(width)
  actual.rows[1][1] = true
  expected.rows[1][1] = true
  cl_cfg_sparse_add_interference(actual, 0, width - 1)
  cl_cfg_sparse_add_interference(expected, 0, width - 1)
  ignore(cl_scalar_clique_original(expected, members))
  ignore(cl_cfg_sparse_add_live_member_interferences(actual, members))
  assert_eq(actual.rows, expected.rows)
  // Repeating a clique is idempotent. Sink rows as well as the operational
  // pair count, so the scalar path's constant-zero return cannot elide writes.
  it.bench(fn() {
    it.keep(
      if original {
        cl_scalar_clique_original(actual, members)
      } else {
        cl_cfg_sparse_add_live_member_interferences(actual, members)
      },
    )
    it.keep(actual.rows)
  })
  assert_eq(actual.rows, expected.rows)
  assert_eq(members, saved)
}

///|
test "bench CL scalar clique rows=8 live=3 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 8, 3, true)
}

///|
test "bench CL scalar clique rows=8 live=3 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 8, 3, false)
}

///|
test "bench CL scalar clique rows=32 live=8 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 32, 8, true)
}

///|
test "bench CL scalar clique rows=32 live=8 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 32, 8, false)
}

///|
test "bench CL scalar clique rows=64 live=15 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 64, 15, true)
}

///|
test "bench CL scalar clique rows=64 live=15 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 64, 15, false)
}

///|
test "bench CL scalar clique rows=8 live=2 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 8, 2, true)
}

///|
test "bench CL scalar clique rows=8 live=2 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 8, 2, false)
}

///|
test "bench CL scalar clique rows=65 live=8 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 65, 8, true)
}

///|
test "bench CL scalar clique rows=65 live=8 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 65, 8, false)
}

///|
test "bench CL scalar clique rows=64 live=16 original" (it : @bench.T) {
  cl_scalar_clique_bench(it, 64, 16, true)
}

///|
test "bench CL scalar clique rows=64 live=16 scalar" (it : @bench.T) {
  cl_scalar_clique_bench(it, 64, 16, false)
}
