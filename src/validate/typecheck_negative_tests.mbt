///|
fn tcneg_make_state(env : Env, stack : Array[ValType]) -> TcState {
  { env, stack, reachable: true }
}

///|
fn[T : Show] tcneg_assert_err_contains(
  result : Result[T, String],
  needle : String,
) -> Unit {
  match result {
    Ok(v) => abort("expected Err containing '\{needle}', got Ok: \{v}")
    Err(e) =>
      if !e.contains(needle) {
        abort("expected Err containing '\{needle}', got: \{e}")
      }
  }
}

///|
fn tcneg_anyref() -> ValType {
  ValType::ref_type(RefType::abs(AbsHeapType::any()))
}

///|
fn tcneg_nullable_ref(ht : HeapType) -> ValType {
  ValType::ref_type(RefType::new(true, ht))
}

///|
fn tcneg_non_nullable_ref(ht : HeapType) -> ValType {
  ValType::ref_type(RefType::new(false, ht))
}

///|
fn tcneg_i32_mem_env() -> Env {
  Env::{ ..empty_env(), mems: [MemType::new(Limits::i32(1, None))] }
}

///|
fn tcneg_single_functype_subtype(
  params : Array[ValType],
  results : Array[ValType],
) -> SubType {
  SubType::comp_type(CompType::func(params, results))
}

///|
test "Typecheck RefGetDesc rejects nullable operand" {
  let state = tcneg_make_state(empty_env(), [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::i31())),
  ])
  let result = Typecheck::typecheck(Instruction::ref_get_desc(), state)
  tcneg_assert_err_contains(result, "non-null reference operand")
}

///|
test "Typecheck RefGetDesc rejects non-reference operand" {
  let state = tcneg_make_state(empty_env(), [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::ref_get_desc(), state)
  tcneg_assert_err_contains(result, "expected a reference operand")
}

///|
test "Typecheck RefTestDesc rejects non-reference operand" {
  let state = tcneg_make_state(empty_env(), [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::eq())),
    state,
  )
  tcneg_assert_err_contains(result, "ref.test_desc expects a reference operand")
}

///|
test "Typecheck RefTestDesc rejects incompatible target hierarchy" {
  let state = tcneg_make_state(empty_env(), [
    tcneg_non_nullable_ref(HeapType::abs(AbsHeapType::func())),
  ])
  let result = Typecheck::typecheck(
    Instruction::ref_test_desc(true, HeapType::abs(AbsHeapType::i31())),
    state,
  )
  tcneg_assert_err_contains(result, "target does not match operand type")
}

///|
test "Typecheck RefTestDesc rejects invalid descriptor target type index" {
  let state = tcneg_make_state(empty_env(), [tcneg_anyref()])
  let result = Typecheck::typecheck(
    Instruction::ref_test_desc(false, HeapType::new(TypeIdx::new(999))),
    state,
  )
  tcneg_assert_err_contains(result, "invalid descriptor target reftype")
}

///|
test "Typecheck RefCastDescEq rejects incompatible target hierarchy" {
  let state = tcneg_make_state(empty_env(), [
    tcneg_non_nullable_ref(HeapType::abs(AbsHeapType::func())),
  ])
  let result = Typecheck::typecheck(
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::i31())),
    state,
  )
  tcneg_assert_err_contains(result, "target does not match operand type")
}

///|
test "Typecheck RefCastDescEq rejects invalid descriptor target type index" {
  let state = tcneg_make_state(empty_env(), [tcneg_anyref()])
  let result = Typecheck::typecheck(
    Instruction::ref_cast_desc_eq(false, HeapType::new(TypeIdx::new(999))),
    state,
  )
  tcneg_assert_err_contains(result, "invalid descriptor target reftype")
}

///|
test "Typecheck RefCastDescEq accepts polymorphic stack in unreachable state" {
  let state : TcState = { env: empty_env(), stack: [], reachable: false }
  let result = Typecheck::typecheck(
    Instruction::ref_cast_desc_eq(true, HeapType::abs(AbsHeapType::eq())),
    state,
  )
  match result {
    Err(e) =>
      fail("unexpected ref.cast_desc_eq error in unreachable state: \{e}")
    Ok(next) =>
      assert_stack(next, [ValType::ref_null(HeapType::abs(AbsHeapType::eq()))])
  }
}

///|
test "Typecheck MemoryAtomicNotify stack effect" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::memory_atomic_notify(mem_arg),
    state,
  )
  match result {
    Err(e) => fail("unexpected atomic.notify error: \{e}")
    Ok(next) => assert_stack(next, [ValType::i32()])
  }
}

///|
test "Typecheck MemoryAtomicNotify rejects non-i32 count" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i64()])
  let result = Typecheck::typecheck(
    Instruction::memory_atomic_notify(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck MemoryAtomicWait32 rejects non-i64 timeout" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [
    ValType::i32(),
    ValType::i32(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::memory_atomic_wait32(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck MemoryAtomicWait32 rejects non-i32 expected value" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [
    ValType::i32(),
    ValType::i64(),
    ValType::i64(),
  ])
  let result = Typecheck::typecheck(
    Instruction::memory_atomic_wait32(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck MemoryAtomicWait64 rejects non-i64 expected value" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [
    ValType::i32(),
    ValType::i32(),
    ValType::i64(),
  ])
  let result = Typecheck::typecheck(
    Instruction::memory_atomic_wait64(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck AtomicRmw rejects wrong value type" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i64()])
  let result = Typecheck::typecheck(
    Instruction::atomic_rmw(AtomicRmwOp::i32_add(), mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck AtomicCmpxchg rejects wrong replacement type" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(0))
  let state = tcneg_make_state(env, [
    ValType::i32(),
    ValType::i64(),
    ValType::i32(),
  ])
  let result = Typecheck::typecheck(
    Instruction::atomic_cmpxchg(AtomicCmpxchgOp::i64(), mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck atomic load rejects invalid memory index in memarg" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), Some(MemIdx::new(1)), U64(0))
  let state = tcneg_make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i32_atomic_load(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "invalid memory index in memarg")
}

///|
test "Typecheck atomic load rejects oversized memarg alignment" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(3), None, U64(0))
  let state = tcneg_make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i32_atomic_load(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "alignment too large for access width")
}

///|
test "Typecheck atomic store rejects out-of-range i32 memarg offset" {
  let env = tcneg_i32_mem_env()
  let mem_arg = MemArg::new(U32(0), None, U64(4294967296))
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::i32_atomic_store(mem_arg),
    state,
  )
  tcneg_assert_err_contains(result, "offset out of range for i32 memory")
}

///|
test "Typecheck AtomicFence preserves stack" {
  let state = tcneg_make_state(empty_env(), [ValType::i32(), ValType::i64()])
  let result = Typecheck::typecheck(Instruction::atomic_fence(), state)
  match result {
    Err(e) => fail("unexpected atomic.fence error: \{e}")
    Ok(next) => assert_stack(next, [ValType::i32(), ValType::i64()])
  }
}

///|
test "Typecheck CallIndirect rejects non-funcref-compatible table element types" {
  let func_type = tcneg_single_functype_subtype([ValType::i32()], [
    ValType::i64(),
  ])
  let bad_table = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
    Limits::i32(1, None),
  )
  let env = Env::{
    ..empty_env(),
    global_types: [func_type],
    tables: [bad_table],
  }
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "not funcref-compatible")
}

///|
test "Typecheck CallIndirect rejects invalid table index" {
  let func_type = tcneg_single_functype_subtype([ValType::i32()], [
    ValType::i64(),
  ])
  let env = Env::{ ..empty_env(), global_types: [func_type] }
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "invalid table index")
}

///|
test "Typecheck ReturnCallIndirect rejects tail-call result mismatches" {
  let func_type = tcneg_single_functype_subtype([ValType::i32()], [
    ValType::i64(),
  ])
  let good_table = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
    Limits::i32(1, None),
  )
  let env = Env::{
    ..empty_env(),
    global_types: [func_type],
    tables: [good_table],
    return_type: Some([ValType::i32()]),
  }
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::return_call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "tail call result mismatch")
}

///|
test "Typecheck ReturnCallIndirect rejects non-funcref-compatible tables" {
  let func_type = tcneg_single_functype_subtype([ValType::i32()], [
    ValType::i64(),
  ])
  let bad_table = TableType::new(
    RefType::new(true, HeapType::abs(AbsHeapType::extern_())),
    Limits::i32(1, None),
  )
  let env = Env::{
    ..empty_env(),
    global_types: [func_type],
    tables: [bad_table],
    return_type: Some([ValType::i64()]),
  }
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::return_call_indirect(TypeIdx::new(0), TableIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "not funcref-compatible")
}

///|
test "Typecheck TryTable catch rejects payload-label mismatches" {
  let tag_sig = tcneg_single_functype_subtype([ValType::i32()], [])
  let env = Env::{ ..empty_env(), global_types: [tag_sig] }
    .push_tag(TagType::new(TypeIdx::new(0)))
    .with_label([])
  let state = tcneg_make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::new(TagIdx::new(0), LabelIdx::new(0))],
      Expr::new([Instruction::nop()]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "payload")
}

///|
test "Typecheck TryTable catch_ref rejects payload+exnref label mismatches" {
  let tag_sig = tcneg_single_functype_subtype([ValType::i32()], [])
  let env = Env::{ ..empty_env(), global_types: [tag_sig] }
    .push_tag(TagType::new(TypeIdx::new(0)))
    .with_label([])
  let state = tcneg_make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::ref_(TagIdx::new(0), LabelIdx::new(0))],
      Expr::new([Instruction::nop()]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "payload + exnref")
}

///|
test "Typecheck TryTable catch rejects invalid catch label index" {
  let tag_sig = tcneg_single_functype_subtype([], [])
  let env = Env::{ ..empty_env(), global_types: [tag_sig] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
  let state = tcneg_make_state(env, [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::void_(),
      [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
      Expr::new([Instruction::nop()]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "Invalid catch label index")
}

///|
test "Typecheck TryTable catch_all rejects labels expecting values" {
  let state = tcneg_make_state(empty_env().with_label([ValType::i32()]), [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::val_type(ValType::i32()),
      [Catch::all(LabelIdx::new(0))],
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "catch_all label must expect no values")
}

///|
test "Typecheck TryTable catch_all_ref rejects labels with non-exnref type" {
  let state = tcneg_make_state(empty_env().with_label([ValType::i32()]), [])
  let result = Typecheck::typecheck(
    Instruction::try_table(
      BlockType::val_type(ValType::i32()),
      [Catch::all_ref(LabelIdx::new(0))],
      Expr::new([Instruction::i32_const(I32(0))]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "catch_all_ref label must expect exnref")
}

///|
test "Typecheck BrOnCast rejects labels with no reftype payload slot" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::any())),
  ])
  let result = Typecheck::typecheck(
    Instruction::br_on_cast(
      LabelIdx::new(0),
      true,
      HeapType::abs(AbsHeapType::any()),
      true,
      HeapType::abs(AbsHeapType::eq()),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "label type too short")
}

///|
test "Typecheck BrOnCast requires label to end in a reftype" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = tcneg_make_state(env, [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::any())),
  ])
  let result = Typecheck::typecheck(
    Instruction::br_on_cast(
      LabelIdx::new(0),
      true,
      HeapType::abs(AbsHeapType::any()),
      true,
      HeapType::abs(AbsHeapType::eq()),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "label must end with a reftype")
}

///|
test "Typecheck BrOnCast rejects rt2 that is not a subtype of rt1" {
  let env = empty_env().with_labels([
    [tcneg_nullable_ref(HeapType::abs(AbsHeapType::i31()))],
  ])
  let state = tcneg_make_state(env, [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::func())),
  ])
  let result = Typecheck::typecheck(
    Instruction::br_on_cast(
      LabelIdx::new(0),
      true,
      HeapType::abs(AbsHeapType::func()),
      true,
      HeapType::abs(AbsHeapType::i31()),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "rt2 does not match rt1")
}

///|
test "Typecheck BrOnCastFail rejects labels with no reftype payload slot" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::any())),
  ])
  let result = Typecheck::typecheck(
    Instruction::br_on_cast_fail(
      LabelIdx::new(0),
      true,
      HeapType::abs(AbsHeapType::any()),
      true,
      HeapType::abs(AbsHeapType::eq()),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "label type too short")
}

///|
test "Typecheck BrOnCastFail rejects labels that mismatch rt1 \\ rt2" {
  let env = empty_env().with_labels([
    [tcneg_nullable_ref(HeapType::abs(AbsHeapType::func()))],
  ])
  let state = tcneg_make_state(env, [
    tcneg_nullable_ref(HeapType::abs(AbsHeapType::eq())),
  ])
  let result = Typecheck::typecheck(
    Instruction::br_on_cast_fail(
      LabelIdx::new(0),
      true,
      HeapType::abs(AbsHeapType::eq()),
      true,
      HeapType::abs(AbsHeapType::i31()),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "does not match label rt")
}

// =============================================================================
// BRANCH / LABEL ERROR NEGATIVE-PATH TESTS
// =============================================================================

///|
test "Typecheck br with invalid label index" {
  let env = empty_env() // no labels
  let state = tcneg_make_state(env, [])
  let result = Typecheck::typecheck(Instruction::br(LabelIdx::new(0)), state)
  tcneg_assert_err_contains(result, "invalid label index")
}

///|
test "Typecheck br with out-of-range label index" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = tcneg_make_state(env, [ValType::i32()])
  // label index 5 is out of range (only 1 label at index 0)
  let result = Typecheck::typecheck(Instruction::br(LabelIdx::new(5)), state)
  tcneg_assert_err_contains(result, "invalid label index")
}

///|
test "Typecheck br with insufficient stack for label types" {
  let env = empty_env().with_labels([[ValType::i32(), ValType::i64()]])
  let state = tcneg_make_state(env, [])
  // label 0 expects [i32, i64] but stack is empty
  let result = Typecheck::typecheck(Instruction::br(LabelIdx::new(0)), state)
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck br_if with invalid label index" {
  let env = empty_env() // no labels
  let state = tcneg_make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(Instruction::br_if(LabelIdx::new(0)), state)
  tcneg_assert_err_contains(result, "invalid label index")
}

///|
test "Typecheck br_if stack underflow missing condition" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [])
  // br_if needs i32 condition on top
  let result = Typecheck::typecheck(Instruction::br_if(LabelIdx::new(0)), state)
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck br_if rejects non-i32 condition type" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [ValType::i64()])
  let result = Typecheck::typecheck(Instruction::br_if(LabelIdx::new(0)), state)
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck br_table with invalid default label" {
  let env = empty_env() // no labels
  let state = tcneg_make_state(env, [ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::br_table([], LabelIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "invalid default label index")
}

///|
test "Typecheck br_table with invalid table label" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [ValType::i32()])
  // default label 0 is valid, but table label 5 is invalid
  let result = Typecheck::typecheck(
    Instruction::br_table([LabelIdx::new(5)], LabelIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "invalid label index in br_table")
}

///|
test "Typecheck br_table with mismatched label types" {
  let env = empty_env().with_labels([[ValType::i32()], [ValType::i64()]])
  let state = tcneg_make_state(env, [ValType::i32(), ValType::i32()])
  // label 0 expects [i32], label 1 expects [i64] - mismatch
  let result = Typecheck::typecheck(
    Instruction::br_table([LabelIdx::new(1)], LabelIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(
    result, "br_table target labels have different argument types",
  )
}

///|
test "Typecheck br_table stack underflow for selector" {
  let env = empty_env().with_labels([[]])
  let state = tcneg_make_state(env, [])
  // needs i32 selector but stack is empty
  let result = Typecheck::typecheck(
    Instruction::br_table([], LabelIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck br_table stack underflow for branch arguments" {
  let env = empty_env().with_labels([[ValType::i32()]])
  let state = tcneg_make_state(env, [ValType::i32()])
  // selector exists, but label argument i32 is missing
  let result = Typecheck::typecheck(
    Instruction::br_table([], LabelIdx::new(0)),
    state,
  )
  tcneg_assert_err_contains(result, "stack underflow")
}

// =============================================================================
// EXPAND_BLOCKTYPE FAILURE NEGATIVE-PATH TESTS
// =============================================================================

///|
test "Typecheck block with invalid TypeIdx blocktype" {
  let env = empty_env() // no types defined
  let state = tcneg_make_state(env, [])
  let bt = BlockType::type_idx(TypeIdx::new(99))
  let result = Typecheck::typecheck(
    Instruction::block(bt, Expr::new([])),
    state,
  )
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck loop with invalid TypeIdx blocktype" {
  let env = empty_env() // no types defined
  let state = tcneg_make_state(env, [])
  let bt = BlockType::type_idx(TypeIdx::new(99))
  let result = Typecheck::typecheck(
    Instruction::loop_(bt, Expr::new([])),
    state,
  )
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck if with invalid TypeIdx blocktype" {
  let env = empty_env() // no types defined
  let state = tcneg_make_state(env, [ValType::i32()])
  let bt = BlockType::type_idx(TypeIdx::new(99))
  let result = Typecheck::typecheck(Instruction::if_(bt, [], None), state)
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck block with non-func CompType as blocktype" {
  // Type 0 is a struct, not a func type - expand_blocktype should fail
  let st = SubType::comp_type(CompType::struct_([]))
  let env = Env::{ ..empty_env(), global_types: [st] }
  let state = tcneg_make_state(env, [])
  let bt = BlockType::type_idx(TypeIdx::new(0))
  let result = Typecheck::typecheck(
    Instruction::block(bt, Expr::new([])),
    state,
  )
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck block with RecIdx blocktype not in rec_stack" {
  let env = empty_env() // no rec_stack
  let state = tcneg_make_state(env, [])
  let bt = BlockType::type_idx(TypeIdx::rec(0))
  let result = Typecheck::typecheck(
    Instruction::block(bt, Expr::new([])),
    state,
  )
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck if with non-function RecIdx blocktype in rec_stack" {
  let st = SubType::comp_type(CompType::struct_([]))
  let env = empty_env().with_rectype(RecType::new(st))
  let state = tcneg_make_state(env, [ValType::i32()])
  let bt = BlockType::type_idx(TypeIdx::rec(0))
  let result = Typecheck::typecheck(Instruction::if_(bt, [], None), state)
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

///|
test "Typecheck try_table with invalid TypeIdx blocktype" {
  let env = empty_env()
  let state = tcneg_make_state(env, [])
  let bt = BlockType::type_idx(TypeIdx::new(77))
  let result = Typecheck::typecheck(
    Instruction::try_table(bt, [], Expr::new([])),
    state,
  )
  tcneg_assert_err_contains(
    result, "blocktype type index is not a function type",
  )
}

// =============================================================================
// UNREACHABLE MERGE NORMALIZATION TESTS
// =============================================================================

///|
test "Typecheck unreachable pop1 returns bot (polymorphic stack)" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: false }
  // In unreachable code, pop1 should succeed and return BotValType
  let result = state.pop1()
  match result {
    Ok((_, v)) => assert_eq(v, ValType::bottom())
    Err(e) => fail("Expected Ok with BotValType, got Err: \{e}")
  }
}

///|
test "Typecheck unreachable pop_expect succeeds for any type" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: false }
  // In unreachable code, pop_expect should accept any type
  let result = state.pop_expect(ValType::i64())
  match result {
    Ok(_) => ()
    Err(e) => fail("Expected Ok in unreachable, got Err: \{e}")
  }
}

///|
test "Typecheck unreachable pop_types succeeds for any types" {
  let env = empty_env()
  let state : TcState = { env, stack: [], reachable: false }
  // In unreachable code, pop_types should accept any type list
  let result = state.pop_types([ValType::i32(), ValType::i64(), ValType::f32()])
  match result {
    Ok(_) => ()
    Err(e) => fail("Expected Ok in unreachable, got Err: \{e}")
  }
}

///|
test "Typecheck if with one unreachable branch merges to reachable" {
  // if: then branch is unreachable (via `unreachable`), else is reachable
  // Merged result should be reachable, using else branch stack
  let env = empty_env()
  let state = tcneg_make_state(env, [ValType::i32()])
  let bt = BlockType::val_type(ValType::i32())
  let result = Typecheck::typecheck(
    Instruction::if_(
      bt,
      [Instruction::unreachable_(), Instruction::i32_const(I32(42))],
      Some([Instruction::i32_const(I32(1))]),
    ),
    state,
  )
  match result {
    Ok(st) => {
      assert_true(st.reachable)
      assert_true(st.stack.contains(ValType::i32()))
    }
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "Typecheck if with both unreachable branches yields unreachable" {
  let env = empty_env()
  let state = tcneg_make_state(env, [ValType::i32()])
  let bt = BlockType::void_()
  let result = Typecheck::typecheck(
    Instruction::if_(
      bt,
      [Instruction::unreachable_()],
      Some([Instruction::unreachable_()]),
    ),
    state,
  )
  match result {
    Ok(st) => assert_true(not(st.reachable))
    Err(e) => fail("Expected Ok (both unreachable), got Err: \{e}")
  }
}

///|
test "Typecheck if branch body cannot pop values below branch label boundary" {
  let env = empty_env()
  let state = tcneg_make_state(env, [ValType::i64(), ValType::i32()])
  let result = Typecheck::typecheck(
    Instruction::if_(
      BlockType::void_(),
      [Instruction::nop()],
      Some([Instruction::drop()]),
    ),
    state,
  )
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck block with unreachable body propagates unreachable" {
  let env = empty_env()
  let state = tcneg_make_state(env, [])
  let bt = BlockType::val_type(ValType::i32())
  // block body is just `unreachable`, which should still succeed
  // because unreachable body doesn't need to produce results
  let result = Typecheck::typecheck(
    Instruction::block(bt, Expr::new([Instruction::unreachable_()])),
    state,
  )
  match result {
    Ok(_) => ()
    Err(e) => fail("Expected Ok for unreachable block body, got Err: \{e}")
  }
}

///|
test "Typecheck return with no return_type in env" {
  let env = empty_env() // return_type is None
  let state = tcneg_make_state(env, [])
  let result = Typecheck::typecheck(Instruction::return_(), state)
  tcneg_assert_err_contains(
    result, "return used with no function return type in context",
  )
}

///|
test "Typecheck return with insufficient stack for return type" {
  let env = empty_env().with_return_type(Some([ValType::i32(), ValType::i64()]))
  let state = tcneg_make_state(env, [])
  // return expects [i32, i64] but stack is empty
  let result = Typecheck::typecheck(Instruction::return_(), state)
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck if stack mismatch between branches" {
  let env = empty_env()
  let state = tcneg_make_state(env, [ValType::i32()])
  let bt = BlockType::val_type(ValType::i32())
  // then returns i32, else returns something different on the base stack
  let result = Typecheck::typecheck(
    Instruction::if_(
      bt,
      [Instruction::i32_const(I32(1))],
      Some([Instruction::i32_const(I32(2))]),
    ),
    state,
  )
  // Both branches produce i32, so this should actually succeed
  match result {
    Ok(_) => ()
    Err(e) => fail("Expected Ok, got Err: \{e}")
  }
}

///|
test "Typecheck if with missing condition on stack" {
  let env = empty_env()
  let state = tcneg_make_state(env, [])
  let bt = BlockType::void_()
  // if needs i32 condition on top but stack is empty
  let result = Typecheck::typecheck(Instruction::if_(bt, [], None), state)
  tcneg_assert_err_contains(result, "stack underflow")
}

///|
test "Typecheck block body type mismatch with blocktype results" {
  let env = empty_env()
  let state = tcneg_make_state(env, [])
  let bt = BlockType::val_type(ValType::i32())
  // block expects i32 result but body pushes i64
  let result = Typecheck::typecheck(
    Instruction::block(bt, Expr::new([Instruction::i64_const(I64(1L))])),
    state,
  )
  tcneg_assert_err_contains(result, "type mismatch")
}

///|
test "Typecheck block body does not consume outer stack without block params" {
  let env = empty_env().with_locals([ValType::i32()])
  let state = tcneg_make_state(env, [])
  let expr = Expr::new([
    Instruction::i32_const(I32(0)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([Instruction::local_tee(LocalIdx::new(0)), Instruction::drop()]),
    ),
  ])
  let result = Typecheck::typecheck(expr, state)
  tcneg_assert_err_contains(result, "stack underflow")
}
