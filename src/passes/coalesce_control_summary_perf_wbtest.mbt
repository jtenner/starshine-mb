///|
fn cl_control_summary_bench(
  it : @bench.T,
  depth : Int,
  self_branch : Bool,
  reference : Bool,
) -> Unit {
  let mut instr = if self_branch {
    @lib.Instruction::br(@lib.LabelIdx::new(0U))
  } else {
    @lib.Instruction::return_()
  }
  for index = 0; index < depth; index = index + 1 {
    instr = @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([instr, @lib.Instruction::unreachable_()]),
    )
  }
  let expected = cl_instr_never_falls_through_reference(instr)
  if cl_instr_never_falls_through(instr) != expected {
    abort("control summary changed fallthrough")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        cl_instr_never_falls_through_reference(instr)
      } else {
        cl_instr_never_falls_through(instr)
      },
    )
  })
}

///|
test "bench coalesce control depth=1 return reference" (it : @bench.T) {
  cl_control_summary_bench(it, 1, false, true)
}

///|
test "bench coalesce control depth=1 return summary" (it : @bench.T) {
  cl_control_summary_bench(it, 1, false, false)
}

///|
test "bench coalesce control depth=1 self-branch reference" (it : @bench.T) {
  cl_control_summary_bench(it, 1, true, true)
}

///|
test "bench coalesce control depth=1 self-branch summary" (it : @bench.T) {
  cl_control_summary_bench(it, 1, true, false)
}

///|
test "bench coalesce control depth=4 return reference" (it : @bench.T) {
  cl_control_summary_bench(it, 4, false, true)
}

///|
test "bench coalesce control depth=4 return summary" (it : @bench.T) {
  cl_control_summary_bench(it, 4, false, false)
}

///|
test "bench coalesce control depth=4 self-branch reference" (it : @bench.T) {
  cl_control_summary_bench(it, 4, true, true)
}

///|
test "bench coalesce control depth=4 self-branch summary" (it : @bench.T) {
  cl_control_summary_bench(it, 4, true, false)
}

///|
test "bench coalesce control depth=32 return reference" (it : @bench.T) {
  cl_control_summary_bench(it, 32, false, true)
}

///|
test "bench coalesce control depth=32 return summary" (it : @bench.T) {
  cl_control_summary_bench(it, 32, false, false)
}

///|
test "bench coalesce control depth=32 self-branch reference" (it : @bench.T) {
  cl_control_summary_bench(it, 32, true, true)
}

///|
test "bench coalesce control depth=32 self-branch summary" (it : @bench.T) {
  cl_control_summary_bench(it, 32, true, false)
}

///|
test "bench coalesce control depth=128 return reference" (it : @bench.T) {
  cl_control_summary_bench(it, 128, false, true)
}

///|
test "bench coalesce control depth=128 return summary" (it : @bench.T) {
  cl_control_summary_bench(it, 128, false, false)
}

///|
test "bench coalesce control depth=128 self-branch reference" (it : @bench.T) {
  cl_control_summary_bench(it, 128, true, true)
}

///|
test "bench coalesce control depth=128 self-branch summary" (it : @bench.T) {
  cl_control_summary_bench(it, 128, true, false)
}

///|
test "bench coalesce control depth=512 return reference" (it : @bench.T) {
  cl_control_summary_bench(it, 512, false, true)
}

///|
test "bench coalesce control depth=512 return summary" (it : @bench.T) {
  cl_control_summary_bench(it, 512, false, false)
}

///|
test "bench coalesce control depth=512 self-branch reference" (it : @bench.T) {
  cl_control_summary_bench(it, 512, true, true)
}

///|
test "bench coalesce control depth=512 self-branch summary" (it : @bench.T) {
  cl_control_summary_bench(it, 512, true, false)
}

///|
fn cl_control_collector_bench(
  it : @bench.T,
  depth : Int,
  reference : Bool,
) -> Unit {
  let body = [cl_control_nested_fixture(depth)]
  it.bench(fn() {
    let actions : Array[CLAction] = []
    if reference {
      cl_collect_instrs_reference(body, actions, 1)
    } else {
      cl_collect_instrs(body, actions, 1)
    }
    it.keep(actions)
  })
}

///|
test "bench coalesce collector depth=4 reference" (it : @bench.T) {
  cl_control_collector_bench(it, 4, true)
}

///|
test "bench coalesce collector depth=4 indexed" (it : @bench.T) {
  cl_control_collector_bench(it, 4, false)
}

///|
test "bench coalesce collector depth=32 reference" (it : @bench.T) {
  cl_control_collector_bench(it, 32, true)
}

///|
test "bench coalesce collector depth=32 indexed" (it : @bench.T) {
  cl_control_collector_bench(it, 32, false)
}

///|
test "bench coalesce collector depth=128 reference" (it : @bench.T) {
  cl_control_collector_bench(it, 128, true)
}

///|
test "bench coalesce collector depth=128 indexed" (it : @bench.T) {
  cl_control_collector_bench(it, 128, false)
}

///|
test "bench coalesce collector depth=512 reference" (it : @bench.T) {
  cl_control_collector_bench(it, 512, true)
}

///|
test "bench coalesce collector depth=512 indexed" (it : @bench.T) {
  cl_control_collector_bench(it, 512, false)
}
