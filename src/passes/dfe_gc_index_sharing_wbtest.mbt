///|
test "GC compaction shares immutable convergent type indices within one remap" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(3U), @lib.TypeIdx::new(3U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::ref_null(
                  @lib.HeapType::new(@lib.TypeIdx::new(1U)),
                ),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::new([
            @lib.LocalRun::new(
              1U,
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  true,
                  @lib.HeapType::new(@lib.TypeIdx::new(2U)),
                ),
              ),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::ref_null(
              @lib.HeapType::new(@lib.TypeIdx::new(2U)),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let before = @binary.encode_module(input).unwrap()
  assert_true(@validate.validate_module(input) is Ok(_))
  let after = dfe_canonicalize_duplicate_simple_type_indices(input)
  assert_true(@validate.validate_module(after) is Ok(_))
  let funcs = after.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(first_body)) = funcs[0]
  let @lib.Func(second_locals, @lib.Expr(second_body)) = funcs[1]
  let nested = match first_body[0] {
    @lib.Block(
      _,
      @lib.Expr(
        [
          @lib.RefNull(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))),
          ..,
        ]
      )
    ) => idx
    _ => fail("expected nested concrete ref")
  }
  let body = match second_body[0] {
    @lib.RefNull(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))) => idx
    _ => fail("expected second concrete ref")
  }
  let local_idx = match second_locals.runs()[0].val_type() {
    @lib.RefTypeValType(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))) =>
      idx
    _ => fail("expected nullable inexact local")
  }
  assert_eq(nested, @lib.TypeIdx::new(0U))
  assert_eq(body, nested)
  assert_eq(local_idx, nested)
  assert_true(physical_equal(nested, body))
  assert_true(physical_equal(nested, local_idx))
  // Each module rewrite owns a fresh cache; no retained/global interning table.
  let again = dfe_canonicalize_duplicate_simple_type_indices(input)
  let @lib.Func(_, @lib.Expr(again_body)) = again.code_sec.unwrap().0[0]
  let again_idx = match again_body[0] {
    @lib.Block(
      _,
      @lib.Expr(
        [
          @lib.RefNull(@lib.HeapTypeRefType(true, false, @lib.HeapType(idx))),
          ..,
        ]
      )
    ) => idx
    _ => fail("expected fresh nested concrete ref")
  }
  assert_eq(again_idx, nested)
  assert_false(physical_equal(again_idx, nested))
  assert_eq(
    @binary.encode_module(again).unwrap(),
    @binary.encode_module(after).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
test "type index sharing keeps final targets flags and bounded cache ownership" {
  let remap : Map[UInt, UInt] = Map([(0U, 0U), (1U, 0U), (2U, 0U), (3U, 2U)])
  let cache : Map[UInt, @lib.TypeIdx] = Map([])
  let index_cache = Some(cache)
  let first = dfe_try_rewrite_type_idx(
    @lib.TypeIdx::new(1U),
    remap,
    index_cache~,
  ).unwrap()
  for width in [1, 8, 32] {
    for _ in 0..<width {
      let next = dfe_try_rewrite_type_idx(
        @lib.TypeIdx::new(2U),
        remap,
        index_cache~,
      ).unwrap()
      assert_true(physical_equal(first, next))
    }
    assert_eq(cache.length(), 1)
  }
  // Cache keys are final direct-map targets; never apply the map twice.
  let second = dfe_try_rewrite_type_idx(
    @lib.TypeIdx::new(3U),
    remap,
    index_cache~,
  ).unwrap()
  assert_eq(second, @lib.TypeIdx::new(2U))
  assert_eq(cache.length(), 2)
  for nullable in [false, true] {
    for exact in [false, true] {
      let before_ref = @lib.RefType::new(
        nullable,
        @lib.HeapType::new(@lib.TypeIdx::new(2U)),
        exact~,
      )
      let next_ref = dfe_try_rewrite_ref_type(before_ref, remap, index_cache~).unwrap()
      match next_ref {
        @lib.HeapTypeRefType(next_nullable, next_exact, @lib.HeapType(idx)) => {
          assert_eq(next_nullable, nullable)
          assert_eq(next_exact, exact)
          assert_true(physical_equal(idx, first))
        }
        _ => fail("expected concrete rewritten ref")
      }
    }
  }
  // Intentionally unchanged identity, abstract and group-local forms do not
  // enter the optional rewrite/cache; inline DefType graphs remain uncached.
  let identity = @lib.TypeIdx::new(0U)
  let group_local = @lib.TypeIdx::rec(1U)
  assert_true(dfe_try_rewrite_type_idx(identity, remap, index_cache~) is None)
  assert_true(
    dfe_try_rewrite_type_idx(group_local, remap, index_cache~) is None,
  )
  assert_true(
    physical_equal(
      dfe_rewrite_type_idx(group_local, remap, index_cache~),
      group_local,
    ),
  )
  assert_true(
    dfe_try_rewrite_heap_type(
      @lib.HeapType::abs(@lib.AbsHeapType::any()),
      remap,
      index_cache~,
    )
    is None,
  )
  assert_eq(cache.length(), 2)
  let separate_cache : Map[UInt, @lib.TypeIdx] = Map([])
  let separate = dfe_try_rewrite_type_idx(
    @lib.TypeIdx::new(1U),
    remap,
    index_cache=Some(separate_cache),
  ).unwrap()
  assert_eq(separate, first)
  assert_false(physical_equal(separate, first))
  // The default uncached helper contract is retained for other callers.
  let uncached = dfe_try_rewrite_type_idx(@lib.TypeIdx::new(1U), remap).unwrap()
  assert_eq(uncached, first)
  assert_false(physical_equal(uncached, first))
}
