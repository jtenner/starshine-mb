///|
fn cl_reader_index_perf_fixture(
  count : Int32,
  sparse_mixed : Bool,
) -> (
  Array[@lib.Instruction],
  Array[CLAction],
  Array[Bool],
  Array[@lib.ValType],
) {
  let types = Array::makei(count, fn(index) {
    if sparse_mixed && index % 2 == 1 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let body : Array[@lib.Instruction] = []
  for index in 0..<count {
    body.push(
      if sparse_mixed && index % 2 == 1 {
        @lib.Instruction::i64_const(@lib.I64(index.to_int64()))
      } else {
        @lib.Instruction::i32_const(@lib.I32(index))
      },
    )
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(index.to_uint())))
  }
  for index in 0..<count {
    if !sparse_mixed || index % 4 == 0 {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, count)
  (body, actions, Array::make(actions.length(), true), types)
}

///|
fn cl_reader_index_bench(
  it : @bench.T,
  count : Int32,
  sparse_mixed : Bool,
  indexed : Bool,
) -> Unit {
  let (body, actions, effective, types) = cl_reader_index_perf_fixture(
    count, sparse_mixed,
  )
  let expected = CLBitMatrix::new(count)
  let actual = CLBitMatrix::new(count)
  cl_add_source_write_dest_read_interferences(
    body,
    actions,
    effective,
    types,
    0,
    expected,
    indexed_readers=false,
  )
  cl_add_source_write_dest_read_interferences(
    body, actions, effective, types, 0, actual,
  )
  for source in 0..<count {
    for dest in (source + 1)..<count {
      if cl_bit_matrix_get(actual, source, dest) !=
        cl_bit_matrix_get(expected, source, dest) {
        abort("reader index changed an interference bit")
      }
    }
  }
  it.bench(fn() {
    let matrix = CLBitMatrix::new(count)
    cl_add_source_write_dest_read_interferences(
      body,
      actions,
      effective,
      types,
      0,
      matrix,
      indexed_readers=indexed,
    )
    it.keep(matrix)
  })
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index small reference" (it : @bench.T) {
  cl_reader_index_bench(it, 4, false, false)
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index small indexed" (it : @bench.T) {
  cl_reader_index_bench(it, 4, false, true)
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index mixed reference" (it : @bench.T) {
  cl_reader_index_bench(it, 64, true, false)
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index mixed indexed" (it : @bench.T) {
  cl_reader_index_bench(it, 64, true, true)
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index dense reference" (it : @bench.T) {
  cl_reader_index_bench(it, 64, false, false)
}

///|
#skip("Native paired reader-index footprint control; dedicated perf lane")
test "bench coalesce reader index dense indexed" (it : @bench.T) {
  cl_reader_index_bench(it, 64, false, true)
}
