///|
fn dae2_first_input_current_plan(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  context : @ir.HotModuleContext?,
  work_left~ : Array[Int32]? = None,
) -> Dae2RawPlan? {
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  let instruction_count = dae2_raw_forward_instruction_count(
    instructions, context,
  )
  if instruction_count < 0 {
    return None
  }
  // Count table labels as input too. Bound map discovery, stored map lanes,
  // incoming joins, restores/applications and branch payload work by the body
  // size. Exhaustion discards this uncommitted plan and keeps full HOT analysis.
  let work = 64 + 8 * instruction_count
  let plan = Dae2RawPlan::new(graph.used.length())
  let state = Dae2RawForwardState::new(
    Dae2RawControlState::new(
      plan,
      infos,
      index,
      type_infos,
      locals.length(),
      intrinsic_imports,
      context,
    ),
    work,
  )
  let outcome = state.body(instructions, 0, infos[index].results.length())
  match work_left {
    Some(remaining) => remaining[0] = state.remaining_work
    None => ()
  }
  match outcome {
    Some(_) => ()
    None => return None
  }
  for source in state.state.stack {
    plan.edge(infos[index].result_location, source)
  }
  Some(plan)
}

///|
fn dae2_first_input_dependency_plan(
  reference : Bool,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  module_context~ : @ir.HotModuleContext? = None,
) -> Dae2RawPlan? {
  if reference {
    dae2_first_input_reference_forward_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, module_context,
    )
  } else {
    dae2_raw_forward_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, module_context,
    )
  }
}

///|
fn dae2_first_input_fixture(body : String, locals~ : Int32 = 4) -> @lib.Module {
  let locals = Array::make(locals, "i32").join(" ")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
fn dae2_first_input_written_fixture(
  width : Int32,
  repeat~ : Bool = false,
) -> @lib.Module {
  let body = StringBuilder::new()
  body.write_string("block $out ")
  for local in 4..<(4 + width) {
    let source = if local % 2 == 0 { 1 } else { 2 }
    body.write_string("local.get \{source} local.set \{local} ")
  }
  if repeat {
    body.write_string("local.get 2 local.set 4 local.get 1 local.set 5 ")
  }
  body.write_string("local.get 0 br_if $out end local.get 4 ")
  for local in 5..<(4 + width) {
    body.write_string("local.get \{local} i32.add ")
  }
  dae2_first_input_fixture(body.to_string(), locals=width)
}

///|
fn dae2_first_input_remaining_pair(input : @lib.Module) -> (Int32, Int32) raise {
  let context = @ir.hot_module_context_from_module(input)
  let indices = dae_collect_func_type_indices(input)
  let graph = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index in 0..<indices.length() {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    infos.push(Dae2Function::new(graph, params, results))
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(input),
    indices.length(),
    indices,
  )
  let type_infos = dae2_prepare_type_locations(
    input, context, graph, infos, exposure, false,
  )
  let body = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(instructions)) = body
  ignore(
    dae2_collect_control_type_infos(
      instructions,
      type_infos,
      infos[0].control_type_infos,
      call_infos=Some(infos[0].call_infos),
    ),
  )
  infos[0].call_infos_ready = true
  dae2_pin_flat_observable_params(
    graph, infos, 0, instructions, indices, type_infos, exposure,
  )
  let mask = dae2_intrinsic_import_mask(context)
  let original_count = graph.used.length()
  let old_work = [-1]
  let current_work = [-1]
  let old = dae2_first_input_reference_forward_dependency_plan(
    graph,
    infos,
    0,
    type_infos,
    body,
    mask,
    Some(context),
    work_left=Some(old_work),
  )
  let current = dae2_first_input_current_plan(
    graph,
    infos,
    0,
    type_infos,
    body,
    mask,
    Some(context),
    work_left=Some(current_work),
  )
  assert_true(
    old is Some(_),
    msg="bounded exact reference plan must be admitted",
  )
  assert_true(
    current is Some(_),
    msg="bounded actual current plan must be admitted",
  )
  let old = old.unwrap()
  let current = current.unwrap()
  assert_true(
    current.base == old.base && current.count == old.count,
    msg="complete plan range or phi identities changed",
  )
  assert_true(
    current.consumers == old.consumers && current.sources == old.sources,
    msg="complete ordered dependency edges changed",
  )
  assert_true(
    current.observations == old.observations,
    msg="complete ordered observations changed",
  )
  assert_true(
    current.write_locations == old.write_locations,
    msg="complete source-write identities changed",
  )
  assert_eq(graph.used.length(), original_count)
  (old_work[0], current_work[0])
}

///|
fn dae2_first_input_compare(
  input : @lib.Module,
  expected_saved : Int32,
  owned~ : Bool = false,
  minimum~ : Bool = false,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let (old_work, current_work) = dae2_first_input_remaining_pair(input)
  let old_writes = []
  let current_writes = []
  let hot_writes = []
  let (old_bits, _) = dae2_first_input_boundary_bits(
    input,
    true,
    reference=true,
    write_demands=Some(old_writes),
  )
  let (current_bits, _) = dae2_first_input_boundary_bits(
    input,
    true,
    write_demands=Some(current_writes),
  )
  let (hot_bits, _) = dae2_first_input_boundary_bits(
    input,
    false,
    write_demands=Some(hot_writes),
  )
  assert_true(
    old_bits == current_bits && current_bits == hot_bits,
    msg="complete boundary masks differ",
  )
  assert_true(
    old_writes == current_writes && current_writes == hot_writes,
    msg="complete every-source-write masks differ",
  )
  let output = dae2_run_module_pass(input, false).unwrap()
  let reference = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_true(
    output.type_sec == reference.type_sec &&
    output.func_sec == reference.func_sec &&
    output.code_sec == reference.code_sec,
    msg="complete HOT type/function/body fields differ",
  )
  assert_true(
    @binary.encode_module(output).unwrap() ==
    @binary.encode_module(reference).unwrap(),
    msg="complete HOT encoded output differs",
  )
  let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_true(
    params.length() < 4,
    msg="actual unused parameter pruning is required",
  )
  if owned {
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let targets = dae2_first_input_table_targets(body).unwrap()
    let types = dae2_first_input_select_types(body).unwrap()
    targets[0] = @lib.LabelIdx::new(1U)
    types[0] = @lib.ValType::i64()
    let mut changed_child = false
    for instr in body {
      match instr {
        @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) => {
          child.push(@lib.Instruction::nop())
          changed_child = true
          break
        }
        _ => ()
      }
    }
    assert_true(changed_child, msg="owned nested output control is required")
  }
  assert_true(
    @binary.encode_module(input).unwrap() == saved,
    msg="actual input changed after output mutation and complete behavior checks",
  )
  // Required resource behavior is LAST, after complete plan/mask/byte,
  // validity, productive transform and ownership checks.
  if minimum {
    assert_true(
      current_work - old_work >= expected_saved,
      msg="first-input fusion must remove actual charged lane work",
    )
  } else {
    assert_eq(current_work - old_work, expected_saved)
  }
}

///|
fn dae2_first_input_boundary_bits(
  input : @lib.Module,
  raw : Bool,
  reference~ : Bool = false,
  closed_world~ : Bool = false,
  write_demands~ : Array[Array[(Int32, Bool)]]? = None,
) -> (Array[Bool], Int32) {
  let input = dae2_prepare_legacy_handlers(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let indices = dae_collect_func_type_indices(input)
  let imported = dae_imported_func_count(input)
  let graph = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index in 0..<indices.length() {
    let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(index.to_uint()),
    ).unwrap()
    infos.push(Dae2Function::new(graph, params, results))
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(input),
    indices.length(),
    indices,
  )
  let type_infos = dae2_prepare_type_locations(
    input, context, graph, infos, exposure, closed_world,
  )
  let boundary_count = graph.used.length()
  let intrinsic_imports = dae2_intrinsic_import_mask(context)
  let mut admitted = 0
  let source_writes : Array[Array[(Int32, Int32)]] = Array::makei(
    infos.length(),
    fn(_) { [] },
  )
  for index in imported..<indices.length() {
    let body = input.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(instructions)) = body
    ignore(
      dae2_collect_control_type_infos(
        instructions,
        type_infos,
        infos[index].control_type_infos,
        call_infos=Some(infos[index].call_infos),
      ),
    )
    infos[index].call_infos_ready = true
    dae2_pin_flat_observable_params(
      graph, infos, index, instructions, indices, type_infos, exposure,
    )
    if raw {
      match
        dae2_first_input_dependency_plan(
          reference,
          graph,
          infos,
          index,
          type_infos,
          body,
          intrinsic_imports,
          module_context=Some(context),
        ) {
        Some(plan) => {
          plan.commit(graph)
          source_writes[index] = plan.write_locations.unwrap_or([])
          admitted += 1
          continue
        }
        None => ()
      }
    }
    let func = dae2_lift_for_analysis(input, context, index).unwrap()
    infos[index].assign_node_locations(graph, @ir.hot_node_count(func))
    source_writes[index] = @ir.hot_lift_local_accesses(func).writes.map(fn(
      write,
    ) {
      (
        write.0,
        if write.1 < 0 {
          -1
        } else {
          infos[index].node_location_base + write.1
        },
      )
    })
    dae2_analyze_function(
      graph,
      infos,
      index,
      type_infos,
      func,
      intrinsic_imports~,
    )
  }
  graph.solve()
  match input.type_sec {
    Some(types) => dae2_preserve_type_identity(types, graph, infos, type_infos)
    None => ()
  }
  match write_demands {
    Some(rows) =>
      for writes in source_writes {
        rows.push(
          writes.map(fn(write) {
            (write.0, write.1 >= 0 && graph.used[write.1])
          }),
        )
      }
    None => ()
  }
  (Array::makei(boundary_count, fn(i) { graph.used[i] }), admitted)
}

///|
fn dae2_first_input_table_targets(
  body : Array[@lib.Instruction],
) -> Array[@lib.LabelIdx]? {
  for instr in body {
    match instr {
      @lib.BrTable(targets, _) => return Some(targets)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match dae2_first_input_table_targets(child) {
          Some(targets) => return Some(targets)
          None => ()
        }
      @lib.If(_, yes, no) => {
        match dae2_first_input_table_targets(yes) {
          Some(targets) => return Some(targets)
          None => ()
        }
        match no {
          Some(child) =>
            match dae2_first_input_table_targets(child) {
              Some(targets) => return Some(targets)
              None => ()
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn dae2_first_input_select_types(
  body : Array[@lib.Instruction],
) -> Array[@lib.ValType]? {
  for instr in body {
    match instr {
      @lib.Select(Some(types)) => return Some(types)
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        match dae2_first_input_select_types(child) {
          Some(types) => return Some(types)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
test "DAE2 first input fuses two-lane discovery after exact behavior" {
  dae2_first_input_compare(dae2_first_input_written_fixture(2), 2)
}

///|
test "DAE2 first input fuses four-lane discovery after exact behavior" {
  dae2_first_input_compare(dae2_first_input_written_fixture(4), 4)
}

///|
test "DAE2 first input captures final repeated-write values in original key order" {
  dae2_first_input_compare(dae2_first_input_written_fixture(4, repeat=true), 4)
}

///|
test "DAE2 first input retains owned branch target select and nested output arrays" {
  let input = dae2_first_input_fixture(
    "block $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 1 local.set 6 local.get 2 local.set 7 local.get 0 br_if $out end block $outer block $inner local.get 4 local.get 5 local.get 0 select (result i32) local.set 6 local.get 0 br_table $inner $outer end end local.get 4 local.get 5 i32.add local.get 6 i32.add",
  )
  dae2_first_input_compare(input, 1, owned=true, minimum=true)
}

///|
test "DAE2 intentionally excludes prior reachable empty arms from first-input fusion" {
  dae2_first_input_compare(
    dae2_first_input_fixture(
      "block $out local.get 0 br_if $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out end local.get 4 local.get 5 i32.add",
      locals=2,
    ),
    0,
  )
}

///|
test "DAE2 intentionally retains original loop snapshot and backedge path" {
  dae2_first_input_compare(
    dae2_first_input_fixture(
      "loop $again local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $again end local.get 4 local.get 5 i32.add",
      locals=2,
    ),
    0,
  )
}

///|
test "DAE2 default-local no-write snapshots keep the original work" {
  dae2_first_input_compare(
    dae2_first_input_fixture(
      "block $out local.get 0 br_if $out end local.get 4 local.get 5 i32.add",
      locals=2,
    ),
    0,
  )
}

///|
test "DAE2 dead sibling writes after an empty reachable arm keep the original path" {
  dae2_first_input_compare(
    dae2_first_input_fixture(
      "local.get 0 if nop else local.get 1 local.set 4 local.get 2 local.set 5 unreachable end local.get 4 local.get 5 i32.add",
      locals=2,
    ),
    0,
  )
}
