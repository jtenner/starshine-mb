///|
fn dae2_flat_tee_demand_fixture(
  producer : String,
  tee~ : Bool = true,
  declarations~ : String = "",
) -> @lib.Module {
  let tee = if tee { "local.tee 1" } else { "" }
  pass_test_module_from_wat(
    "(module (import \"env\" \"effect\" (func $effect (param i32))) (memory 1) \{declarations} (func $keep (param i64 i32) (result i64) local.get 0) (func (export \"run\") (param i32) (result i64) (local i32) \{producer} \{tee} i64.extend_i32_s i32.const 9 call $keep))",
  )
}

///|
fn dae2_flat_tee_complete_compare(
  input : @lib.Module,
  capture_shape~ : (@lib.Func, @lib.Func)? = None,
) -> Unit raise {
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    let reference = dae2_run_module_pass(
      input,
      closed_world,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    @validate.validate_module(reference).unwrap()
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    let context = @ir.hot_module_context_from_module(actual)
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i64()], [@lib.ValType::i64()])),
    )
    match capture_shape {
      Some((direct, captured)) => {
        assert_eq(actual.code_sec.unwrap().0[1], direct)
        assert_eq(reference.code_sec.unwrap().0[1], captured)
        assert_eq(
          @binary.encode_module(actual).unwrap().length() + 4,
          @binary.encode_module(reference).unwrap().length(),
        )
        // The exact source value stays on the stack before the later work.
        // These fourteen raw modules save four bytes. Verified v133 outputs
        // match after downstream cleanup and O2; bounded call/throw/re-entry
        // and resource-mutation checks preserve the observed value and order.
        // Compare both exact bodies before projecting only this known capture.
        reference.code_sec.unwrap().0[1] = direct
      }
      None => ()
    }
    assert_eq(
      @binary.encode_module(actual).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let raw_writes = []
    let hot_writes = []
    let raw = raw_conditional_boundary_bits(
      input,
      true,
      closed_world~,
      write_demands=Some(raw_writes),
    )
    let hot = raw_conditional_boundary_bits(
      input,
      false,
      closed_world~,
      write_demands=Some(hot_writes),
    )
    assert_eq(raw.0, hot.0)
    assert_eq(raw.1, 2)
    assert_eq(raw_writes, hot_writes)
  }
}

///|
fn dae2_flat_tee_capture_compare(
  input : @lib.Module,
  direct_body : String,
  captured_body : String,
  declarations~ : String = "",
) -> Unit raise {
  let expected = fn(body : String, locals : String) {
    pass_test_module_from_wat(
      "(module (import \"env\" \"effect\" (func $effect (param i32))) (memory 1) \{declarations} (func $keep (param i64) (result i64) local.get 0) (func (param i32) (result i64) (local \{locals}) \{body}))",
    ).code_sec.unwrap().0[1]
  }
  dae2_flat_tee_complete_compare(
    input,
    capture_shape=Some(
      (expected(direct_body, "i32"), expected(captured_body, "i32 i32")),
    ),
  )
}

///|
test "DAE2 flat Tee complete demand parameter" {
  let input = dae2_flat_tee_demand_fixture("local.get 0", tee=true)
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 flat Tee complete demand constant" {
  let input = dae2_flat_tee_demand_fixture("i32.const 7", tee=true)
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 flat Tee complete demand held-effect" {
  let input = dae2_flat_tee_demand_fixture(
    "local.get 0 local.get 0 call $effect",
    tee=true,
  )
  dae2_flat_tee_complete_compare(input)
  for closed_world in [false, true] {
    let output = dae2_run_module_pass(input, closed_world).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i64_extend_i32s(),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ])
  }
}

///|
test "DAE2 flat Tee complete demand load" {
  let input = dae2_flat_tee_demand_fixture("local.get 0 i32.load", tee=true)
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 flat Tee complete demand store-read-control" {
  let input = dae2_flat_tee_demand_fixture(
    "local.get 0 local.tee 1 drop local.get 1",
    tee=false,
  )
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 flat and suffix Tee overwrite preserve complete source demand" {
  let input = dae2_flat_tee_demand_fixture(
    "local.get 0 local.tee 1 i32.const 7 local.set 1 local.get 1 i32.add",
    tee=false,
  )
  dae2_flat_tee_capture_compare(
    input, "local.get 0 local.tee 1 i32.const 7 local.set 1 local.get 1 i32.add i64.extend_i32_s call $keep",
    "local.get 0 local.tee 1 local.set 2 i32.const 7 local.set 1 local.get 2 local.get 1 i32.add i64.extend_i32_s call $keep",
  )
}

///|
test "DAE2 flattened branchless block Tee keeps complete source demand" {
  let input = dae2_flat_tee_demand_fixture(
    "block (result i32) local.get 0 local.tee 1 end",
    tee=false,
  )
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 flattened branchless block Tee overwrite keeps complete source demand" {
  let input = dae2_flat_tee_demand_fixture(
    "block (result i32) local.get 0 local.tee 1 i32.const 7 local.set 1 local.get 1 i32.add end",
    tee=false,
  )
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 held parameter read uses HOT deferral across repeated effects" {
  let input = dae2_flat_tee_demand_fixture(
    "local.get 0 local.get 0 call $effect local.get 0 call $effect",
  )
  dae2_flat_tee_complete_compare(input)
}

///|
test "DAE2 held parameter read stays before a surviving parameter write" {
  let input = dae2_flat_tee_demand_fixture(
    "local.get 0 i32.const 7 local.set 0 local.get 0 call $effect",
  )
  dae2_flat_tee_capture_compare(
    input, "local.get 0 i32.const 7 local.set 0 local.get 0 call $effect i64.extend_i32_s call $keep",
    "local.get 0 local.set 2 i32.const 7 local.set 0 local.get 0 call $effect local.get 2 i64.extend_i32_s call $keep",
  )
}

///|
test "DAE2 held global and size reads stay before effects" {
  for
    (prefix, declarations) in [
      ("global.get 0", "(global (mut i32) (i32.const 7))"),
      ("memory.size", ""),
      ("table.size 0", "(table 1 funcref)"),
      ("local.get 0 i32.load", ""),
      // This exact divisor is nontrapping; OOB load and imported throws above
      // provide the trap/effect controls.
      ("local.get 0 i32.const 1 i32.div_s", ""),
    ] {
    let input = dae2_flat_tee_demand_fixture(
      "\{prefix} local.get 0 call $effect",
      declarations~,
    )
    dae2_flat_tee_capture_compare(
      input,
      "\{prefix} local.get 0 call $effect i64.extend_i32_s call $keep",
      "\{prefix} local.set 2 local.get 0 call $effect local.get 2 i64.extend_i32_s call $keep",
      declarations~,
    )
  }
}

///|
test "DAE2 suffix builder consumes complete overwritten Tee facts from real solved analysis" {
  let input = dae2_flat_tee_demand_fixture(
    "block (result i32) local.get 0 local.tee 1 i32.const 7 local.set 1 local.get 1 i32.add end",
    tee=false,
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  for closed_world in [false, true] {
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
    let state = Dae2StackSuffixState::new(indices.length(), context~)
    for index in imported..<indices.length() {
      let original = input.code_sec.unwrap().0[index - imported]
      let @lib.Func(_, @lib.Expr(body)) = original
      ignore(
        dae2_collect_control_type_infos(
          body,
          type_infos,
          infos[index].control_type_infos,
          call_infos=Some(infos[index].call_infos),
          suffix_state=Some(state),
          function_index=index,
        ),
      )
      infos[index].call_infos_ready = true
      dae2_pin_flat_observable_params(
        graph, infos, index, body, indices, type_infos, exposure,
      )
      let plan = dae2_raw_dependency_plan(
        graph,
        infos,
        index,
        type_infos,
        original,
        None,
        module_context=Some(context),
      ).unwrap()
      plan.commit(graph)
      infos[index].raw_analysis = true
      infos[index].raw_write_locations = plan.write_locations
    }
    graph.solve()
    dae2_preserve_type_identity(
      input.type_sec.unwrap(),
      graph,
      infos,
      type_infos,
    )
    assert_eq(state.admissions[2], 1)
    let caller_writes = infos[2].raw_write_locations.unwrap()
    let used = graph.used.copy()
    let edges = graph.edges.copy()
    let work = graph.work.copy()
    let direct = dae2_rewrite_stack_suffix_function(
      Dae2StackSuffixPlan::new(graph, infos),
      graph,
      infos[2],
      2,
      input.code_sec.unwrap().0[1],
      state,
    ).unwrap()
    assert_eq(caller_writes.map(fn(write) { (write.0, graph.used[write.1]) }), [
      (1, true),
      (1, true),
    ])
    let analysis = [0]
    let rewrite = [0]
    let actual = dae2_run_module_pass(
      input,
      closed_world,
      analysis_lifts=Some(analysis),
      rewrite_lifts=Some(rewrite),
    ).unwrap()
    @validate.validate_module(actual).unwrap()
    assert_eq(analysis[0], 0)
    assert_eq(rewrite[0], 0)
    assert_eq(
      @ir.hot_module_resolve_func_type(
        @ir.hot_module_context_from_module(actual),
        @lib.FuncIdx::new(1U),
      ),
      Some(@lib.FuncType::new([@lib.ValType::i64()], [@lib.ValType::i64()])),
    )
    // The public path normalizes branchless wrappers after every direct
    // builder. Compare the suffix result after that same required cleanup.
    let cleaned = pass_lower_cleanup_branchless_blocks(
        direct.0,
        actual,
        module_env=Some(@validate.Env::new().with_module(actual)),
        flatten_parameter_blocks=true,
      ).0
    let @lib.Func(direct_locals, @lib.Expr(direct_body)) = cleaned
    let @lib.Func(actual_locals, @lib.Expr(actual_body)) = actual.code_sec.unwrap().0[1]
    assert_eq(direct_body, actual_body)
    assert_eq(direct_locals.length(), actual_locals.length())
    for local_id in 0..<direct_locals.length() {
      assert_eq(direct_locals[local_id], actual_locals[local_id])
    }
    let suffix_bodies = actual.code_sec.unwrap().0.copy()
    suffix_bodies[1] = cleaned
    let suffix_module = actual.with_code_sec(@lib.CodeSec::new(suffix_bodies))
    @validate.validate_module(suffix_module).unwrap()
    assert_eq(
      @binary.encode_module(suffix_module).unwrap(),
      @binary.encode_module(actual).unwrap(),
    )
    assert_eq(direct.1, [0, 1])
    assert_eq(graph.used, used)
    assert_eq(graph.edges, edges)
    assert_eq(graph.work, work)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
  dae2_flat_tee_complete_compare(input)
}
