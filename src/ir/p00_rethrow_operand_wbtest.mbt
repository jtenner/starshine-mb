///|
test "P00 synthetic catch preserves a rethrow in a local-set block operand" {
  let hot = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let rethrow = hot_build_node(hot, HotOp::Rethrow, hot_type_void(hot), imm0=0)
  let value = hot_build_block(
    hot,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [rethrow],
  )
  let set = hot_build_local_set(hot, 0, value)
  let try_id = hot_build_try(
    hot,
    @lib.BlockType::void_(),
    [hot_build_throw(hot, @lib.TagIdx::new(0U), [])],
    catch_body=Some([set]),
  )
  hot_root_append(hot, try_id)

  assert_eq(
    hot_lower_impl_catch_rethrow_count(
      hot,
      hot_region_catch_ref(hot, try_id).unwrap(),
      0,
    ),
    1,
  )
  let lowered = hot_lower_func(hot)
  let @lib.Func(locals, @lib.Expr(body)) = lowered
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::ref_null_exn()]),
  )
  assert_true(
    body
    is [
      @lib.Block(
        _,
        @lib.Expr(
          [
            @lib.Block(
              _,
              @lib.Expr(
                [@lib.TryTable(_, [@lib.CatchAllRef(@lib.LabelIdx(0U))], _), ..]
              )
            ),
            @lib.LocalSet(@lib.LocalIdx(1U)),
            ..,
          ]
        )
      ),
    ],
  )
  let module_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(0U))]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
  @validate.validate_module(module_).unwrap()
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(module_).unwrap()).unwrap(),
  ).unwrap()
}

///|
test "P00 catch operand rethrow visits preserve the nested catch ordinal" {
  let hot = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let current = hot_build_node(hot, HotOp::Rethrow, hot_type_void(hot), imm0=0)
  let outer = hot_build_node(hot, HotOp::Rethrow, hot_type_void(hot), imm0=1)
  let shared = hot_build_block(
    hot,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [current],
  )
  let outer_value = hot_build_block(
    hot,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [outer],
  )
  let inner_try = hot_build_try(
    hot,
    @lib.BlockType::void_(),
    [hot_build_throw(hot, @lib.TagIdx::new(1U), [])],
    catch_body=Some([
      hot_build_local_set(hot, 0, shared),
      hot_build_local_set(hot, 0, outer_value),
    ]),
  )
  let outer_try = hot_build_try(
    hot,
    @lib.BlockType::void_(),
    [hot_build_throw(hot, @lib.TagIdx::new(0U), [])],
    catch_body=Some([hot_build_local_set(hot, 0, shared), inner_try]),
  )
  // The shared depth-zero rethrow belongs to the outer catch only at its
  // direct use. The depth-one rethrow in the inner catch also targets it.
  assert_eq(
    hot_lower_impl_catch_rethrow_count(
      hot,
      hot_region_catch_ref(hot, outer_try).unwrap(),
      0,
    ),
    2,
  )
}

///|
test "P00 catch operand rethrow counts shared dependencies once per scope" {
  let hot = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let rethrow = hot_build_node(hot, HotOp::Rethrow, hot_type_void(hot), imm0=0)
  let mut value = hot_build_block(
    hot,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [rethrow],
  )
  for _ in 0..<12 {
    value = hot_build_binary(hot, @lib.ValType::i32(), value, value)
  }
  let try_id = hot_build_try(
    hot,
    @lib.BlockType::void_(),
    [hot_build_throw(hot, @lib.TagIdx::new(0U), [])],
    catch_body=Some([hot_build_local_set(hot, 0, value)]),
  )
  assert_eq(
    hot_lower_impl_catch_rethrow_count(
      hot,
      hot_region_catch_ref(hot, try_id).unwrap(),
      0,
    ),
    1,
  )
}
