///|
fn sl_cleanup_reads_reference(
  instrs : Array[@lib.Instruction],
  reads : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => {
        let local_id = raw.reinterpret_as_int()
        if !reads.contains(local_id) {
          reads.push(local_id)
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        sl_cleanup_reads_reference(body, reads)
      @lib.If(_, then_body, else_body) => {
        sl_cleanup_reads_reference(then_body, reads)
        match else_body {
          Some(body) => sl_cleanup_reads_reference(body, reads)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn sl_cleanup_membership_bench(
  it : @bench.T,
  width : Int,
  reference : Bool,
) -> Unit raise {
  let instrs = Array::makei(width, fn(index) {
    @lib.Instruction::local_get(@lib.LocalIdx::new(index.to_uint()))
  })
  let body = [
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(instrs)),
  ]
  let saved = sl_leaf_bytes(body)
  let expected : Array[Int] = []
  let actual : Array[Int] = []
  sl_cleanup_reads_reference(body, expected)
  run_hot_pipeline_simplify_locals_lowered_collect_local_reads(body, actual)
  assert_eq(actual, expected)
  it.bench(fn() {
    let reads : Array[Int] = []
    if reference {
      sl_cleanup_reads_reference(body, reads)
    } else {
      run_hot_pipeline_simplify_locals_lowered_collect_local_reads(body, reads)
    }
    it.keep(reads)
  })
  assert_eq(sl_leaf_bytes(body), saved)
}

///|
test "bench cleanup ordered read membership width=1 reference" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 1, true)
}

///|
test "bench cleanup ordered read membership width=1 indexed" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 1, false)
}

///|
test "bench cleanup ordered read membership width=8 reference" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 8, true)
}

///|
test "bench cleanup ordered read membership width=8 indexed" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 8, false)
}

///|
test "bench cleanup ordered read membership width=64 reference" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 64, true)
}

///|
test "bench cleanup ordered read membership width=64 indexed" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 64, false)
}

///|
test "bench cleanup ordered read membership width=512 reference" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 512, true)
}

///|
test "bench cleanup ordered read membership width=512 indexed" (it : @bench.T) {
  sl_cleanup_membership_bench(it, 512, false)
}
