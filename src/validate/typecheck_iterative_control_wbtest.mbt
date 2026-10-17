///|
fn tci_test_expr(depth : Int32, kind : Int32, invalid~ : Bool = false) -> Expr {
  let mut body = if invalid {
    [Instruction::i32_add()]
  } else {
    [Instruction::i32_const(I32(7))]
  }
  for _ in 0..<depth {
    body = match kind {
      0 =>
        [
          Instruction::block(
            BlockType::val_type(ValType::i32()),
            Expr::new(body),
          ),
        ]
      1 =>
        [
          Instruction::loop_(
            BlockType::val_type(ValType::i32()),
            Expr::new(body),
          ),
        ]
      _ =>
        [
          Instruction::i32_const(I32(1)),
          Instruction::if_(
            BlockType::val_type(ValType::i32()),
            body,
            Some([Instruction::i32_const(I32(9))]),
          ),
        ]
    }
  }
  Expr::new(body)
}

///|
#skip("dedicated artifact-depth validator qualification")
test "iterative control validation reaches 567 nested block loop and if regions" {
  for kind in 0..<3 {
    let result = Typecheck::typecheck(
      tci_test_expr(567, kind),
      tc_state_new(empty_env(), [], true, NoTcEscape),
    ).unwrap()
    assert_eq(result.stack, [ValType::i32()])
    assert_true(result.reachable)
  }
}

///|
#skip("dedicated deep invalid diagnostic qualification")
test "iterative control validation rejects an invalid 567-depth expression" {
  assert_true(
    Typecheck::typecheck(
      tci_test_expr(567, 0, invalid=true),
      tc_state_new(empty_env(), [], true, NoTcEscape),
    )
    is Err(_),
  )
}

///|
fn tci_test_same_state(left : TcState, right : TcState) -> Unit raise {
  assert_eq(left.stack, right.stack)
  assert_eq(left.reachable, right.reachable)
  assert_eq(left.polymorphic, right.polymorphic)
  assert_eq(left.escape, right.escape)
  assert_eq(left.reachable_escape_depths, right.reachable_escape_depths)
  assert_eq(left.initialized_locals, right.initialized_locals)
}

///|
test "iterative control agrees with existing shallow entry and finish paths" {
  for kind in 0..<3 {
    for depth in 0..<12 {
      let expr = tci_test_expr(depth, kind)
      let iterative = Typecheck::typecheck(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
      ).unwrap()
      let reference = typecheck_expr_recursive_reference(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
        true,
      ).unwrap()
      tci_test_same_state(iterative, reference)
      let invalid = tci_test_expr(depth, kind, invalid=true)
      match
        (
          Typecheck::typecheck(
            invalid,
            tc_state_new(empty_env(), [], true, NoTcEscape),
          ),
          typecheck_expr_recursive_reference(
            invalid,
            tc_state_new(empty_env(), [], true, NoTcEscape),
            true,
          ),
        ) {
        (Err(error), Err(old)) => assert_eq(error, old)
        _ => fail("expected invalid expression")
      }
    }
  }
}

///|
test "iterative if checks else instructions before normalizing then stack" {
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::if_(
      BlockType::val_type(ValType::i32()),
      [],
      Some([Instruction::local_get(LocalIdx::new(99U))]),
    ),
  ])
  let result = Typecheck::typecheck(
    expr,
    tc_state_new(empty_env(), [], true, NoTcEscape),
  )
  let reference = typecheck_expr_recursive_reference(
    expr,
    tc_state_new(empty_env(), [], true, NoTcEscape),
    true,
  )
  match (result, reference) {
    (Err(error), Err(old)) => {
      assert_eq(error, old)
      assert_true(error.contains("invalid local index"))
    }
    _ => fail("expected else instruction failure")
  }
}

///|
test "iterative expression keeps parent initialization owner across child scopes" {
  let env = empty_env().with_locals(Locals::single(4U, ValType::i32()))
  let entry = tc_state_new(env, [], true, NoTcEscape)
  entry.initialized_locals.fill(false)
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::local_set(LocalIdx::new(0U)),
    Instruction::block(
      BlockType::void_(),
      Expr::new([
        Instruction::i32_const(I32(2)),
        Instruction::local_set(LocalIdx::new(1U)),
      ]),
    ),
    Instruction::i32_const(I32(3)),
    Instruction::local_set(LocalIdx::new(2U)),
  ])
  let result = Typecheck::typecheck(expr, entry).unwrap()
  assert_eq(result.initialized_locals, [true, false, true, false])
  assert_eq(entry.initialized_locals, [false, false, false, false])
  assert_false(
    physical_equal(result.initialized_locals, entry.initialized_locals),
  )
}

///|
test "iterative if else initialization starts from the saved entry mask" {
  let env = empty_env().with_locals(Locals::single(1U, ValType::i32()))
  let entry = tc_state_new(env, [], true, NoTcEscape)
  entry.initialized_locals.fill(false)
  let expr = Expr::new([
    Instruction::i32_const(I32(1)),
    Instruction::if_(
      BlockType::void_(),
      [
        Instruction::i32_const(I32(2)),
        Instruction::local_set(LocalIdx::new(0U)),
      ],
      Some([Instruction::local_get(LocalIdx::new(0U)), Instruction::drop()]),
    ),
  ])
  assert_true(Typecheck::typecheck(expr, entry) is Err(_))
  assert_false(entry.initialized_locals[0])
}

///|
test "iterative controls retain branch and unreachable joins" {
  let expressions = [
    Expr::new([
      Instruction::block(
        BlockType::val_type(ValType::i32()),
        Expr::new([
          Instruction::i32_const(I32(1)),
          Instruction::br(LabelIdx::new(0U)),
        ]),
      ),
    ]),
    Expr::new([
      Instruction::loop_(
        BlockType::void_(),
        Expr::new([Instruction::br(LabelIdx::new(0U))]),
      ),
    ]),
    Expr::new([
      Instruction::i32_const(I32(1)),
      Instruction::if_(
        BlockType::void_(),
        [Instruction::unreachable_()],
        Some([Instruction::unreachable_()]),
      ),
    ]),
    Expr::new([
      Instruction::block(
        BlockType::void_(),
        Expr::new([
          Instruction::block(
            BlockType::void_(),
            Expr::new([Instruction::br(LabelIdx::new(1U))]),
          ),
        ]),
      ),
    ]),
  ]
  for expr in expressions {
    tci_test_same_state(
      Typecheck::typecheck(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
      ).unwrap(),
      typecheck_expr_recursive_reference(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
        true,
      ).unwrap(),
    )
  }
}

///|
test "iterative probe removes only root diagnostic context" {
  let expr = tci_test_expr(3, 0, invalid=true)
  let actual = typecheck_expr_for_probe(
    expr,
    tc_state_new(empty_env(), [], true, NoTcEscape),
  )
  let reference = typecheck_expr_recursive_reference(
    expr,
    tc_state_new(empty_env(), [], true, NoTcEscape),
    false,
  )
  match (actual, reference) {
    (Err(error), Err(old)) => assert_eq(error, old)
    _ => fail("expected nested diagnostic")
  }
}

///|
fn typecheck_expr_recursive_reference(
  expr : Expr,
  st0 : TcState,
  include_context : Bool,
) -> TcResult {
  let Expr(instrs) = expr
  let mut st = st0
  let mut initialization_owner : TcInitializationOwner? = None
  for index, ins in instrs {
    let checked = match ins {
      LocalGet(idx) =>
        match typecheck_local_get_error(st, idx) {
          // A read only appends to the owned stack; the state and its
          // initialization/control metadata retain their identity.
          None => continue
          Some(error) => Err(error)
        }
      LocalSet(idx) | LocalTee(idx) => {
        let LocalIdx(raw) = idx
        let local_id = raw.reinterpret_as_int()
        if initialization_owner is None &&
          local_id >= 0 &&
          local_id < st.initialized_locals.length() &&
          !st.initialized_locals[local_id] {
          initialization_owner = Some(TcInitializationOwner::new())
        }
        match ins {
          LocalSet(_) => typecheck_local_set(st, idx, initialization_owner~)
          _ => typecheck_local_tee(st, idx, initialization_owner~)
        }
      }
      Block(bt, body) => typecheck_block_reference(st, bt, body)
      Loop(bt, body) => typecheck_loop_reference(st, bt, body)
      If(bt, left, right) => typecheck_if_reference(st, bt, left, right)
      _ => Typecheck::typecheck(ins, st)
    }
    match checked {
      Ok(stp) => st = stp
      Err(err) => {
        if include_context {
          return Err("instruction[\{index}] \{ins}: \{err}; stack=\{st.stack}")
        }
        return Err(err)
      }
    }
  }
  Ok(st)
}

///|
#skip("dedicated bounded outlining validator ceiling")
test "iterative control validation handles ceiling depth 1024 valid and invalid regions" {
  for kind in 0..<3 {
    let result = Typecheck::typecheck(
      tci_test_expr(1024, kind),
      tc_state_new(empty_env(), [], true, NoTcEscape),
    ).unwrap()
    assert_eq(result.stack, [ValType::i32()])
    assert_true(
      Typecheck::typecheck(
        tci_test_expr(1024, kind, invalid=true),
        tc_state_new(empty_env(), [], true, NoTcEscape),
      )
      is Err(_),
    )
  }
}

///|
fn typecheck_block_reference(
  st : TcState,
  bt : BlockType,
  body : Expr,
) -> TcResult {
  let Expr(body_instrs) = body
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // Consume params from the outer stack.
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Body instructions only see block params above their label boundary.
  let body_stack = tc_stack_from_types(params)
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{
    env: env2,
    stack: body_stack,
    reachable: st1.reachable,
    polymorphic: false,
    escape: NoTcEscape,
    reachable_escape_depths: [],
    initialized_locals: tc_fork_initialized_for_body(
      st1.initialized_locals,
      body_instrs,
    ),
  }
  let st_body = match
    typecheck_expr_recursive_reference(Expr::new(body_instrs), st_body0, true) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  tc_state_finish_block(st, st1, st_body, results)
}

///|
fn typecheck_if_reference(
  st : TcState,
  bt : BlockType,
  then_instrs : Array[Instruction],
  else_instrs_opt : Array[Instruction]?,
) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // pop condition
  let st0 = match st.pop_expect(ValType::i32()) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // pop params
  let st1 = match st0.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }
  let else_instrs = match else_instrs_opt {
    None => []
    Some(xs) => xs
  }

  // typecheck then branch
  let branch_stack = tc_stack_from_types(params)
  let env_branch = st1.env.with_label(results)
  let st_then0 = TcState::{
    env: env_branch,
    stack: branch_stack,
    reachable: st1.reachable,
    polymorphic: false,
    escape: NoTcEscape,
    reachable_escape_depths: [],
    initialized_locals: tc_fork_initialized_for_body(
      st1.initialized_locals,
      then_instrs,
    ),
  }
  let st_then = match
    typecheck_expr_recursive_reference(Expr::new(then_instrs), st_then0, true) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // typecheck else branch (same starting state!)
  let st_else0 = TcState::{
    env: env_branch,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
    polymorphic: false,
    escape: NoTcEscape,
    reachable_escape_depths: [],
    initialized_locals: tc_fork_initialized_for_body(
      st1.initialized_locals,
      else_instrs,
    ),
  }
  let st_else = match
    typecheck_expr_recursive_reference(Expr::new(else_instrs), st_else0, true) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  tc_state_finish_if(st, st1, st_then, st_else, results)
}

///|
fn typecheck_loop_reference(
  st : TcState,
  bt : BlockType,
  body : Expr,
) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) {
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // consume params
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // loop label is params (not results)
  let env2 = st1.env.with_label(params)
  let st_body0 = TcState::{
    env: env2,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
    polymorphic: false,
    escape: NoTcEscape,
    reachable_escape_depths: [],
    initialized_locals: tc_fork_initialized_for_body(
      st1.initialized_locals,
      body.0,
    ),
  }
  let st_body = match typecheck_expr_recursive_reference(body, st_body0, true) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  tc_state_finish_loop(st, st1, st_body, results)
}

///|
test "iterative controls preserve multivalue params and distinct loop labels" {
  let env = empty_env().with_types([
    SubType::comp_type(
      CompType::func([ValType::i32()], [ValType::i32(), ValType::i64()]),
    ),
  ])
  let bt = BlockType::type_idx(TypeIdx::new(0U))
  let exprs = [
    Expr::new([
      Instruction::i32_const(I32(11)),
      Instruction::block(bt, Expr::new([Instruction::i64_const(I64(9L))])),
    ]),
    Expr::new([
      Instruction::i32_const(I32(11)),
      Instruction::loop_(bt, Expr::new([Instruction::br(LabelIdx::new(0U))])),
    ]),
    Expr::new([
      Instruction::i32_const(I32(11)),
      Instruction::i32_const(I32(1)),
      Instruction::if_(
        bt,
        [Instruction::i64_const(I64(9L))],
        Some([Instruction::i64_const(I64(8L))]),
      ),
    ]),
  ]
  for expr in exprs {
    tci_test_same_state(
      Typecheck::typecheck(expr, tc_state_new(env, [], true, NoTcEscape)).unwrap(),
      typecheck_expr_recursive_reference(
        expr,
        tc_state_new(env, [], true, NoTcEscape),
        true,
      ).unwrap(),
    )
  }
  let missing = Expr::new([
    Instruction::i32_const(I32(11)),
    Instruction::i32_const(I32(1)),
    Instruction::if_(bt, [Instruction::i64_const(I64(9L))], None),
  ])
  match
    (
      Typecheck::typecheck(missing, tc_state_new(env, [], true, NoTcEscape)),
      typecheck_expr_recursive_reference(
        missing,
        tc_state_new(env, [], true, NoTcEscape),
        true,
      ),
    ) {
    (Err(error), Err(old)) => assert_eq(error, old)
    _ => fail("missing else must reject mismatched multivalue results")
  }
}

///|
test "iterative controls retain delegated EH validation and bounded EH diagnostics" {
  for
    ins in [
      Instruction::try_(BlockType::void_(), Expr::new([Instruction::nop()]), []),
      Instruction::try_table(
        BlockType::void_(),
        [],
        Expr::new([Instruction::nop()]),
      ),
    ] {
    let expr = Expr::new([ins])
    tci_test_same_state(
      Typecheck::typecheck(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
      ).unwrap(),
      typecheck_expr_recursive_reference(
        expr,
        tc_state_new(empty_env(), [], true, NoTcEscape),
        true,
      ).unwrap(),
    )
    assert_eq(tc_expr_instruction_context(ins), "\{ins}")
  }
  for
    ins in [
      Instruction::try_(
        BlockType::void_(),
        tci_test_expr(567, 0, invalid=true),
        [],
      ),
      Instruction::try_table(
        BlockType::void_(),
        [],
        tci_test_expr(567, 0, invalid=true),
      ),
    ] {
    assert_true(
      tc_expr_instruction_context(ins).contains("bounded control diagnostic"),
    )
    assert_true(
      Typecheck::typecheck(
        Expr::new([ins]),
        tc_state_new(empty_env(), [], true, NoTcEscape),
      )
      is Err(_),
    )
  }
  let wide = Array::make(255, Instruction::nop())
  wide[254] = Instruction::block(
    BlockType::void_(),
    Expr::new(Array::make(254, Instruction::nop())),
  )
  assert_true(
    tc_expr_instruction_context(
      Instruction::block(BlockType::void_(), Expr::new(wide)),
    ).contains("bounded control diagnostic"),
  )
}
