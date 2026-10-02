///|
fn vacuum_indexed_tag_gate_reference(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  let row : Array[@lib.Instruction] = []
  for instr in body {
    if !(instr is @lib.Nop) {
      row.push(instr)
    }
  }
  if run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(row) {
    return None
  }
  if row.length() == 51 || row.length() == 57 {
    Some(row)
  } else {
    None
  }
}

///|
fn vacuum_indexed_tag_gate_current(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction]? {
  match vacuum_indexed_tag_candidate_non_nops(body) {
    Some(row) =>
      if run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(row) {
        None
      } else {
        Some(row)
      }
    None => None
  }
}

///|
fn vacuum_indexed_tag_gate_bench(
  it : @bench.T,
  width : Int,
  nested : Bool,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let body = if active {
    pass_manager_test_vacuum_indexed_tag_cascade_body()
  } else {
    let leaf = if nested {
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new(Array::make(1024, @lib.Instruction::nop())),
      )
    } else {
      @lib.Instruction::drop()
    }
    Array::make(width, leaf)
  }
  assert_eq(
    vacuum_indexed_tag_gate_current(body),
    vacuum_indexed_tag_gate_reference(body),
  )
  it.bench(fn() {
    it.keep(
      if reference {
        vacuum_indexed_tag_gate_reference(body)
      } else {
        vacuum_indexed_tag_gate_current(body)
      },
    )
  })
}

///|
test "bench indexed tag width=1 rejected original" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 1, false, false, true)
}

///|
test "bench indexed tag width=1 rejected bounded" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 1, false, false, false)
}

///|
test "bench indexed tag width=4096 rejected original" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 4096, false, false, true)
}

///|
test "bench indexed tag width=4096 rejected bounded" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 4096, false, false, false)
}

///|
test "bench indexed tag width=32 nested rejected original" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 32, true, false, true)
}

///|
test "bench indexed tag width=32 nested rejected bounded" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 32, true, false, false)
}

///|
test "bench indexed tag admitted original" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 57, false, true, true)
}

///|
test "bench indexed tag admitted bounded" (it : @bench.T) {
  vacuum_indexed_tag_gate_bench(it, 57, false, true, false)
}
