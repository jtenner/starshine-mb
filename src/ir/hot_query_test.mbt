///|
test "query helpers classify representative node families and expose node result types" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let local_get = hot_build_local_get(func, 0)
  let global = hot_build_global_get(func, 2, @lib.ValType::i64())
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let load = hot_build_load(func, @lib.ValType::i32(), memarg, local_get)
  let table = hot_build_table_get(func, 1, @lib.ValType::externref(), local_get)
  let numeric = hot_build_binary(
    func,
    @lib.ValType::i32(),
    local_get,
    local_get,
  )
  let tuple = hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [local_get, hot_build_const_i64(func, @lib.I64(2L))],
  )
  let ref_null = hot_build_ref_null(
    func,
    @lib.RefType::abs(@lib.AbsHeapType::extern_()),
  )
  let heap = hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::array_len(),
    [ref_null],
  )
  let throw_ref = hot_build_throw_ref(func, ref_null)
  let call = hot_build_call(func, 5, [@lib.ValType::i32()], [local_get])
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])

  assert_true(hot_node_kind_is_local(func, local_get))
  assert_true(hot_node_kind_is_global(func, global))
  assert_true(hot_node_kind_is_memory(func, load))
  assert_true(hot_node_kind_is_table(func, table))
  assert_true(hot_node_kind_is_numeric(func, numeric))
  assert_true(hot_node_kind_is_tuple(func, tuple))
  assert_true(hot_node_kind_is_heap(func, heap))
  assert_true(hot_node_kind_is_exception(func, throw_ref))
  assert_true(hot_node_kind_is_call(func, call))
  assert_true(hot_node_kind_is_control(func, block))

  assert_eq(
    hot_node_type(func, local_get),
    hot_type_intern_value(func, @lib.ValType::i32()),
  )
  assert_eq(hot_node_result_arity(func, local_get), 1)
  assert_eq(hot_node_result_arity(func, tuple), 2)
  assert_eq(
    hot_node_exact_instr(func, heap),
    Some(@lib.Instruction::array_len()),
  )
}

///|
test "branch queries expose single-target and branch-table metadata" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])
  let target = hot_control_node_label(func, block)
  let br_if = hot_build_br_if(func, target, condition)
  let br_table = hot_build_br_table(func, [target], target, condition)
  let delegate = hot_build_delegate(func, target)

  assert_eq(hot_branch_target(func, br_if), Some(target))
  assert_eq(hot_branch_target(func, br_table), Some(target))
  assert_eq(hot_branch_target(func, delegate), Some(target))
  assert_eq(hot_branch_table_targets_for_node(func, br_table), [target])
  assert_eq(hot_branch_table_targets_for_node(func, br_if).length(), 0)
}

///|
test "root child local and tombstone queries stay read only" {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
      @lib.ValType::externref(),
    ]),
  )
  let deleted = hot_build_nop(func)
  let first = hot_build_const_i32(func, @lib.I32(7))
  let second = hot_build_const_i32(func, @lib.I32(9))
  let block = hot_build_block(func, @lib.BlockType::void_(), [first, second])
  hot_root_append(func, block)
  hot_delete_node(func, deleted)

  let rev0 = hot_revision_current(func)
  assert_eq(hot_root_span(func), [block])
  assert_eq(hot_child_span(func, block), [first, second])
  assert_eq(hot_local_param_count(func), 1)
  assert_eq(hot_local_body_count(func), 2)
  assert_true(hot_local_is_param(func, 0))
  assert_false(hot_local_is_param(func, 1))
  assert_true(hot_node_is_deleted(func, deleted))
  assert_false(hot_node_is_deleted(func, block))
  assert_eq(hot_revision_current(func), rev0)
}

///|
test "simple value queries compare semantic leaf identity" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let const7a = hot_build_const_i32(func, @lib.I32(7))
  let const7b = hot_build_const_i32(func, @lib.I32(7))
  let const9 = hot_build_const_i32(func, @lib.I32(9))
  let local0a = hot_build_local_get(func, 0)
  let local0b = hot_build_local_get(func, 0)
  let drop_local0 = hot_build_drop(func, local0a)

  assert_true(hot_nodes_match_simple_value(func, const7a, const7b))
  assert_false(hot_nodes_match_simple_value(func, const7a, const9))
  assert_true(hot_nodes_match_simple_value(func, local0a, local0b))
  assert_false(hot_nodes_match_simple_value(func, const7a, local0a))
  assert_false(hot_nodes_match_simple_value(func, local0a, drop_local0))

  match hot_simple_value_key(func, const7a) {
    Some(HotSimpleValueKey::ConstValue(HotConstPayload::I32Const(value))) =>
      assert_eq(value, @lib.I32(7))
    other => fail("expected i32 const simple value key, got \{other}")
  }
  match hot_simple_value_key(func, local0a) {
    Some(HotSimpleValueKey::LocalGetValue(local_id)) => assert_eq(local_id, 0)
    other => fail("expected local.get simple value key, got \{other}")
  }
  assert_eq(hot_simple_value_key(func, drop_local0), None)
}

///|
test "single-root wrapper queries peel canonical block wrappers" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([
          @lib.Instruction::block(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
    body_result_type=@lib.BlockType::val_type(@lib.ValType::i32()),
  )
  let root_ref = HotRegionRef::root()
  let root_block = hot_region_single_live_block_root(func, root_ref).unwrap()
  let outer_body = hot_region_single_live_block_body(func, root_ref).unwrap()
  let inner_block = hot_region_single_live_block_root(func, outer_body).unwrap()
  let inner_body = hot_region_single_live_block_body(func, outer_body).unwrap()
  let payload = hot_region_single_live_root(func, inner_body).unwrap()

  assert_eq(hot_region_single_live_root(func, root_ref), Some(root_block))
  assert_eq(hot_region_single_live_block_root(func, root_ref), Some(root_block))
  assert_eq(hot_region_single_live_block_body(func, root_ref), Some(outer_body))
  assert_eq(
    hot_region_single_live_block_body_or_self(func, root_ref),
    outer_body,
  )
  assert_eq(
    hot_region_single_live_block_root(func, outer_body),
    Some(inner_block),
  )
  assert_eq(
    hot_region_single_live_block_body_or_self(func, outer_body),
    inner_body,
  )
  assert_eq(hot_region_single_live_root(func, inner_body), Some(payload))
  assert_eq(
    hot_region_single_live_block_body_or_self(func, inner_body),
    inner_body,
  )
  match hot_node_get(func, payload).op {
    HotOp::Const => ()
    _ => fail("expected peeled inner payload to be a const")
  }
}

///|
test "holder and single-if queries expose canonical lifted control entry points" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
            Some([@lib.Instruction::nop()]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let root_ref = HotRegionRef::root()
  let block_id = hot_region_single_live_block_root(func, root_ref).unwrap()
  let body_ref = hot_region_body_ref(func, block_id)
  let if_id = hot_region_single_live_if_root(func, body_ref).unwrap()
  let then_ref = hot_region_then_ref(func, if_id)
  let else_ref = hot_region_else_ref(func, if_id).unwrap()
  let target = hot_control_node_label(func, block_id)
  let then_holder = then_ref.holder
  let else_holder = else_ref.holder

  assert_eq(hot_region_holder_block_root(func, body_ref), Some(block_id))
  assert_eq(hot_region_holder_block_label(func, body_ref), Some(target))
  assert_eq(hot_region_single_live_if_root(func, body_ref), Some(if_id))
  assert_eq(hot_region_holder_block_root(func, then_ref), Some(then_holder))
  assert_eq(
    hot_region_holder_block_label(func, then_ref),
    Some(hot_control_node_label(func, then_holder)),
  )
  assert_eq(hot_region_holder_block_root(func, else_ref), Some(else_holder))
  assert_eq(
    hot_region_holder_block_label(func, else_ref),
    Some(hot_control_node_label(func, else_holder)),
  )
}

///|
test "plain-branch arm queries expose single plain branch roots canonically" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
            Some([
              @lib.Instruction::i32_const(@lib.I32(2)),
              @lib.Instruction::drop(),
            ]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let block_id = hot_region_single_live_block_root(func, HotRegionRef::root()).unwrap()
  let if_id = hot_region_single_live_if_root(
    func,
    hot_region_body_ref(func, block_id),
  ).unwrap()
  let then_ref = hot_region_then_ref(func, if_id)
  let else_ref = hot_region_else_ref(func, if_id).unwrap()
  let then_root = hot_region_get(func, then_ref, 0)

  assert_eq(
    hot_region_single_plain_br_target(func, then_ref),
    hot_branch_target(func, then_root),
  )
  assert_eq(hot_region_single_plain_br_root(func, then_ref), Some(then_root))
  assert_eq(hot_region_single_plain_br_root(func, else_ref), None)
  assert_eq(hot_region_single_plain_br_target(func, else_ref), None)
}

///|
test "single-exit-arm queries expose return and plain branch arms canonically" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::return_()],
            Some([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
          ),
        ]),
      ),
    ]),
    HotLocals::new(),
  )
  let block_id = hot_region_single_live_block_root(func, HotRegionRef::root()).unwrap()
  let if_id = hot_region_single_live_if_root(
    func,
    hot_region_body_ref(func, block_id),
  ).unwrap()
  let then_ref = hot_region_then_ref(func, if_id)
  let else_ref = hot_region_else_ref(func, if_id).unwrap()
  let then_root = hot_region_get(func, then_ref, 0)
  let else_root = hot_region_get(func, else_ref, 0)

  assert_eq(hot_region_single_exit_root(func, then_ref), Some(then_root))
  assert_eq(hot_region_single_exit_root(func, else_ref), Some(else_root))
}

///|
test "trailing plain-branch split queries expose prefix roots and tail target canonically" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let prefix0 = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(0)))
  let prefix1 = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(1)))
  let tail = hot_build_br(func, 7)
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    prefix0, prefix1, tail,
  ])
  let body_ref = hot_region_body_ref(func, block)
  let mixed = hot_build_block(func, @lib.BlockType::void_(), [
    prefix0,
    hot_build_br(func, 7, values=[hot_build_const_i32(func, @lib.I32(2))]),
  ])

  match hot_region_split_trailing_plain_br_root(func, body_ref) {
    Some((prefix, split_tail)) => {
      assert_eq(prefix, [prefix0, prefix1])
      assert_eq(split_tail, tail)
    }
    None => fail("expected trailing plain br split for region roots")
  }
  match hot_region_split_trailing_plain_br_target(func, body_ref) {
    Some((prefix, target)) => {
      assert_eq(prefix, [prefix0, prefix1])
      assert_eq(target, 7)
    }
    None => fail("expected trailing plain br target split for region roots")
  }
  assert_eq(
    hot_region_split_trailing_plain_br_root(
      func,
      hot_region_body_ref(func, mixed),
    ),
    None,
  )
  assert_eq(
    hot_region_split_trailing_plain_br_target(
      func,
      hot_region_body_ref(func, mixed),
    ),
    None,
  )
}

///|
test "payload split queries expose trailing result roots canonically" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let prefix = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(1)))
  let payload_a = hot_build_const_i32(func, @lib.I32(7))
  let payload_b = hot_build_local_get(func, 0)
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    prefix, payload_a, payload_b,
  ])
  let body_ref = hot_region_body_ref(func, block)

  let roots = [prefix, payload_a, payload_b]
  match hot_split_trailing_payload_roots(func, roots, 2) {
    Some((split_prefix, split_payload)) => {
      assert_eq(split_prefix, [prefix])
      assert_eq(split_payload, [payload_a, payload_b])
    }
    None => fail("expected payload split for direct roots")
  }

  match hot_region_split_trailing_payload_roots(func, body_ref, 2) {
    Some((split_prefix, split_payload)) => {
      assert_eq(split_prefix, [prefix])
      assert_eq(split_payload, [payload_a, payload_b])
    }
    None => fail("expected payload split for region roots")
  }

  assert_eq(hot_split_trailing_payload_roots(func, roots, 3), None)
}

///|
test "repeated-shape queries expose repeated live children and region roots canonically" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let cond = hot_build_local_get(func, 0)
  let payload_if = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    cond,
    [hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([hot_build_const_i32(func, @lib.I32(2))]),
  )
  let repeated_br = hot_build_br(func, 7, values=[payload_if, payload_if])
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    repeated_br, repeated_br,
  ])
  let body_ref = hot_region_body_ref(func, block)
  let repeated_if_block = hot_build_block(func, @lib.BlockType::void_(), [
    payload_if, payload_if,
  ])
  let repeated_inner_block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_nop(func),
  ])
  let repeated_blocks = hot_build_block(func, @lib.BlockType::void_(), [
    repeated_inner_block, repeated_inner_block,
  ])
  let mixed_br = hot_build_br(func, 7, values=[
    payload_if,
    hot_build_const_i32(func, @lib.I32(3)),
  ])
  let mixed_block = hot_build_block(func, @lib.BlockType::void_(), [
    repeated_br, mixed_br,
  ])

  assert_eq(hot_node_repeated_live_child(func, repeated_br), Some(payload_if))
  assert_eq(hot_region_repeated_live_root(func, body_ref), Some(repeated_br))
  assert_eq(
    hot_region_repeated_live_if_root(
      func,
      hot_region_body_ref(func, repeated_if_block),
    ),
    Some(payload_if),
  )
  assert_eq(
    hot_region_repeated_live_block_root(
      func,
      hot_region_body_ref(func, repeated_blocks),
    ),
    Some(repeated_inner_block),
  )
  assert_eq(
    hot_region_repeated_live_block_body(
      func,
      hot_region_body_ref(func, repeated_blocks),
    ),
    Some(hot_region_body_ref(func, repeated_inner_block)),
  )
  assert_eq(
    hot_region_repeated_live_block_body_or_self(
      func,
      hot_region_body_ref(func, repeated_blocks),
    ),
    hot_region_body_ref(func, repeated_inner_block),
  )
  assert_eq(
    hot_region_repeated_live_block_body_or_self(
      func,
      hot_region_body_ref(func, mixed_block),
    ),
    hot_region_body_ref(func, mixed_block),
  )
  assert_eq(hot_node_repeated_live_child(func, mixed_br), None)
  assert_eq(
    hot_region_repeated_live_root(func, hot_region_body_ref(func, mixed_block)),
    None,
  )
  assert_eq(
    hot_region_repeated_live_if_root(
      func,
      hot_region_body_ref(func, mixed_block),
    ),
    None,
  )
}
