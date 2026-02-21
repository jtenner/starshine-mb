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
  let env = Env::{ ..empty_env(), global_types: [tag_sig] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
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
  let env = Env::{ ..empty_env(), global_types: [tag_sig] }.push_tag(
    TagType::new(TypeIdx::new(0)),
  )
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
  let state = tcneg_make_state(empty_env(), [])
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
  let state = tcneg_make_state(empty_env(), [])
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
