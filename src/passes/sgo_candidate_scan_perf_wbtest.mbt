///|
fn sgo_candidate_scan_reference(
  instrs : Array[@lib.Instruction],
  start : Int,
) -> Int {
  let max_condition_length = 16
  let condition_limit = Int::min(
    instrs.length() - 2,
    start + max_condition_length,
  )
  for if_pos = start + 1; if_pos <= condition_limit; if_pos = if_pos + 1 {
    if !sgo_final_cleanup_pure_expr_range(instrs, start, if_pos) {
      continue
    }
    if if_pos + 1 >= instrs.length() || !(instrs[if_pos + 1] is @lib.Drop) {
      continue
    }
    match instrs[if_pos] {
      @lib.If(@lib.ValTypeBlockType(_), then_body, Some(else_body)) =>
        if sgo_final_cleanup_pure_expr_range(then_body, 0, then_body.length()) &&
          sgo_final_cleanup_pure_expr_range(else_body, 0, else_body.length()) {
          return if_pos - start + 2
        }
      _ => ()
    }
  }
  0
}

///|
fn sgo_candidate_scan_bench(
  it : @bench.T,
  count : Int,
  active : Bool,
  reference : Bool,
) -> Unit {
  let body : Array[@lib.Instruction] = []
  for _ in 0..<count {
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    if active {
      body.push(
        @lib.Instruction::if_(
          @lib.BlockType::val_type(@lib.ValType::i32()),
          [@lib.Instruction::i32_const(@lib.I32(2))],
          Some([@lib.Instruction::i32_const(@lib.I32(3))]),
        ),
      )
    }
    body.push(@lib.Instruction::drop())
  }
  for index = 0; index < body.length(); index = index + 1 {
    if sgo_candidate_scan_reference(body, index) !=
      sgo_final_cleanup_dropped_pure_result_if_length(body, index) {
      abort("SGO candidate scan changed earliest cleanup")
    }
  }
  it.bench(fn() {
    for index = 0; index < body.length(); index = index + 1 {
      it.keep(
        if reference {
          sgo_candidate_scan_reference(body, index)
        } else {
          sgo_final_cleanup_dropped_pure_result_if_length(body, index)
        },
      )
    }
  })
}

///|
test "bench SGO candidate scan count=16 unchanged reference" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 16, false, true)
}

///|
test "bench SGO candidate scan count=16 unchanged gated" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 16, false, false)
}

///|
test "bench SGO candidate scan count=16 active reference" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 16, true, true)
}

///|
test "bench SGO candidate scan count=16 active gated" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 16, true, false)
}

///|
test "bench SGO candidate scan count=256 unchanged reference" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 256, false, true)
}

///|
test "bench SGO candidate scan count=256 unchanged gated" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 256, false, false)
}

///|
test "bench SGO candidate scan count=256 active reference" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 256, true, true)
}

///|
test "bench SGO candidate scan count=256 active gated" (it : @bench.T) {
  sgo_candidate_scan_bench(it, 256, true, false)
}
