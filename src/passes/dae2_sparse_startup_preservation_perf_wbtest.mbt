///|
fn dae2_sparse_startup_dependency_plan(
  old : Bool,
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  body : @lib.Func,
  intrinsic_imports : Array[Bool]?,
  module_context~ : @ir.HotModuleContext? = None,
) -> Dae2RawPlan? {
  // Only the two actual lost admissions use the existing sealed old worker.
  // Every other function uses the same current planner on both sides.
  if old && (index == 774 || index == 8821) {
    dae2_sparse_reference_forward_dependency_plan(
      graph, infos, index, type_infos, body, intrinsic_imports, module_context,
    )
  } else {
    dae2_raw_dependency_plan(
      graph,
      infos,
      index,
      type_infos,
      body,
      intrinsic_imports,
      module_context~,
    )
  }
}

///|
fn dae2_sparse_startup_encode(input : @lib.Module) -> Bytes {
  match @binary.encode_module(input) {
    Ok(bytes) => bytes
    Err(_) => abort("sparse startup fixture encode failed")
  }
}

///|
fn dae2_sparse_startup_validate(input : @lib.Module) -> Unit {
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(_) => abort("sparse startup fixture validation failed")
  }
}

///|
fn dae2_sparse_startup_target_plans(
  input : @lib.Module,
  index : Int32,
) -> (Bool, Bool) raise {
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
  let body = input.code_sec.unwrap().0[index - dae_imported_func_count(input)]
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
  let count = graph.used.length()
  let imports = dae2_intrinsic_import_mask(context)
  let old = dae2_sparse_reference_forward_dependency_plan(
    graph,
    infos,
    index,
    type_infos,
    body,
    imports,
    Some(context),
  )
  let current = dae2_raw_forward_dependency_plan(
    graph,
    infos,
    index,
    type_infos,
    body,
    imports,
    Some(context),
  )
  let old_admitted = old is Some(_)
  let current_admitted = current is Some(_)
  match (old, current) {
    (Some(old), Some(current)) => {
      // Actual RED had zero sparse merges for both targets. Preserve exact
      // complete plan identities, not just solved masks, when admitted.
      assert_true(
        current.base == old.base && current.count == old.count,
        msg="startup preservation plan range differs",
      )
      assert_true(
        current.consumers == old.consumers && current.sources == old.sources,
        msg="startup preservation complete dependency edges differ",
      )
      assert_true(
        current.observations == old.observations &&
        current.write_locations == old.write_locations,
        msg="startup preservation observations or source-write journal differ",
      )
    }
    _ => ()
  }
  assert_eq(graph.used.length(), count)
  (old_admitted, current_admitted)
}

///|
fn dae2_sparse_startup_boundary_bits(
  input : @lib.Module,
  raw : Bool,
  old~ : Bool = false,
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
        dae2_sparse_startup_dependency_plan(
          old,
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
#skip("manual hash-bound actual-artifact startup allowance and old-admission preservation lane")
test "DAE2 fixed sparse startup retains both old actual admissions and complete output" {
  let bytes = @sfs.read_file_bytes(".tmp/dae-speed-20261016/inputs/large.wasm").unwrap()
  let input = match @binary.decode_module(bytes) {
    Ok(input) => input
    Err(_) => abort("sparse startup fixture decode failed")
  }
  dae2_sparse_startup_validate(input)
  let saved = dae2_sparse_startup_encode(input)
  let old_writes = []
  let current_writes = []
  let (old_bits, _) = dae2_sparse_startup_boundary_bits(
    input,
    true,
    old=true,
    write_demands=Some(old_writes),
  )
  let (current_bits, _) = dae2_sparse_startup_boundary_bits(
    input,
    true,
    write_demands=Some(current_writes),
  )
  assert_true(
    current_bits == old_bits,
    msg="complete original-module boundary demand differs",
  )
  assert_true(
    current_writes == old_writes,
    msg="complete original-module source-write demand differs",
  )
  let output = dae2_run_module_pass(input, false).unwrap()
  dae2_sparse_startup_validate(output)
  let actual = dae2_sparse_startup_encode(output)
  assert_true(
    actual.length() < saved.length(),
    msg="actual pass must make a productive encoded reduction",
  )
  assert_true(
    dae2_sparse_startup_encode(input) == saved,
    msg="actual input changed after aggregate demand/output checks",
  )
  let admissions : Array[(Bool, Bool)] = []
  for index in [774, 8821] {
    admissions.push(dae2_sparse_startup_target_plans(input, index))
  }
  assert_true(
    dae2_sparse_startup_encode(input) == saved,
    msg="actual input changed after targeted uncommitted plans",
  )
  // Required resource behavior follows every complete behavior/ownership gate.
  for (old, current) in admissions {
    assert_true(old, msg="old actual admission must remain established")
    assert_true(
      current,
      msg="fixed startup must preserve this old actual admission",
    )
  }
}
