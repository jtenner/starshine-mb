///|
fn dae2_entry_lookup_attempts(
  input : @lib.Module,
) -> (Dae2RawPlan?, Dae2RawPlan?, Dae2RawPlan?, Int32) {
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
  let reads = [-1]
  let old = dae2_entry_lookup_reference_dependency_plan(
    graph,
    infos,
    0,
    type_infos,
    body,
    mask,
    Some(context),
  )
  let current = dae2_entry_lookup_probe_dependency_plan(
    graph,
    infos,
    0,
    type_infos,
    body,
    mask,
    Some(context),
    entry_reads=Some(reads),
  )
  let actual = dae2_raw_forward_dependency_plan(
    graph,
    infos,
    0,
    type_infos,
    body,
    mask,
    Some(context),
  )
  (old, current, actual, reads[0])
}

///|
fn dae2_entry_lookup_dependency_plan(
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
    dae2_entry_lookup_reference_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, module_context,
    )
  } else {
    dae2_entry_lookup_probe_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, module_context,
    )
  }
}

///|
fn dae2_entry_lookup_boundary_bits(
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
        dae2_entry_lookup_dependency_plan(
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
fn dae2_entry_lookup_assert_plan(
  a : Dae2RawPlan,
  b : Dae2RawPlan,
) -> Unit raise {
  assert_true(a.base == b.base && a.count == b.count)
  assert_eq(a.consumers, b.consumers)
  assert_eq(a.sources, b.sources)
  assert_eq(a.observations, b.observations)
  assert_eq(a.write_locations, b.write_locations)
}

///|
fn dae2_entry_lookup_compare(
  body : String,
  required_reads : Int32,
) -> Unit raise {
  let input = dae2_entry_lookup_fixture(body, locals=2).with_custom_secs([
    @lib.CustomSec::new(
      @lib.Name::from_string("entry-lookup-proof"),
      b"metadata",
    ),
  ])
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let (old, probe, actual, reads) = dae2_entry_lookup_attempts(input)
  assert_true(old is Some(_) && probe is Some(_) && actual is Some(_))
  dae2_entry_lookup_assert_plan(old.unwrap(), probe.unwrap())
  dae2_entry_lookup_assert_plan(old.unwrap(), actual.unwrap())
  let old_writes = []
  let probe_writes = []
  let hot_writes = []
  let (old_bits, _) = dae2_entry_lookup_boundary_bits(
    input,
    true,
    reference=true,
    write_demands=Some(old_writes),
  )
  let (probe_bits, _) = dae2_entry_lookup_boundary_bits(
    input,
    true,
    write_demands=Some(probe_writes),
  )
  let (hot_bits, _) = dae2_entry_lookup_boundary_bits(
    input,
    false,
    write_demands=Some(hot_writes),
  )
  assert_eq(old_bits, probe_bits)
  assert_eq(probe_bits, hot_bits)
  assert_eq(old_writes, probe_writes)
  assert_eq(probe_writes, hot_writes)
  let @lib.Func(_, @lib.Expr(source)) = input.code_sec.unwrap().0[0]
  assert_eq(
    probe_writes[0].map(fn(write) { write.0 }),
    dae2_entry_lookup_lexical_writes(source),
  )
  let output = dae2_run_module_pass(input, false).unwrap()
  let hot = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @validate.validate_module(hot).unwrap()
  assert_true(
    output.type_sec == hot.type_sec &&
    output.func_sec == hot.func_sec &&
    output.code_sec == hot.code_sec,
  )
  assert_eq(output.custom_secs, input.custom_secs)
  assert_eq(output.custom_secs, hot.custom_secs)
  assert_true(
    @binary.encode_module(output).unwrap() ==
    @binary.encode_module(hot).unwrap(),
  )
  let @lib.FuncType(before_params, before_results) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(input),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  let @lib.FuncType(params, results) = @ir.hot_module_resolve_func_type(
    @ir.hot_module_context_from_module(output),
    @lib.FuncIdx::new(0U),
  ).unwrap()
  assert_true(params.length() < before_params.length())
  assert_eq(results, before_results)
  for index in 0..<input.code_sec.unwrap().0.length() {
    let @lib.Func(_, @lib.Expr(before)) = input.code_sec.unwrap().0[index]
    let @lib.Func(_, @lib.Expr(after)) = output.code_sec.unwrap().0[index]
    assert_eq(
      dae2_entry_lookup_effect_count(before),
      dae2_entry_lookup_effect_count(after),
    )
  }
  let @lib.Func(_, @lib.Expr(output_body)) = output.code_sec.unwrap().0[0]
  let mut changed_nested = false
  for instr in output_body {
    match instr {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) => {
        child.push(@lib.Instruction::nop())
        changed_nested = true
        break
      }
      _ => ()
    }
  }
  assert_true(changed_nested)
  output_body.push(@lib.Instruction::nop())
  assert_true(@binary.encode_module(input).unwrap() == saved)
  // Count the real entries.values.get site only after all behavior gates.
  assert_eq(reads, required_reads)
}

///|
test "DAE2 existing incoming value avoids unused eager baseline lookup after exact behavior" {
  dae2_entry_lookup_compare(
    "block $out local.get 1 local.set 4 local.get 0 br_if $out local.get 2 local.set 4 local.get 0 br_if $out end local.get 4",
    0,
  )
}

///|
test "DAE2 two existing incoming values avoid unused eager baseline lookups" {
  dae2_entry_lookup_compare(
    "block $out local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out local.get 2 local.set 4 local.get 1 local.set 5 local.get 0 br_if $out end local.get 4 local.get 5 i32.add",
    0,
  )
}

///|
test "DAE2 previous empty reachable arm retains required baseline lookup" {
  dae2_entry_lookup_compare(
    "block $out local.get 0 br_if $out local.get 1 local.set 4 local.get 0 br_if $out end local.get 4",
    1,
  )
}

///|
test "DAE2 first incoming capture performs no baseline join lookup" {
  dae2_entry_lookup_compare(
    "block $out local.get 1 local.set 4 local.get 0 br_if $out end local.get 4",
    0,
  )
}
