///|
// Solve every function/type boundary directly, including bodies whose final
// signatures remain unchanged and therefore never trigger rewrite replay.
fn raw_conditional_boundary_bits(
  input : @lib.Module,
  raw : Bool,
  closed_world? : Bool = false,
  write_demands? : Array[Array[(Int, Bool)]]? = None,
) -> (Array[Bool], Int) {
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
  let source_writes : Array[Array[(Int, Int)]] = Array::makei(infos.length(), fn(
    _,
  ) {
    []
  })
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
        dae2_raw_dependency_plan(
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
      (write.0, infos[index].node_location_base + write.1)
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
        rows.push(writes.map(fn(write) { (write.0, graph.used[write.1]) }))
      }
    None => ()
  }
  (Array::makei(boundary_count, fn(i) { graph.used[i] }), admitted)
}

///|
fn raw_conditional_compare_boundaries(
  input : @lib.Module,
  expected : Int,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let raw_writes = []
    let hot_writes = []
    let (actual, count) = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let (reference, _) = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(raw_writes.length(), hot_writes.length())
    for index in 0..<raw_writes.length() {
      if !raw_writes[index].is_empty() {
        assert_eq(raw_writes[index], hot_writes[index])
      }
    }
    assert_eq(actual, reference)
    assert_eq(count, expected)
    let output = dae2_run_module_pass(input, closed_world).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_conditionals=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw conditionals preserve scalar result dependencies while avoiding analysis lifts" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i64) (result i32) local.get 0 if (result i32) local.get 1 else local.get 1 end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
  )
  let saved = @binary.encode_module(input).unwrap()
  raw_conditional_compare_boundaries(input, 2)
  let analysis = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(analysis)).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(
      @lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  assert_eq(analysis[0], 0)
  let reference = dae2_run_module_pass(input, false, raw_conditionals=false).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 raw conditional definitions join both arms and preserve unwritten entry values" {
  for
    definition in [
      "local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end",
      "local.get 1 local.set 4 local.get 0 if local.get 2 local.set 4 end", "local.get 0 if local.get 1 local.set 4 local.get 2 local.set 5 else local.get 0 if local.get 2 local.set 4 else local.get 1 local.set 4 end local.get 1 local.set 5 end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32 i32) \{definition} local.get 4 local.get 5 i32.add) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let analysis = [0]
    let output = dae2_run_module_pass(
      input,
      false,
      analysis_lifts=Some(analysis),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(analysis[0], 0)
    let reference = dae2_run_module_pass(input, false, raw_conditionals=false).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
}

///|
test "DAE2 raw conditional reads retain a parameter only on paths without its replacement" {
  for
    (arms, kept) in [
      ("i32.const 7 local.set 1 else i32.const 8 local.set 1", 1),
      ("i32.const 7 local.set 1", 2),
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i64) (result i32) local.get 0 if \{arms} end local.get 1) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
    let analysis = [0]
    let output = dae2_run_module_pass(
      input,
      false,
      analysis_lifts=Some(analysis),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(analysis[0], 0)
    let context = @ir.hot_module_context_from_module(output)
    let @lib.FuncType(params, _) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(0U),
    ).unwrap()
    assert_eq(params.length(), kept)
    let reference = dae2_run_module_pass(input, false, raw_conditionals=false).unwrap()
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
  }
}

///|
test "DAE2 raw conditionals preserve dead result condition and trapping arm dependencies" {
  for
    body in [
      "local.get 0 if (result i32) local.get 1 else local.get 2 end drop", "local.get 0 if local.get 1 i32.load drop else local.get 2 i32.const 0 i32.div_s drop end",
      "block local.get 0 if local.get 1 global.set $g else local.get 2 global.set $g end end",
      "local.get 0 if (result i32) local.get 1 else local.get 2 end return",
    ] {
    let result = if body.ends_with("return") { "(result i32)" } else { "" }
    let call_result = if result == "" { "" } else { "(result i32)" }
    let input = pass_test_module_from_wat(
      "(module (memory 1) (global $g (mut i32) (i32.const 0)) (func $h (param i32 i32 i32 i64) \{result} \{body}) (func (export \"run\") (param i32 i32 i32) \{call_result} local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw conditional result types and prefix stack slots preserve complete boundaries" {
  for ty in ["i32", "i64", "f64", "externref", "(ref null $s)"] {
    let input = pass_test_module_from_wat(
      "(module (type $s (struct (field i32))) (func $h (param i32 \{ty} \{ty} i64) (result \{ty} \{ty}) local.get 1 local.get 0 if (result \{ty}) block (result \{ty}) local.get 1 end else local.get 2 end) (func (export \"run\") (param i32 \{ty} \{ty}) (result \{ty} \{ty}) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}

///|
test "DAE2 raw conditionals intentionally retain HOT for unsupported control" {
  for
    body in [
      "local.get 0 if loop local.get 1 local.set 0 end end local.get 0", "block (result i32) local.get 0 if local.get 1 br 1 end local.get 0 end",
      "local.get 0 if local.get 1 return end local.get 0", "(try (result i32) (do local.get 0 if (result i32) local.get 1 else local.get 0 end) (catch_all i32.const 7))",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i64) (result i32) \{body}) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 1)
  }
}

///|
test "DAE2 raw conditionals preserve direct indirect reference and tuple call boundaries" {
  for
    wat in [
      "(module (import \"env\" \"consume\" (func $c (param i32))) (func $h (param i32 i32 i32 i64) local.get 0 if local.get 1 call $c else local.get 2 call $c end) (func (export \"run\") (param i32 i32 i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
      "(module (func $pair (param i32) (result i32 i64) local.get 0 i64.const 1) (func $h (param i32 i32 i64) (result i32 i64) local.get 0 if (result i32) local.get 1 else i32.const 7 end call $pair) (func (export \"run\") (param i32 i32) (result i32 i64) local.get 0 local.get 1 i64.const 9 call $h))",
      "(module (type $sig (func (param i32 i32) (result i32))) (table 1 funcref) (func $pair (type $sig) local.get 1) (elem (i32.const 0) $pair) (func $h (param i32 i32 i64) (result i32) local.get 0 if (result i32) i32.const 7 local.get 1 i32.const 0 call_indirect (type $sig) else i32.const 9 local.get 1 i32.const 0 call_indirect (type $sig) end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
      "(module (type $sig (func (param i32 i32) (result i32))) (func $pair (type $sig) local.get 1) (elem declare func $pair) (func $h (param i32 i32 i64) (result i32) local.get 0 if (result i32) i32.const 7 local.get 1 ref.func $pair call_ref $sig else i32.const 9 local.get 1 ref.func $pair call_ref $sig end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 9 call $h))",
    ] {
    let input = pass_test_module_from_wat(wat)
    raw_conditional_compare_boundaries(
      input,
      if wat.contains("import") {
        2
      } else {
        3
      },
    )
  }
}

///|
test "DAE2 conditional plans preserve raw rewrite rejection and reject invalid stack floors atomically" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 if (result i32) i32.const 7 else i32.const 9 end i32.add))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  graph.observe(info.param_locations[1])
  let body = input.code_sec.unwrap().0[0]
  let @lib.Func(locals, @lib.Expr(instructions)) = body
  let context = @ir.hot_module_context_from_module(input)
  let used = graph.used.copy()
  let first = graph.first_edge.copy()
  let work = graph.work.copy()
  let plan = dae2_raw_dependency_plan(
    graph,
    [info],
    0,
    [],
    body,
    None,
    module_context=Some(context),
  )
  assert_true(plan is Some(_))
  // This preallocation qualifier is still shared with raw rewrite: If stays HOT.
  assert_true(
    dae2_raw_qualified_instructions(instructions, Some(context)) is None,
  )
  assert_eq(graph.used, used)
  assert_eq(graph.first_edge, first)
  assert_eq(graph.work, work)
  assert_true(graph.edges.is_empty())
  for
    invalid_arm in [
      [@lib.Instruction::i32_add()],
      [@lib.Instruction::local_get(@lib.LocalIdx::new(0xffffffffU))],
      [],
    ] {
    let invalid = instructions.copy()
    // Intentionally invalid: arms cannot consume parent stack entries, read
    // nonexistent locals, or omit their declared scalar result.
    invalid[2] = @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      invalid_arm,
      Some([@lib.Instruction::i32_const(@lib.I32(9))]),
    )
    assert_true(
      dae2_raw_dependency_plan(
        graph,
        [info],
        0,
        [],
        @lib.Func::new(locals, @lib.Expr::new(invalid)),
        None,
        module_context=Some(context),
      )
      is None,
    )
    assert_eq(graph.used, used)
    assert_eq(graph.first_edge, first)
    assert_eq(graph.work, work)
    assert_true(graph.edges.is_empty())
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 conditional write demand preserves suffix replay and original producer order" {
  let item = "local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end local.get 4 i32.add"
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) i32.const 0 \{Array::make(3, item).join(" ")}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  raw_conditional_compare_boundaries(input, 2)
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(0)))
}

///|
test "DAE2 conditional write demand retains HOT fallback for overwritten stores and matches tee demand" {
  for
    body in [
      "i32.const 41 local.set 4 local.get 0 if local.get 1 local.set 4 else local.get 2 local.set 4 end local.get 4",
      "local.get 0 if local.get 1 local.tee 4 drop local.get 2 local.set 4 else local.get 2 local.tee 4 drop end local.get 4",
      "local.get 0 if local.get 1 local.tee 4 drop else local.get 2 local.tee 4 drop end i32.const 7",
      "local.get 0 if local.get 1 local.set 4 local.get 2 local.set 4 else local.get 2 local.set 4 end local.get 4",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32 i64) (result i32) (local i32) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
    )
    raw_conditional_compare_boundaries(input, 2)
  }
}
