///|
test "OI root storage preserves positions instruction identity and control barriers" {
  let cases = [
    (
      @lib.Instruction::nop(),
      RawOiRootKind::Other,
      false,
      false,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::i32_const(@lib.I32::new(7)),
      RawOiRootKind::I32Const,
      false,
      false,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      RawOiRootKind::LocalGet,
      false,
      false,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      RawOiRootKind::DirectCall,
      false,
      false,
      true,
      false,
      false,
    ),
    (
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
      RawOiRootKind::CallRef,
      false,
      false,
      true,
      false,
      false,
    ),
    (
      @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U)),
      RawOiRootKind::ReturnCallRef,
      false,
      false,
      true,
      true,
      false,
    ),
    (
      @lib.Instruction::return_(),
      RawOiRootKind::Other,
      false,
      false,
      true,
      true,
      false,
    ),
    (
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      RawOiRootKind::Other,
      false,
      true,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::unreachable_(),
      RawOiRootKind::Other,
      false,
      false,
      false,
      false,
      true,
    ),
    (
      @lib.Instruction::throw_ref(),
      RawOiRootKind::Other,
      false,
      false,
      false,
      false,
      true,
    ),
    (
      @lib.Instruction::array_len(),
      RawOiRootKind::ArrayLen,
      false,
      false,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([])),
      RawOiRootKind::StructuredBlock,
      true,
      false,
      false,
      false,
      false,
    ),
    (
      @lib.Instruction::if_(@lib.BlockType::void_(), [], None),
      RawOiRootKind::If,
      true,
      false,
      false,
      false,
      false,
    ),
  ]
  let body = cases.map(fn(row) { row.0 })
  let region = RawOiInstructionRegionFact::from_instrs(body)
  assert_eq(region.roots.length(), body.length())
  for position in 0..<body.length() {
    let (instr, kind, nested, branch, call, exit_, trap) = cases[position]
    let root = region.roots[position]
    assert_eq(root.position, position)
    assert_true(physical_equal(root.instr, instr))
    assert_true(
      RawOiFunctionRevisionFactIndex::root_kind_matches(root.kind, kind),
    )
    assert_eq(
      root.is_pure_stack_operand,
      run_hot_pipeline_optimize_instructions_instr_is_pure_stack_call_operand(
        instr,
      ),
    )
    assert_eq(root.flow.has_nested_control, nested)
    assert_eq(root.flow.has_branch, branch)
    assert_eq(root.flow.has_call, call)
    assert_eq(root.flow.has_function_exit, exit_)
    assert_eq(root.flow.has_throw_or_trap, trap)
    assert_eq(
      root.flow.blocks_branch_free_value_region(),
      nested || branch || call || exit_ || trap,
    )
    assert_true(region.has_root_at(position, kind))
  }
  assert_false(region.has_root_at(-1, RawOiRootKind::Other))
  assert_false(region.has_root_at(body.length(), RawOiRootKind::Other))
}

///|
test "OI root storage rebuild observes edited nested regions without stale facts" {
  let child = [@lib.Instruction::call(@lib.FuncIdx::new(3U))]
  let body = [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(child)),
  ]
  let before = RawOiFunctionRevisionFactIndex::from_instrs(body)
  assert_eq(before.instruction_count, 3)
  assert_eq(before.top_level_pure_stack_prefix_count, 1)
  assert_eq(before.regions.length(), 2)
  assert_eq(before.call_sites.length(), 1)
  assert_true(before.regions[1].has_call_like_root_at(0))
  child[0] = @lib.Instruction::unreachable_()
  body[0] = @lib.Instruction::local_tee(@lib.LocalIdx::new(0U))
  let after = RawOiFunctionRevisionFactIndex::from_instrs(body)
  assert_eq(after.instruction_count, 3)
  assert_eq(after.top_level_pure_stack_prefix_count, 0)
  assert_eq(after.call_sites.length(), 0)
  assert_false(after.regions[1].has_call_like_root_at(0))
  assert_true(after.regions[1].roots[0].flow.has_throw_or_trap)
  assert_true(physical_equal(after.regions[1].roots[0].instr, child[0]))
  // Previously collected facts remain a snapshot, never a proof for the edit.
  assert_true(before.regions[1].has_call_like_root_at(0))
  assert_true(before.top_level_roots[0].kind is I32Const)
  assert_true(after.top_level_roots[0].kind is LocalTee)
}

///|
// Frozen boxed root-storage boundary; classification and shared flow are unchanged.
priv struct OiBoxedRootStorageReference {
  position : Int
  kind : RawOiRootKind
  instr : @lib.Instruction
  is_pure_stack_operand : Bool
  flow : RawOiRootFlowFact
}

///|
priv struct OiBoxedRegionStorageReference {
  roots : Array[OiBoxedRootStorageReference]
}

///|
fn OiBoxedRegionStorageReference::from_instrs(
  body : Array[@lib.Instruction],
) -> OiBoxedRegionStorageReference {
  {
    roots: body.mapi(fn(position, instr) {
      OiBoxedRootStorageReference::from_instr(position, instr)
    }),
  }
}

///|
fn OiBoxedRootStorageReference::from_instr(
  position : Int,
  instr : @lib.Instruction,
) -> OiBoxedRootStorageReference {
  let kind = match instr {
    @lib.Call(_) => RawOiRootKind::DirectCall
    @lib.CallIndirect(_, _) => RawOiRootKind::CallLike
    @lib.CallRef(_) => RawOiRootKind::CallRef
    @lib.ReturnCallRef(_) => RawOiRootKind::ReturnCallRef
    @lib.TableGet(_) => RawOiRootKind::TableGet
    @lib.StructNew(_) => RawOiRootKind::StructConstructor
    @lib.StructGet(_, _) => RawOiRootKind::StructRead
    @lib.ArrayNew(_) | @lib.ArrayNewFixed(_, _) | @lib.ArrayNewDefault(_) =>
      RawOiRootKind::ArrayConstructor
    @lib.ArrayGet(_) => RawOiRootKind::ArrayRead
    @lib.ArraySet(_) => RawOiRootKind::ArrayWrite
    @lib.ArrayLen => RawOiRootKind::ArrayLen
    @lib.I32Const(_) => RawOiRootKind::I32Const
    @lib.Block(_, _) => RawOiRootKind::StructuredBlock
    @lib.If(_, _, _) => RawOiRootKind::If
    @lib.Select(_) => RawOiRootKind::Select
    @lib.MemorySize(_) => RawOiRootKind::MemorySize
    @lib.MemoryCopy(_, _) | @lib.MemoryFill(_) => RawOiRootKind::BulkMemory
    @lib.LocalGet(_) => RawOiRootKind::LocalGet
    @lib.LocalTee(_) => RawOiRootKind::LocalTee
    @lib.RefNull(_) => RawOiRootKind::RefNull
    @lib.RefAsNonNull => RawOiRootKind::RefAsNonNull
    @lib.RefGetDesc(_) => RawOiRootKind::RefGetDesc
    @lib.RefCastDescEq(_, _, _) => RawOiRootKind::RefCastDescEq
    instr if run_hot_pipeline_optimize_instructions_instr_is_plain_load(instr) =>
      RawOiRootKind::PlainLoad
    instr if RawOiMemoryAccessMemargFact::from_store_instr(instr) is Some(_) =>
      RawOiRootKind::MemoryStore
    instr if run_hot_pipeline_optimize_instructions_instr_is_commutative_integer_binop(
        instr,
      ) => RawOiRootKind::CommutativeIntegerBinop
    @lib.I32Sub
    | @lib.I64Sub
    | @lib.I32Eq
    | @lib.I32Ne
    | @lib.I64Eq
    | @lib.I64Ne
    | @lib.I32LtS
    | @lib.I32LeS
    | @lib.I32GtS
    | @lib.I32GeS
    | @lib.I64LtS
    | @lib.I64LeS
    | @lib.I64GtS
    | @lib.I64GeS
    | @lib.I32DivS
    | @lib.I32RemS
    | @lib.I32ShrS
    | @lib.I64DivS
    | @lib.I64RemS
    | @lib.I64ShrS
    | @lib.F32Sub
    | @lib.F64Sub
    | @lib.I32WrapI64 => RawOiRootKind::ScalarNumericTerminal
    _ => RawOiRootKind::Other
  }
  {
    position,
    kind,
    instr,
    is_pure_stack_operand: run_hot_pipeline_optimize_instructions_instr_is_pure_stack_call_operand(
      instr,
    ),
    flow: RawOiRootFlowFact::from_instr(instr),
  }
}
