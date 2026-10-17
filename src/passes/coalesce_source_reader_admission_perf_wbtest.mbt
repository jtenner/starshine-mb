///|
fn cl_reader_admission_perf_fixture(
  count : Int32,
  shape : Int32,
) -> (
  Array[@lib.Instruction],
  Array[CLAction],
  Array[Bool],
  Array[@lib.ValType],
) {
  // 0: dense one group; 1: dense mixed groups; 2: sparse one group.
  let types = Array::makei(count, fn(index) {
    if shape == 1 && index % 2 == 1 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let body : Array[@lib.Instruction] = []
  for local in 0..<count {
    body.push(
      if shape == 1 && local % 2 == 1 {
        @lib.Instruction::i64_const(@lib.I64(local.to_int64()))
      } else {
        @lib.Instruction::i32_const(@lib.I32(local))
      },
    )
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())))
  }
  for local in 0..<count {
    if shape != 2 || local % 4 == 0 {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, count)
  (body, actions, Array::make(actions.length(), true), types)
}

///|
fn cl_reader_admission_bench(
  it : @bench.T,
  count : Int32,
  shape : Int32,
  mode : Int32,
) -> Unit {
  let (body, actions, effective, types) = cl_reader_admission_perf_fixture(
    count, shape,
  )
  let expected = CLBitMatrix::new(count)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 0, expected,
  )
  let original = CLBitMatrix::new(count)
  cl_reader_admission_unconditional_reference(
    body, actions, effective, types, 0, original,
  )
  let actual = CLBitMatrix::new(count)
  cl_add_source_write_dest_read_interferences(
    body, actions, effective, types, 0, actual,
  )
  for source in 0..<count {
    for dest in 0..<count {
      if cl_bit_matrix_get(actual, source, dest) !=
        cl_bit_matrix_get(expected, source, dest) ||
        cl_bit_matrix_get(original, source, dest) !=
        cl_bit_matrix_get(expected, source, dest) {
        abort("reader admission changed an actual hazard matrix bit")
      }
    }
  }
  it.bench(
    fn() {
      let matrix = CLBitMatrix::new(count)
      match mode {
        0 =>
          cl_reader_admission_unconditional_reference(
            body, actions, effective, types, 0, matrix,
          )
        1 =>
          cl_add_source_write_dest_read_interferences(
            body, actions, effective, types, 0, matrix,
          )
        _ =>
          cl_add_source_write_dest_read_interferences(
            body,
            actions,
            effective,
            types,
            0,
            matrix,
            indexed_readers=false,
          )
      }
      it.keep(matrix)
    },
    count=5,
  )
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense4 unconditional-index" (
  it : @bench.T,
) {
  cl_reader_admission_bench(it, 4, 0, 0)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense4 admitted" (it : @bench.T) {
  cl_reader_admission_bench(it, 4, 0, 1)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense4 unindexed" (it : @bench.T) {
  cl_reader_admission_bench(it, 4, 0, 2)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense64 unconditional-index" (
  it : @bench.T,
) {
  cl_reader_admission_bench(it, 64, 0, 0)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense64 admitted" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 0, 1)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission dense64 unindexed" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 0, 2)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission mixed64 unconditional-index" (
  it : @bench.T,
) {
  cl_reader_admission_bench(it, 64, 1, 0)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission mixed64 admitted" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 1, 1)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission mixed64 unindexed" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 1, 2)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission sparse64 unconditional-index" (
  it : @bench.T,
) {
  cl_reader_admission_bench(it, 64, 2, 0)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission sparse64 admitted" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 2, 1)
}

///|
#skip("Native reader-admission footprint control; dedicated perf lane")
test "bench coalesce reader admission sparse64 unindexed" (it : @bench.T) {
  cl_reader_admission_bench(it, 64, 2, 2)
}
