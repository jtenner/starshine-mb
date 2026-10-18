///|
fn dae2_raw_local_boundary_fixture(
  work : Int32,
  result_count~ : Int32 = 1,
  context~ : @ir.HotModuleContext? = None,
  intrinsic_imports~ : Array[Bool]? = None,
  type_infos~ : Array[Int32] = [],
) -> (Dae2Graph, Dae2Function, Dae2RawLocalFlow) {
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    Array::make(result_count, @lib.ValType::i32()),
  )
  let flow = Dae2RawLocalFlow::new(
    Dae2RawControlState::new(
      Dae2RawPlan::new(graph.used.length()),
      [info],
      0,
      type_infos,
      1,
      intrinsic_imports,
      context,
    ),
    info.param_locations,
    work,
  )
  (graph, info, flow)
}

///|
fn dae2_raw_local_boundary_uncommitted(
  graph : Dae2Graph,
  used : Array[Bool],
) -> Unit raise {
  assert_eq(graph.used, used)
  assert_true(graph.edges.is_empty())
  assert_true(graph.work.is_empty())
}

///|
fn dae2_raw_local_boundary_demands(
  graph : Dae2Graph,
  info : Dae2Function,
  flow : Dae2RawLocalFlow,
  result : Int32,
) -> Array[Bool] raise {
  flow.state.plan.edge(info.result_location, result)
  assert_true(flow.resolve())
  flow.state.plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  info.param_locations.map(fn(location) { graph.used[location] })
}

///|
test "DAE2 local flow intentionally rejects exhausted allocation and invalid edge boundaries before commit" {
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(0)
  let used = graph.used.copy()
  assert_eq(flow.block(), -1)
  assert_eq(flow.blocks.length(), 1)
  assert_false(flow.write(3, 0))
  assert_true(flow.blocks[0].writes is None)
  dae2_raw_local_boundary_uncommitted(graph, used)
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(1)
  let used = graph.used.copy()
  let next = flow.block()
  assert_eq(flow.entry(next, 0), -1)
  assert_true(flow.query_symbols.is_empty())
  assert_eq(flow.state.plan.count, 0)
  assert_false(flow.connect(next))
  assert_false(flow.blocks[0].frozen)
  assert_true(flow.blocks[next].predecessors.is_empty())
  dae2_raw_local_boundary_uncommitted(graph, used)
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(8)
  let used = graph.used.copy()
  assert_false(flow.connect(-1))
  assert_false(flow.blocks[0].frozen)
  assert_false(flow.spend(-1))
  assert_false(flow.write(3, 0))
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 local flow keeps frozen predecessor definitions when a later write exhausts its private budget" {
  for budget in [0, 1, 2, 3] {
    let (graph, info, flow) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    assert_eq(
      flow.body(
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ],
        0,
        0,
      ),
      Some(true),
    )
    let previous = flow.read(0, 3)
    let exit = flow.block()
    assert_true(flow.connect(exit))
    flow.remaining_work = budget
    let written = flow.write(3, info.param_locations[1])
    assert_eq(written, budget == 3)
    assert_eq(flow.read(0, 3), previous)
    assert_eq(flow.blocks[exit].predecessors, [0])
    if written {
      assert_true(flow.current != 0)
      assert_eq(flow.read(flow.current, 3), info.param_locations[1])
    } else {
      assert_eq(flow.current, 0)
    }
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
}

///|
test "DAE2 local flow reuses a cached entry and resolves predecessor definitions after the complete body" {
  let (graph, info, flow) = dae2_raw_local_boundary_fixture(100)
  assert_eq(
    flow.body(
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      ],
      0,
      0,
    ),
    Some(true),
  )
  let middle = flow.block()
  assert_true(flow.connect(middle))
  flow.current = middle
  let exit = flow.block()
  assert_true(flow.connect(exit))
  flow.current = exit
  let value = flow.read(exit, 3)
  flow.remaining_work = 0
  // An existing reaching-definition query remains usable without allocating
  // another symbol or overwriting the already frozen predecessor.
  assert_eq(flow.read(exit, 3), value)
  flow.remaining_work = 100
  assert_eq(dae2_raw_local_boundary_demands(graph, info, flow, value), [
    false, true, false,
  ])
  let writes = flow.state.plan.write_locations.unwrap()
  assert_eq(writes.length(), 1)
  assert_true(graph.used[writes[0].1])
}

///|
test "DAE2 local flow intentionally reports unresolved predecessor queries when its private budget is exhausted" {
  for budget in [0, 1] {
    let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    assert_eq(
      flow.body(
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ],
        0,
        0,
      ),
      Some(true),
    )
    let middle = flow.block()
    assert_true(flow.connect(middle))
    flow.current = middle
    let exit = flow.block()
    assert_true(flow.connect(exit))
    flow.current = exit
    let value = flow.read(exit, 3)
    flow.state.plan.edge(flow.state.result_location, value)
    flow.remaining_work = budget
    assert_false(flow.resolve())
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
}

///|
test "DAE2 local flow repeated branch destinations preserve each epoch's payload dependencies" {
  let (graph, info, flow) = dae2_raw_local_boundary_fixture(100)
  let target = flow.block()
  let value = flow.state.plan.base + flow.state.plan.count
  flow.state.plan.count += 1
  flow.frames.push(Dae2RawLocalFrame::new(target, target, value, 1, 1, false))
  flow.state.stack.push(info.param_locations[0])
  assert_true(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
  assert_true(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
  flow.branch_epoch += 1
  flow.state.stack[0] = info.param_locations[1]
  assert_true(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
  assert_eq(flow.state.plan.consumers, [value, value])
  assert_eq(flow.state.plan.sources, [
    info.param_locations[0],
    info.param_locations[1],
  ])
  assert_eq(flow.blocks[target].predecessors, [0])
  ignore(flow.frames.pop())
  flow.state.stack[0] = info.param_locations[2]
  assert_true(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
  assert_true(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
  assert_eq(dae2_raw_local_boundary_demands(graph, info, flow, value), [
    true, true, true,
  ])
}

///|
test "DAE2 local flow intentionally rejects invalid label depths and payload arities before adding dependencies" {
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
  let used = graph.used.copy()
  assert_eq(flow.target_arity(@lib.LabelIdx::new(0xffffffffU)), -1)
  assert_eq(flow.target_arity(@lib.LabelIdx::new(1U)), -1)
  assert_false(flow.branch(@lib.LabelIdx::new(0U), 0, 0))
  assert_true(flow.state.plan.sources.is_empty())
  assert_true(flow.state.plan.observations.is_empty())
  assert_false(flow.blocks[0].frozen)
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 local flow intentionally rejects exhausted branch payload budgets without observing an incomplete result" {
  for function_target in [false, true] {
    let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    if !function_target {
      let target = flow.block()
      flow.frames.push(Dae2RawLocalFrame::new(target, target, -1, 1, 1, false))
    }
    flow.remaining_work = 0
    assert_false(flow.branch(@lib.LabelIdx::new(0U), 0, 1))
    assert_true(flow.state.plan.sources.is_empty())
    assert_true(flow.state.plan.observations.is_empty())
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
}

///|
test "DAE2 local flow intentionally rejects malformed stack and structured control boundaries" {
  for
    body in [
      [],
      [@lib.Instruction::if_(@lib.BlockType::void_(), [], None)],
      [
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new([]),
        ),
      ],
      [@lib.Instruction::local_get(@lib.LocalIdx::new(4U))],
      [@lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      ],
      [@lib.Instruction::br_if(@lib.LabelIdx::new(0U))],
      [@lib.Instruction::br(@lib.LabelIdx::new(0U))],
      [@lib.Instruction::br_table([], @lib.LabelIdx::new(0U))],
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table([], @lib.LabelIdx::new(1U)),
      ],
      [@lib.Instruction::return_()],
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      ],
    ] {
    let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    assert_eq(flow.body(body, 0, 1), None)
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
}

///|
test "DAE2 local flow intentionally rejects exhausted structured and branch bodies accepted with sufficient work" {
  for
    (budget, result_count, body) in [
      (
        0,
        0,
        [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([]))],
      ),
      (
        1,
        0,
        [@lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new([]))],
      ),
      (
        1,
        0,
        [@lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([]))],
      ),
      (
        2,
        0,
        [@lib.Instruction::loop_(@lib.BlockType::void_(), @lib.Expr::new([]))],
      ),
      (
        0,
        1,
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ],
      ),
      (
        1,
        1,
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br(@lib.LabelIdx::new(0U)),
        ],
      ),
      (
        0,
        0,
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        ],
      ),
      (
        0,
        1,
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::br_table([], @lib.LabelIdx::new(0U)),
        ],
      ),
      (
        1,
        1,
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::br_table([], @lib.LabelIdx::new(0U)),
        ],
      ),
    ] {
    let (graph, _, flow) = dae2_raw_local_boundary_fixture(
      budget,
      result_count~,
    )
    let used = graph.used.copy()
    assert_eq(flow.body(body, 0, result_count), None)
    dae2_raw_local_boundary_uncommitted(graph, used)
    let (_, _, accepted) = dae2_raw_local_boundary_fixture(100, result_count~)
    assert_eq(accepted.body(body, 0, result_count), Some(result_count == 0))
  }
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(1)
  let used = graph.used.copy()
  flow.current = flow.block()
  // A failed read query must reject the body, rather than treating its -1
  // failure sentinel as a successfully read default local value.
  assert_eq(
    flow.body([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))], 0, 1),
    None,
  )
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 local flow branch tables retain their selector and result while allowing only cleanup in dead tails" {
  let body = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::br_table(
      [@lib.LabelIdx::new(0U), @lib.LabelIdx::new(0U)],
      @lib.LabelIdx::new(0U),
    ),
    @lib.Instruction::nop(),
    @lib.Instruction::drop(),
    @lib.Instruction::unreachable_(),
  ]
  let (graph, info, flow) = dae2_raw_local_boundary_fixture(100)
  assert_eq(flow.body(body, 0, 1), Some(false))
  assert_true(flow.state.stack.is_empty())
  assert_eq(dae2_raw_local_boundary_demands(graph, info, flow, -1), [
    true, true, false,
  ])
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
  let used = graph.used.copy()
  let unsupported_tail = body.copy()
  unsupported_tail.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  // A general instruction after an unconditional branch intentionally needs
  // the complete HOT path, even though these cleanup-only tail items do not.
  assert_eq(flow.body(unsupported_tail, 0, 1), None)
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 local flow intentionally rejects in-range branch table destinations with different payload arities" {
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
  let used = graph.used.copy()
  let target = flow.block()
  flow.frames.push(Dae2RawLocalFrame::new(target, target, -1, 0, 0, false))
  assert_eq(flow.target_arity(@lib.LabelIdx::new(0U)), 0)
  assert_eq(flow.target_arity(@lib.LabelIdx::new(1U)), 1)
  assert_eq(
    flow.body(
      [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(1U),
        ),
      ],
      0,
      1,
    ),
    None,
  )
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 raw control intentionally rejects missing signatures and insufficient producer store and call operands" {
  for
    instr in [
      @lib.Instruction::i32_div_s(),
      @lib.Instruction::array_set(@lib.TypeIdx::new(0U)),
      @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(99U)),
      @lib.Instruction::call_ref(@lib.TypeIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ] {
    let (graph, _, flow) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    assert_false(flow.state.leaf(instr, 0))
    assert_true(flow.state.stack.is_empty())
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
  let (graph, info, flow) = dae2_raw_local_boundary_fixture(
    100,
    intrinsic_imports=Some([true]),
  )
  let used = graph.used.copy()
  for location in info.param_locations {
    flow.state.stack.push(location)
  }
  let operands = flow.state.stack.copy()
  assert_false(
    flow.state.leaf(@lib.Instruction::call(@lib.FuncIdx::new(0U)), 0),
  )
  assert_eq(flow.state.stack, operands)
  assert_true(flow.state.plan.sources.is_empty())
  assert_true(flow.state.plan.observations.is_empty())
  dae2_raw_local_boundary_uncommitted(graph, used)
  let (_, info, accepted) = dae2_raw_local_boundary_fixture(100)
  for location in info.param_locations {
    accepted.state.stack.push(location)
  }
  assert_true(
    accepted.state.leaf(@lib.Instruction::call(@lib.FuncIdx::new(0U)), 0),
  )
  assert_eq(accepted.state.stack, [info.result_location])
  assert_eq(accepted.state.plan.sources, info.param_locations)
}

///|
test "DAE2 raw preflight intentionally leaves unresolved and wider loop signatures to HOT" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32 i32))) (type (struct (field i32))) (func))",
  )
  @validate.validate_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  for index in [0U, 1U, 99U] {
    assert_eq(
      dae2_raw_loop_shape(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(index)),
        Some(context),
      ),
      -1,
    )
  }
  let unknown_loop = @lib.Instruction::loop_(
    @lib.BlockType::type_idx(@lib.TypeIdx::new(99U)),
    @lib.Expr::new([]),
  )
  assert_eq(
    dae2_raw_forward_instruction_count(
      [@lib.Instruction::if_(@lib.BlockType::void_(), [], Some([unknown_loop]))],
      Some(context),
    ),
    -1,
  )
  let unsupported = @lib.Instruction::struct_new(@lib.TypeIdx::new(0U))
  assert_eq(dae2_raw_observed_producer_arity(unsupported, Some(context)), -1)
  assert_eq(
    dae2_raw_observed_producer_arity(
      @lib.Instruction::struct_new(@lib.TypeIdx::new(99U)),
      Some(context),
    ),
    -1,
  )
  assert_eq(
    dae2_raw_forward_instruction_count([unsupported], Some(context)),
    -1,
  )
}

///|
test "DAE2 local flow preserves an indexed loop's carried dependency and rejects its intentionally missing input" {
  let input = pass_test_module_from_wat(
    "(module (type $scalar (func (param i32) (result i32))) (func (param i32 i32 i32) (result i32) local.get 0 loop (type $scalar) end))",
  )
  @validate.validate_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let (graph, _, flow) = dae2_raw_local_boundary_fixture(
    100,
    context=Some(context),
  )
  let used = graph.used.copy()
  assert_eq(
    flow.body(
      [
        @lib.Instruction::loop_(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
          @lib.Expr::new([]),
        ),
      ],
      0,
      1,
    ),
    None,
  )
  dae2_raw_local_boundary_uncommitted(graph, used)
  let (graph, info, flow) = dae2_raw_local_boundary_fixture(
    100,
    context=Some(context),
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  assert_eq(flow.body(body, 0, 1), Some(true))
  assert_eq(
    dae2_raw_local_boundary_demands(graph, info, flow, flow.state.stack[0]),
    [true, false, false],
  )
}

///|
test "DAE2 flat raw planning intentionally rejects invalid operands and unresolved call boundaries atomically" {
  for
    body in [
      [],
      [@lib.Instruction::i32_add()],
      [@lib.Instruction::local_get(@lib.LocalIdx::new(4U))],
      [@lib.Instruction::array_set(@lib.TypeIdx::new(0U))],
      [@lib.Instruction::i32_div_s()],
      [@lib.Instruction::drop()],
      [@lib.Instruction::local_set(@lib.LocalIdx::new(0U))],
      [@lib.Instruction::call_ref(@lib.TypeIdx::new(0U))],
      [@lib.Instruction::call(@lib.FuncIdx::new(99U))],
      [@lib.Instruction::call(@lib.FuncIdx::new(0U))],
      [@lib.Instruction::return_()],
    ] {
    let (graph, info, _) = dae2_raw_local_boundary_fixture(100)
    let used = graph.used.copy()
    let candidate = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
    assert_true(
      dae2_raw_dependency_plan(graph, [info], 0, [], candidate, None) is None,
    )
    dae2_raw_local_boundary_uncommitted(graph, used)
  }
  let (graph, info, _) = dae2_raw_local_boundary_fixture(100)
  let used = graph.used.copy()
  let intrinsic = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ]),
  )
  assert_true(
    dae2_raw_dependency_plan(graph, [info], 0, [], intrinsic, Some([true]))
    is None,
  )
  dae2_raw_local_boundary_uncommitted(graph, used)
}

///|
test "DAE2 local-flow planner returns a usable dependency plan and intentionally rejects an invalid return before commit" {
  let (graph, info, _) = dae2_raw_local_boundary_fixture(100)
  let used = graph.used.copy()
  let invalid = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::return_()]),
  )
  // The configured function has one result, so this empty return is invalid.
  assert_true(
    dae2_raw_local_flow_dependency_plan(
      graph,
      [info],
      0,
      [],
      invalid,
      None,
      None,
    )
    is None,
  )
  dae2_raw_local_boundary_uncommitted(graph, used)
  let valid = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
  )
  let plan = dae2_raw_local_flow_dependency_plan(
    graph,
    [info],
    0,
    [],
    valid,
    None,
    None,
  ).unwrap()
  dae2_raw_local_boundary_uncommitted(graph, used)
  plan.commit(graph)
  graph.observe(info.result_location)
  graph.solve()
  assert_eq(info.param_locations.map(fn(location) { graph.used[location] }), [
    false, true, false,
  ])
}
