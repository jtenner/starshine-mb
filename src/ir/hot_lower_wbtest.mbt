///|
test "hot lower split payload tail fix accepts non-void tail if with mixed positive branch depths" {
  let bt = @lib.BlockType::val_type(@lib.ValType::i32())
  let carried_local = @lib.LocalIdx::new(0U)
  let sibling_local = @lib.LocalIdx::new(1U)
  let tail_local = @lib.LocalIdx::new(2U)
  let child_body : Array[@lib.Instruction] = [
    @lib.Instruction::if_(
      bt,
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(carried_local),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(sibling_local),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::block(
          bt,
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(child_body),
            ),
            @lib.Instruction::local_get(carried_local),
          ]),
        ),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(tail_local),
  ]

  let rewritten = match
    hot_lower_impl_try_fix_split_payload_wrapper_with_tail(bt, body) {
    Some(rewritten) => rewritten
    None => fail("expected split payload wrapper tail fix rewrite")
  }

  assert_eq(rewritten.length(), 2)
  assert_eq(rewritten[1], @lib.Instruction::local_get(tail_local))
  assert_true(rewritten != body)
}

///|
test "hot lower direct split payload tail fix accepts nested result head with mixed positive branch depths" {
  let bt = @lib.BlockType::val_type(@lib.ValType::i32())
  let carried_local = @lib.LocalIdx::new(0U)
  let sibling_local = @lib.LocalIdx::new(1U)
  let child_body : Array[@lib.Instruction] = [
    @lib.Instruction::if_(
      bt,
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(carried_local),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(sibling_local),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::block(
      bt,
      @lib.Expr::new([
        @lib.Instruction::block(
          bt,
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(child_body),
            ),
            @lib.Instruction::local_get(carried_local),
          ]),
        ),
        @lib.Instruction::local_set(sibling_local),
        @lib.Instruction::local_get(sibling_local),
      ]),
    ),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]

  let rewritten = match
    hot_lower_impl_try_fix_direct_split_payload_wrapper_with_tail(bt, body) {
    Some(rewritten) => rewritten
    None => fail("expected direct split payload wrapper tail fix rewrite")
  }

  assert_eq(rewritten.length(), 2)
  assert_eq(rewritten[1], @lib.Instruction::br(@lib.LabelIdx::new(0U)))
  assert_true(rewritten != body)
}

///|
test "hot lower voidifies split local.set wrapper pairs with unreachable prefixes" {
  let carried_local = @lib.LocalIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let first = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
            Some([@lib.Instruction::br(@lib.LabelIdx::new(1U))]),
          ),
          @lib.Instruction::unreachable_(),
        ]),
      ),
      @lib.Instruction::local_get(carried_local),
    ]),
  )
  let second = @lib.Instruction::local_set(target_local)

  let rewritten = match
    hot_lower_impl_try_voidify_split_local_set_wrapper_pair(first, second) {
    Some(rewritten) => rewritten
    None => fail("expected split local.set wrapper pair rewrite")
  }

  match rewritten {
    @lib.Instruction::Block(@lib.VoidBlockType, @lib.Expr(body)) => {
      assert_eq(body.length(), 2)
      assert_eq(body[1], @lib.Instruction::local_set(target_local))
    }
    other => fail("expected voidified wrapper block, got \{other}")
  }
}

///|
test "hot lower unpacks parent-exit payload wrappers with trailing roots" {
  let bt = @lib.BlockType::val_type(@lib.ValType::i32())
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::block(
      bt,
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
              Some([
                @lib.Instruction::i32_const(@lib.I32(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(7)),
      ]),
    ),
    @lib.Instruction::br(@lib.LabelIdx::new(0U)),
  ]

  let rewritten = match
    hot_lower_impl_try_unpack_parent_exit_payload_wrapper_with_tail(bt, body) {
    Some(rewritten) => rewritten
    None => fail("expected parent-exit payload wrapper with tail rewrite")
  }

  assert_eq(rewritten.length(), 5)
  assert_eq(rewritten[4], @lib.Instruction::br(@lib.LabelIdx::new(0U)))
}

///|
test "hot lower fixes voidified split local.set wrappers with mixed positive tail depths" {
  let carried_local = @lib.LocalIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let child_body : Array[@lib.Instruction] = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(carried_local),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(target_local),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let instr = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new(child_body),
      ),
      @lib.Instruction::local_get(carried_local),
      @lib.Instruction::local_set(target_local),
    ]),
  )

  let rewritten = match
    hot_lower_impl_try_fix_voidified_split_local_set_wrapper(instr) {
    Some(rewritten) => rewritten
    None => fail("expected voidified split local.set wrapper depth rewrite")
  }

  assert_true(rewritten != instr)
}

///|
test "hot lower recursively fixes mixed tail depths after voidifying a split local.set wrapper pair" {
  let bt = @lib.BlockType::val_type(@lib.ValType::i32())
  let carried_local = @lib.LocalIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let child_body : Array[@lib.Instruction] = [
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(carried_local),
        @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(target_local),
        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
      ]),
    ),
    @lib.Instruction::unreachable_(),
  ]
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::block(
      bt,
      @lib.Expr::new([
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new(child_body),
        ),
        @lib.Instruction::local_get(carried_local),
      ]),
    ),
    @lib.Instruction::local_set(target_local),
  ]

  let fixed = hot_lower_impl_fix_split_payload_wrappers_in_body(body)
  assert_eq(fixed.length(), 1)
  match fixed[0] {
    @lib.Instruction::Block(
      @lib.VoidBlockType,
      @lib.Expr(
        [
          @lib.Instruction::Block(
            @lib.VoidBlockType,
            @lib.Expr(inner_child_body)
          ),
          @lib.Instruction::LocalGet(_),
          @lib.Instruction::LocalSet(_),
        ]
      )
    ) =>
      match inner_child_body[0] {
        @lib.Instruction::If(_, _, Some(else_)) =>
          match else_[2] {
            @lib.Instruction::Br(li) => assert_eq(li, @lib.LabelIdx::new(2U))
            other => fail("expected shifted else terminal br, got \{other}")
          }
        other => fail("expected rewritten inner tail if, got \{other}")
      }
    other =>
      fail("expected recursively rewritten voidified pair block, got \{other}")
  }
}
