///|
fn cl_sparse_extra_bench(
  it : @bench.T,
  width : Int,
  dense : Bool,
  structured : Bool,
  reference : Bool,
) -> Unit {
  let hazards = CLBitMatrix::new(width)
  let types = Array::make(width, @lib.ValType::i32())
  for lower = 0; lower < width; lower = lower + 1 {
    for upper = lower + 1; upper < width; upper = upper + 1 {
      if dense || (lower % 17 == 0 && upper == width - 1) {
        cl_bit_matrix_set(hazards, lower, upper, true)
      }
    }
  }
  let (actions, liveness, _) = cl_structured_live_fixture(width, 16)
  it.bench(fn() {
    let matrix = CLBitMatrix::new(width)
    if structured {
      if reference {
        cl_add_structured_write_live_interferences_reference(
          hazards, types, 2, matrix,
        )
      } else {
        cl_add_structured_write_live_interferences(hazards, types, 2, matrix)
      }
    } else if reference {
      cl_add_plain_live_interferences_reference(actions, liveness, matrix)
    } else {
      cl_add_plain_live_interferences(actions, liveness, matrix)
    }
    it.keep(matrix.bits)
  })
}

///|
test "bench coalesce write-hazards width=4 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, false, true, true)
}

///|
test "bench coalesce write-hazards width=4 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, false, true, false)
}

///|
test "bench coalesce write-hazards width=4 dense reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, true, true, true)
}

///|
test "bench coalesce write-hazards width=4 dense members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, true, true, false)
}

///|
test "bench coalesce plain-live width=4 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, false, false, true)
}

///|
test "bench coalesce plain-live width=4 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 4, false, false, false)
}

///|
test "bench coalesce write-hazards width=128 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, false, true, true)
}

///|
test "bench coalesce write-hazards width=128 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, false, true, false)
}

///|
test "bench coalesce write-hazards width=128 dense reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, true, true, true)
}

///|
test "bench coalesce write-hazards width=128 dense members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, true, true, false)
}

///|
test "bench coalesce plain-live width=128 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, false, false, true)
}

///|
test "bench coalesce plain-live width=128 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 128, false, false, false)
}

///|
test "bench coalesce write-hazards width=1024 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, false, true, true)
}

///|
test "bench coalesce write-hazards width=1024 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, false, true, false)
}

///|
test "bench coalesce write-hazards width=1024 dense reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, true, true, true)
}

///|
test "bench coalesce write-hazards width=1024 dense members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, true, true, false)
}

///|
test "bench coalesce plain-live width=1024 sparse reference" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, false, false, true)
}

///|
test "bench coalesce plain-live width=1024 sparse members" (it : @bench.T) {
  cl_sparse_extra_bench(it, 1024, false, false, false)
}
