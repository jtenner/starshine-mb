///|
test "types constructors and accessors keep heap reference shape" {
  let typed_heap = HeapType::new(TypeIdx::new(7))
  let ref_type = RefType::new(false, typed_heap)
  assert_true(ref_type.is_non_nullable())
  assert_eq(ref_type.get_heap_type(), typed_heap)

  let nullable_ref = ref_type.make_nullable()
  assert_true(nullable_ref.is_nullable())
  match nullable_ref {
    HeapTypeRefType(nullable, HeapType(TypeIdx(i))) => {
      assert_true(nullable)
      assert_eq(i, 7U)
    }
    _ => fail("expected nullable ref over concrete TypeIdx")
  }

  let comp = CompType::func([ValType::i32()], [ValType::externref()])
  let sub = SubType::new(true, [TypeIdx::new(1), TypeIdx::rec(0)], comp)
  assert_eq(sub.super_types().length(), 2)
  assert_eq(sub.get_comptype(), comp)
}

///|
test "rectype get_subtype handles in-range and out-of-range indexes" {
  let first = SubType::comp_type(CompType::func([], []))
  let second = SubType::comp_type(CompType::func([ValType::i64()], []))
  let group = RecType::group([first, second])

  assert_eq(group.get_subtype(0), Some(first))
  assert_eq(group.get_subtype(1), Some(second))
  assert_eq(group.get_subtype(2), None)
}

///|
test "Locals from_types compresses into canonical runs" {
  let locals = Locals::from_types([
    ValType::i32(),
    ValType::i32(),
    ValType::funcref(),
    ValType::funcref(),
    ValType::i64(),
  ])
  let runs = locals.runs()
  assert_eq(runs.length(), 3)
  assert_eq(runs[0], LocalRun::new(2U, ValType::i32()))
  assert_eq(runs[1], LocalRun::new(2U, ValType::funcref()))
  assert_eq(runs[2], LocalRun::new(1U, ValType::i64()))
}

///|
test "FunctionLocals normalizes params and body locals" {
  let locals = FunctionLocals::new(
    [ValType::i32(), ValType::i64()],
    Locals::from_types([ValType::funcref()]),
  )
  assert_eq(locals.param_count(), 2)
  assert_eq(locals.params(), [ValType::i32(), ValType::i64()])
  assert_eq(locals.body_locals(), Locals::from_types([ValType::funcref()]))
  assert_eq(
    locals.all_locals(),
    Locals::from_types([ValType::i32(), ValType::i64(), ValType::funcref()]),
  )
}

///|
test "FunctionLocals local index lookup uses unified local space" {
  let locals = FunctionLocals::new(
    [ValType::i32()],
    Locals::from_types([ValType::i64(), ValType::externref()]),
  )
  assert_eq(locals.local_type(LocalIdx::new(0)), Some(ValType::i32()))
  assert_eq(locals.local_type(LocalIdx::new(1)), Some(ValType::i64()))
  assert_eq(locals.local_type(LocalIdx::new(2)), Some(ValType::externref()))
  assert_eq(locals.local_type(LocalIdx::new(3)), None)
}

///|
test "FunctionLocals pass helper adopts declared params when typed params are missing" {
  let locals = match
    FunctionLocals::from_typed_func_for_pass(
      [ValType::i32()],
      [],
      Locals::from_types([ValType::i64()]),
    ) {
    Ok(v) => v
    Err(e) => fail("unexpected locals resolution error: \{e}")
  }
  assert_eq(locals.params(), [ValType::i32()])
  assert_eq(
    locals.all_locals(),
    Locals::from_types([ValType::i32(), ValType::i64()]),
  )
}

///|
test "TExpr.to_expr lowers nested if with explicit operand order" {
  let texpr = TExpr::new([
    TInstr::if_(
      BlockType::void_(),
      TInstr::local_get(LocalIdx::new(0)),
      TExpr::new([TInstr::i32_const(I32(1))]),
      Some(TExpr::new([TInstr::i32_const(I32(0))])),
    ),
  ])
  let Expr(instrs) = texpr.to_expr()
  assert_eq(instrs.length(), 2)

  match instrs[0] {
    LocalGet(LocalIdx(i)) => assert_eq(i, 0U)
    _ => fail("expected condition local.get before if")
  }
  match instrs[1] {
    If(VoidBlockType, [I32Const(I32(then_v))], Some([I32Const(I32(else_v))])) => {
      assert_eq(then_v, 1)
      assert_eq(else_v, 0)
    }
    _ => fail("expected lowered if instruction with both branches")
  }
}

///|
test "limits helpers report address width and minimum address domain" {
  let lim32 = Limits::i32(1U, Some(8U))
  let lim64_a = Limits::i64(2UL, Some(16UL))
  let lim64_b = Limits::i64(3UL, None)

  assert_eq(lim32.mem_addr_bits(), 32)
  assert_eq(lim64_a.mem_addr_bits(), 64)

  assert_eq(min_addr(lim32, lim64_a), lim32)
  assert_eq(min_addr(lim64_a, lim32), lim32)
  assert_eq(min_addr(lim64_a, lim64_b), lim64_a)
}

///|
test "has_default handles numeric vector and ref nullability cases" {
  assert_true(has_default(ValType::i64()))
  assert_true(has_default(ValType::v128()))
  assert_true(has_default(ValType::bottom()))
  assert_true(has_default(ValType::ref_null(HeapType::new(TypeIdx::new(0)))))
  assert_false(
    has_default(
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
    ),
  )
}

///|
test "constructor shorthands map to expected variants" {
  assert_eq(TypeIdx::rec(3U), TypeIdx::rec(3U))
  assert_eq(
    HeapType::abs(AbsHeapType::extern_()),
    AbsHeapTypeHeapType(ExternAbsHeapType),
  )
  assert_eq(
    RefType::abs(AbsHeapType::no_func()),
    AbsHeapTypeRefType(NoFuncAbsHeapType),
  )
  assert_eq(Mut::const_(), Const)
  assert_eq(Mut::var_(), Var)
  assert_eq(
    StorageType::pack_type(PackType::i8()),
    PackTypeStorageType(I8PackType),
  )
}

///|
test "tinstr size caches subtree instruction counts" {
  let add = TInstr::binary(
    BinaryOp::i32_add(),
    TInstr::i32_const(I32(1)),
    TInstr::i32_const(I32(2)),
  )
  assert_eq(add.size, 3)

  let blk = TInstr::block(
    BlockType::void_(),
    TExpr::new([TInstr::nop(), TInstr::drop(add)]),
  )
  assert_eq(blk.size, 6)
}

///|
test "tinstr size accounts for if condition and both branches" {
  let cond = TInstr::local_get(LocalIdx::new(0))
  let then_body = TExpr::new([TInstr::i32_const(I32(1))])
  let else_body = TExpr::new([TInstr::i32_const(I32(0))])
  let if_instr = TInstr::if_(
    BlockType::val_type(ValType::i32()),
    cond,
    then_body,
    Some(else_body),
  )
  // if + cond + then const + else const
  assert_eq(if_instr.size, 4)
}
