///|
// Frozen S6 candidate algorithm; only the function and uniform-entry names differ.
fn dae_s10_frozen_discovery_reference(
  mod_ : @lib.Module,
  call_facts : DaeCurrentCallFacts,
  max_def_exclusive : Int32,
  allow_immutable_global_get~ : Bool = false,
) -> Array[Int32] {
  let candidates : Array[Int32] = []
  let imported = dae_imported_func_count(mod_)
  let boundary_facts = dae_call_boundary_facts_from_current(call_facts)
  let type_indices = dae_collect_func_type_indices(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return candidates
  }
  let limit = if max_def_exclusive >= 0 && max_def_exclusive < funcs.length() {
    max_def_exclusive
  } else {
    funcs.length()
  }
  let mut def_idx = 0
  while def_idx < limit {
    let callee_abs = imported + def_idx
    let boundary_candidate = match
      dae_call_boundary_candidate(boundary_facts, callee_abs, def_idx~) {
      Some(candidate) => candidate
      None => {
        def_idx += 1
        continue
      }
    }
    if !boundary_candidate.owned ||
      boundary_candidate.has_self_direct_caller ||
      !boundary_candidate.allows_nonself_direct_rewrite {
      def_idx += 1
      continue
    }
    let func_type = match
      dae_resolve_func_type(mod_, type_indices, callee_abs) {
      Some(ft) => ft
      None => {
        def_idx += 1
        continue
      }
    }
    let @lib.FuncType(params, _) = func_type
    let @lib.Func(locals, _) = funcs[def_idx]
    let local_use = dae_local_use_for_callee(
      funcs[def_idx],
      params.length() + locals.length(),
      callee_abs,
      params.length(),
    )
    let uniform_const_params = dae_s6_uniform_reference_collect_uniform_const_actuals_from_boundary_facts(
      mod_,
      callee_abs,
      params.length(),
      type_indices,
      boundary_facts,
      allow_immutable_global_get~,
    )
    let mut any_const = false
    let mut has_dead_param = false
    let mut p = 0
    while p < params.length() {
      if !local_use.gets[p] {
        has_dead_param = true
      } else if !local_use.writes[p] {
        match uniform_const_params {
          Some(values) =>
            match values[p] {
              Some(_) => any_const = true
              None => ()
            }
          None => ()
        }
      }
      p += 1
    }
    if any_const && !has_dead_param {
      candidates.push(def_idx)
    }
    def_idx += 1
  }
  candidates
}

///|
fn dae_s10_discovery_input(
  calls : Int32,
  dead_forward : Bool,
  catch_wrapped~ : Bool = false,
) -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string("(module (import \"m\" \"tick\" (func $tick)) ")
  if catch_wrapped {
    wat.write_string("(tag $e (param i32)) ")
  }
  wat.write_string(
    "(func $noise) (func $a (param i32) (result i32) local.get 0) (func $b (param i32) (result i32) local.get 0) (func $forward (param i32",
  )
  if dead_forward {
    wat.write_string(" i32")
  }
  wat.write_string(
    ") (result i32) local.get 0 call $a drop local.get 0 call $b) (func (export \"run\") (result i32) ",
  )
  for _ in 0..<calls {
    // Both imported and defined unrelated calls must stay in the module.
    wat.write_string("call $tick call $noise ")
  }
  let actuals = if dead_forward {
    "i32.const 7 i32.const 9 call $forward"
  } else {
    "i32.const 7 call $forward"
  }
  if catch_wrapped {
    wat.write_string("(try (result i32) (do ")
    wat.write_string(actuals)
    wat.write_string(") (catch $e drop ")
    wat.write_string(actuals)
    wat.write_string("))")
  } else {
    wat.write_string(actuals)
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string()).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.targets.keep"), b"unchanged"),
  ])
}

///|
fn dae_s10_single_target_input() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func $h (param i32) (result i32) local.get 0) (func $empty) (func $dead (param i32)) (func $written (param i32) (result i32) i32.const 9 local.set 0 local.get 0) (func (export \"run\") (result i32) call $empty i32.const 7 call $dead i32.const 7 call $written drop i32.const 7 call $h))",
  ).with_custom_secs([
    @lib.CustomSec::new(@lib.Name::new("syntax.targets.keep"), b"unchanged"),
  ])
}

///|
fn dae_s10_assert_discovery_output(
  input : @lib.Module,
  actual : Array[Int32],
  expected : Array[Int32],
  saved : Bytes,
) -> Unit raise {
  assert_eq(actual, expected)
  let graph = dae_current_boundary_graph_new(input)
  let output = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    Array::make(graph.snapshot.defined, false),
    false,
    actual,
  )
  let reference = dae_run_exact_literal_candidate_worklist_with_facts(
    input,
    Array::make(graph.snapshot.defined, false),
    false,
    expected,
  )
  assert_true(output.changed)
  assert_eq(output.productive_defs, reference.productive_defs)
  assert_eq(output.touched, reference.touched)
  assert_eq(output.effects, reference.effects)
  @validate.validate_module(output.mod_out).unwrap()
  assert_eq(
    @binary.encode_module(output.mod_out).unwrap(),
    @binary.encode_module(reference.mod_out).unwrap(),
  )
  let after = dae_current_boundary_graph_new(output.mod_out)
  for def_idx in actual {
    assert_eq(
      after.snapshot.function_types[after.snapshot.imported + def_idx],
      Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
    )
    let @lib.Func(locals, @lib.Expr(body)) = after.snapshot.funcs[def_idx]
    assert_eq(locals.length(), 0)
    let @lib.Func(_, @lib.Expr(before)) = graph.snapshot.funcs[def_idx]
    if before.length() == 1 && before[0] is @lib.LocalGet(_) {
      assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
    }
  }
  assert_eq(output.mod_out.custom_secs, input.custom_secs)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
fn dae_s10_discovery_query(
  input : @lib.Module,
  facts : DaeCurrentCallFacts,
  mode : Int32,
) -> Array[Int32] {
  match mode {
    0 => dae_s10_frozen_discovery_reference(input, facts, -1)
    1 =>
      dae_collect_exact_literal_candidate_defs_with_facts(
        input,
        facts,
        -1,
        indexed_syntax=false,
      )
    _ => dae_collect_exact_literal_candidate_defs_with_facts(input, facts, -1)
  }
}

///|
fn dae_s10_single_wide_target_input() -> @lib.Module {
  let wat = StringBuilder::new()
  wat.write_string(
    "(module (func $h (param i32 i32 i32 i32 i32 i32 i32 i32) (result i32) local.get 0 ",
  )
  for p in 1..<8 {
    wat.write_string("local.get ")
    wat.write_string(p.to_string())
    wat.write_string(" i32.add ")
  }
  // The dead ninth parameter makes only h eligible, while all eight forwarded
  // values can revisit the same caller. This guards the single-target cutoff.
  wat.write_string(
    ") (func $forward (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) ",
  )
  for p in 0..<8 {
    wat.write_string("local.get ")
    wat.write_string(p.to_string())
    wat.write_string(" ")
  }
  wat.write_string("call $h) (func (export \"run\") (result i32) ")
  for _ in 0..<9 {
    wat.write_string("i32.const 7 ")
  }
  wat.write_string("call $forward))")
  pass_test_module_from_wat(wat.to_string())
}
