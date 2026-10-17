///|
fn dae2_first_input_review_attempts(
  input : @lib.Module,
) -> (Dae2RawPlan?, Dae2RawPlan?, Int32, Int32) {
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
  (old, current, old_work[0], current_work[0])
}

///|
fn dae2_first_input_review_repeated(
  width : Int32,
  exits : Int32,
) -> @lib.Module {
  let body = StringBuilder::new()
  body.write_string("block $out ")
  for local in 4..<(4 + width) {
    body.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<exits {
    for change in 0..<9 {
      let source = if change % 2 == 0 { 2 } else { 1 }
      body.write_string("local.get \{source} local.set \{4 + change} ")
    }
    body.write_string("local.get 0 br_if $out ")
  }
  body.write_string("end local.get 4 local.get 5 i32.add")
  dae2_first_input_fixture(body.to_string(), locals=width)
}

///|
fn dae2_first_input_review_lexical_writes(
  body : Array[@lib.Instruction],
) -> Array[Int32] {
  let writes : Array[Int32] = []
  for instr in body {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(local))
      | @lib.LocalTee(@lib.LocalIdx(local)) =>
        writes.push(local.reinterpret_as_int())
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        writes.append(dae2_first_input_review_lexical_writes(child))
      @lib.If(_, yes, no) => {
        writes.append(dae2_first_input_review_lexical_writes(yes))
        match no {
          Some(child) =>
            writes.append(dae2_first_input_review_lexical_writes(child))
          None => ()
        }
      }
      _ => ()
    }
  }
  writes
}

///|
#skip("observed synthetic default-budget threshold; dedicated first-input regression lane")
test "DAE2 first input admits observed 160 by 64 old budget fallback with exact HOT behavior" {
  let input = dae2_first_input_review_repeated(160, 64)
  let (old, current, old_left, current_left) = dae2_first_input_review_attempts(
    input,
  )
  // The old None is the supported default-work-budget fallback. It is not
  // invalid input, and this regression must exercise the newly admitted route.
  assert_true(
    old is None,
    msg="observed old default-budget fallback is required",
  )
  assert_true(
    current is Some(_),
    msg="observed current default-budget admission is required",
  )
  assert_eq(old_left, -1)
  assert_true(current_left >= 0)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(source_body)) = input.code_sec.unwrap().0[0]
  let lexical_writes = dae2_first_input_review_lexical_writes(source_body)
  assert_false(lexical_writes.is_empty())
  let old_writes = []
  let current_writes = []
  let hot_writes = []
  let (old_bits, old_admitted) = dae2_first_input_boundary_bits(
    input,
    true,
    reference=true,
    write_demands=Some(old_writes),
  )
  let (current_bits, current_admitted) = dae2_first_input_boundary_bits(
    input,
    true,
    write_demands=Some(current_writes),
  )
  let (hot_bits, _) = dae2_first_input_boundary_bits(
    input,
    false,
    write_demands=Some(hot_writes),
  )
  assert_true(current_admitted > old_admitted)
  assert_eq(old_bits, current_bits)
  assert_eq(current_bits, hot_bits)
  assert_eq(old_writes, current_writes)
  assert_eq(current_writes, hot_writes)
  // Check each source write, including duplicate local IDs and unused writes.
  // A missing concrete HOT node remains false in the shared boundary helper.
  assert_eq(current_writes[0].map(fn(write) { write.0 }), lexical_writes)
  let output = dae2_run_module_pass(input, false).unwrap()
  let fallback = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @validate.validate_module(fallback).unwrap()
  assert_true(output.type_sec == fallback.type_sec)
  assert_true(output.func_sec == fallback.func_sec)
  assert_true(output.code_sec == fallback.code_sec)
  assert_true(
    @binary.encode_module(output).unwrap() ==
    @binary.encode_module(fallback).unwrap(),
  )
  let @lib.FuncType(before_params, before_results) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(input),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let @lib.FuncType(after_params, after_results) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_true(after_params.length() < before_params.length())
  assert_eq(after_results, before_results)
  for index in 0..<input.code_sec.unwrap().0.length() {
    let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[index]
    let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[index]
    assert_eq(
      dae2_writer_cut_effect_count(after),
      dae2_writer_cut_effect_count(before),
    )
  }
  assert_true(@binary.encode_module(input).unwrap() == saved)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let mut changed_nested = false
  for instr in body {
    match instr {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) => {
        child.push(@lib.Instruction::nop())
        changed_nested = true
        break
      }
      _ => ()
    }
  }
  assert_true(
    changed_nested,
    msg="returned nested control ownership must be exercised",
  )
  body.push(@lib.Instruction::nop())
  assert_true(@binary.encode_module(input).unwrap() == saved)
}

///|
#skip("untimed default-budget diagnostic; pin one actual old-None/new-Some fixture before default signoff")
test "DAE2 first input default budget admission boundary diagnostic" {
  for width in [128, 160, 192, 224, 256] {
    for exits in [16, 24, 32, 40, 48, 56, 64] {
      let input = dae2_first_input_review_repeated(width, exits)
      @validate.validate_module(input).unwrap()
      let saved = @binary.encode_module(input).unwrap()
      let (old, current, old_left, current_left) = dae2_first_input_review_attempts(
        input,
      )
      let old_some = old is Some(_)
      let current_some = current is Some(_)
      println(
        "first-input-admission width=\{width} exits=\{exits} old=\{old_some} current=\{current_some} old_left=\{old_left} current_left=\{current_left}",
      )
      assert_true(
        !old_some || current_some,
        msg="actual old successful admission was lost",
      )
      assert_true(@binary.encode_module(input).unwrap() == saved)
    }
  }
}

///|
test "DAE2 mid first-input exhaustion discards partial maps and keeps source ownership" {
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ],
    [@lib.ValType::i32()],
  )
  let before_used = graph.used.copy()
  let before_edges = graph.edges.copy()
  let before_work = graph.work.copy()
  let current = Dae2RawForwardState::new(
    Dae2RawControlState::new(
      Dae2RawPlan::new(graph.used.length()),
      [info],
      0,
      [],
      2,
      None,
      None,
    ),
    5,
  )
  let frame = current.push_frame(0)
  for local in [4, 5] {
    current.write_locals.push(local)
    current.write_entries.push(current.state.locals[local])
    current.state.assign(local, info.param_locations[local - 3])
    current.changed(local~)
  }
  let local_snapshot = current.state.locals.copy()
  current.merge_incoming(frame)
  assert_eq(current.remaining_work, -1)
  assert_false(frame.reachable)
  assert_eq(frame.event_cursor, 1)
  assert_eq(frame.entries.unwrap().order, [4])
  assert_eq(frame.incoming.unwrap().order, [4])
  assert_eq(
    frame.incoming.unwrap().values.get(4),
    Some(info.param_locations[1]),
  )
  assert_eq(current.state.locals, local_snapshot)
  assert_true(current.body([@lib.Instruction::nop()], 0, 1) is None)
  let old = Dae2FirstInputReferenceState::new(
    Dae2RawControlState::new(
      Dae2RawPlan::new(graph.used.length()),
      [info],
      0,
      [],
      2,
      None,
      None,
    ),
    5,
  )
  let old_frame = old.push_frame(0)
  for local in [4, 5] {
    old.write_locals.push(local)
    old.write_entries.push(old.state.locals[local])
    old.state.assign(local, info.param_locations[local - 3])
    old.changed(local~)
  }
  old.merge_incoming(old_frame)
  assert_eq(old.remaining_work, -1)
  assert_false(old_frame.reachable)
  assert_eq(old_frame.entries.unwrap().order, [4, 5])
  assert_true(old_frame.incoming is None)
  assert_true(old.body([@lib.Instruction::nop()], 0, 1) is None)
  assert_eq(graph.used, before_used)
  assert_eq(graph.edges, before_edges)
  assert_eq(graph.work, before_work)
  // This separately runs the real complete full-HOT fallback. The custom
  // private budget above is not claimed to force the public default budget.
  let input = dae2_first_input_written_fixture(2)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  let fallback = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @validate.validate_module(fallback).unwrap()
  assert_true(
    @binary.encode_module(output).unwrap() ==
    @binary.encode_module(fallback).unwrap(),
  )
  let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_true(params.length() < 4)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  body.push(@lib.Instruction::nop())
  assert_true(@binary.encode_module(input).unwrap() == saved)
}
