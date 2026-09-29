///|
fn cl_hazard_program_bench(
  it : @bench.T,
  count : Int,
  dense : Bool,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for source = 1; source <= count; source = source + 1 {
    body.push(@lib.Instruction::i32_const(@lib.I32(source)))
    body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(source.to_uint())))
    if !dense {
      body.push(@lib.Instruction::nop())
      body.push(@lib.Instruction::nop())
    }
  }
  for source = 1; source <= count; source = source + 1 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(source.to_uint())))
    body.push(@lib.Instruction::drop())
  }
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, count + 1)
  let effective = Array::make(actions.length(), true)
  let types = Array::make(count + 1, @lib.ValType::i32())
  let expected = CLBitMatrix::new(count + 1)
  let actual = CLBitMatrix::new(count + 1)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 1, expected,
  )
  cl_add_source_write_dest_read_interferences(
    body, actions, effective, types, 1, actual,
  )
  for source = 0; source <= count; source = source + 1 {
    for dest = source + 1; dest <= count; dest = dest + 1 {
      if cl_bit_matrix_get(actual, source, dest) !=
        cl_bit_matrix_get(expected, source, dest) {
        abort("compiled hazards changed interference")
      }
    }
  }
  it.bench(fn() {
    let matrix = CLBitMatrix::new(count + 1)
    if reference {
      cl_add_source_write_dest_read_interferences_reference(
        body, actions, effective, types, 1, matrix,
      )
    } else {
      cl_add_source_write_dest_read_interferences(
        body, actions, effective, types, 1, matrix,
      )
    }
    it.keep(matrix)
  })
}

///|
test "bench coalesce hazards locals=4 sparse reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 4, false, true)
}

///|
test "bench coalesce hazards locals=4 sparse compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 4, false, false)
}

///|
test "bench coalesce hazards locals=4 dense reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 4, true, true)
}

///|
test "bench coalesce hazards locals=4 dense compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 4, true, false)
}

///|
test "bench coalesce hazards locals=32 sparse reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 32, false, true)
}

///|
test "bench coalesce hazards locals=32 sparse compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 32, false, false)
}

///|
test "bench coalesce hazards locals=32 dense reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 32, true, true)
}

///|
test "bench coalesce hazards locals=32 dense compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 32, true, false)
}

///|
test "bench coalesce hazards locals=128 sparse reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 128, false, true)
}

///|
test "bench coalesce hazards locals=128 sparse compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 128, false, false)
}

///|
test "bench coalesce hazards locals=128 dense reference" (it : @bench.T) {
  cl_hazard_program_bench(it, 128, true, true)
}

///|
test "bench coalesce hazards locals=128 dense compiled" (it : @bench.T) {
  cl_hazard_program_bench(it, 128, true, false)
}
