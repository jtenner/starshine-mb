///|
test "coalesce-locals keeps copied destinations live across later slot writes" {
  let module_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (result i32) (local i32 i32 i32)
      #|    i32.const 11
      #|    local.set 0
      #|    local.get 0
      #|    local.set 1
      #|    i32.const 22
      #|    local.set 2
      #|    local.get 2
      #|    drop
      #|    local.get 1))
    ),
  )
  let @lib.Func(body_locals, @lib.Expr(instrs)) = match module_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => fail("expected code section")
  }
  let types = cl_all_local_types([], body_locals)
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, types.length())
  let liveness = cl_compute_liveness(actions, types.length())
  let interferences = cl_compute_linear_interferences(
    instrs, actions, liveness, types, 0,
  )
  assert_true(
    interferences[2][1],
    msg="later local write must interfere with the still-live copied destination",
  )
}

///|
test "coalesce-locals scans memory-size snapshots across parameter writes linearly" {
  let instrs : Array[@lib.Instruction] = []
  let parameter = @lib.LocalIdx::new(0U)
  let snapshot = @lib.LocalIdx::new(1U)
  for value = 0; value < 4096; value = value + 1 {
    instrs.push(@lib.Instruction::memory_size(@lib.MemIdx::new(0U)))
    instrs.push(@lib.Instruction::local_tee(snapshot))
    instrs.push(@lib.Instruction::drop())
    instrs.push(@lib.Instruction::i32_const(@lib.I32(value)))
    instrs.push(@lib.Instruction::local_set(parameter))
  }
  assert_false(cl_instrs_have_local_snapshot_across_parameter_write(instrs, 1))
}

///|
test "coalesce-locals indexes only effective writers and observed readers for copied-destination hazards" {
  let instrs = [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, 4)
  let (writers, readers) = cl_source_write_dest_read_active_flags(
    actions,
    [true, true],
    4,
  )
  assert_false(writers[0])
  assert_false(writers[1])
  assert_true(writers[2])
  assert_false(writers[3])
  assert_false(readers[0])
  assert_true(readers[1])
  assert_false(readers[2])
  assert_false(readers[3])
  let (syntactic_reads, syntactic_writes) = cl_local_read_write_flags(
    actions, 4,
  )
  assert_false(syntactic_reads[0])
  assert_true(syntactic_reads[1])
  assert_false(syntactic_reads[2])
  assert_false(syntactic_reads[3])
  assert_false(syntactic_writes[0])
  assert_false(syntactic_writes[1])
  assert_true(syntactic_writes[2])
  assert_false(syntactic_writes[3])
}

///|
test "coalesce-locals computes all copied-destination hazards in one source scan" {
  let source = @lib.LocalIdx::new(2U)
  let clobbered_dest = @lib.LocalIdx::new(1U)
  let copied_dest = @lib.LocalIdx::new(3U)
  let instrs = [
    @lib.Instruction::local_get(copied_dest),
    @lib.Instruction::local_set(source),
    @lib.Instruction::local_get(copied_dest),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(11)),
    @lib.Instruction::local_set(source),
    @lib.Instruction::local_get(clobbered_dest),
    @lib.Instruction::drop(),
  ]
  let actions : Array[CLAction] = []
  cl_collect_instrs(instrs, actions, 4)
  let effective = Array::make(actions.length(), true)
  let hazards = cl_source_write_dest_read_hazards(instrs, effective, 2, 4)
  assert_false(hazards[0])
  assert_true(hazards[1])
  assert_false(hazards[2])
  assert_false(hazards[3])
}
