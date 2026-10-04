///|
fn cl_path_scan_value_bench(
  it : @bench.T,
  width : Int,
  nested : Bool,
  unsupported : Bool,
) -> Unit {
  let mut body : Array[@lib.Instruction] = [@lib.Instruction::nop()]
  if unsupported {
    body.push(@lib.Instruction::return_())
  }
  if nested {
    for _ in 0..<width {
      body = [
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(body)),
      ]
    }
  } else {
    body = Array::make(
      width,
      @lib.Instruction::if_(@lib.BlockType::void_(), body, Some(body)),
    )
  }
  let checked = cl_scan_path_disjoint_branch_result_instrs(
    body, 1, 0, true, false, false,
  )
  if checked.ok == unsupported {
    abort("path scan benchmark changed admission")
  }
  it.bench(fn() {
    let result = cl_scan_path_disjoint_branch_result_instrs(
      body, 1, 0, true, false, false,
    )
    it.keep(result.ok)
    it.keep(result.source_initialized)
  })
}

///|
test "bench path scan result single branch" (it : @bench.T) {
  cl_path_scan_value_bench(it, 1, false, false)
}

///|
test "bench path scan result wide branches" (it : @bench.T) {
  cl_path_scan_value_bench(it, 64, false, false)
}

///|
test "bench path scan result nested blocks" (it : @bench.T) {
  cl_path_scan_value_bench(it, 64, true, false)
}

///|
test "bench path scan result unsupported control" (it : @bench.T) {
  cl_path_scan_value_bench(it, 16, true, true)
}
