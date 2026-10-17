///|
/// The production proof path has no recorder or user callback. This checks
/// its actual two-removal result against the chain-less complete-gate route;
/// the separate instrumented main-route test establishes selected work.
test "numeric result main core keeps exact behavior without any work recorder" {
  let input = dae_numeric_result_validation_fixture()
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let reference_options = HotPipelineOptions::new()
  let expected = dae_run_core(input, reference_options.trace)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let options = HotPipelineOptions::new()
  let proof = hot_pipeline_dae_no_callback_trace(options)
  assert_true(proof is Some(_))
  let actual = dae_run_core(input, options.trace, no_callback_trace=proof)
  assert_true(actual.changed)
  assert_eq(actual.changed, expected.changed)
  assert_eq(actual.effects, expected.effects)
  assert_eq(actual.touched, expected.touched)
  assert_eq(actual.touched, [false, true, true, false])
  assert_eq(
    @binary.encode_module(actual.mod_out).unwrap(),
    @binary.encode_module(expected.mod_out).unwrap(),
  )
  for target in [0, 1] {
    assert_eq(dae_numeric_result_validation_results(actual.mod_out, target), 0)
    assert_eq(dae_wb_param_count(actual.mod_out, target), 1)
    assert_true(actual.effects.result_removed[target])
    assert_true(actual.effects.result_changed[target])
    let @lib.Func(_, @lib.Expr(body)) = actual.mod_out.code_sec.unwrap().0[target]
    assert_true(
      body.contains(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U))),
    )
  }
  @validate.validate_module(actual.mod_out).unwrap()
  @validate.validate_module(expected.mod_out).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
/// Every row starts with two real productive numeric commits. The second
/// commit builds a real syntax index. Only the private boundary record/source
/// is then perturbed; no new producer or aliased IR write is certified.
test "numeric result report guard keeps only the exact successful numeric record" {
  for fault in 0..<9 {
    let input = dae_numeric_result_validation_fixture()
    let saved = @binary.encode_module(input).unwrap()
    let chain = dae_scalar_validation_test_chain()
    let work = DaeScalarValidationWork::new()
    let first = dae_numeric_result_v2_step(input, 0, chain, work)
    let first_saved = @binary.encode_module(first.result.mod_out).unwrap()
    let second = dae_numeric_result_v2_step(
      first.result.mod_out,
      1,
      chain,
      work,
    )
    let result = second.result
    let exact_report : DaeCoreResultApplication = {
      mod_out: result.mod_out,
      touched: result.touched,
      changed: result.changed,
      applied: second.applied,
      primary_def: result.primary_def,
      effects: second.effects,
    }
    assert_eq(dae_numeric_result_validation_results(result.mod_out, 0), 0)
    assert_eq(dae_numeric_result_validation_results(result.mod_out, 1), 0)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    @validate.validate_module(result.mod_out).unwrap()
    assert_true(chain.numeric_result_source)
    assert_true(chain.no_callback is Some(_))
    let checked = chain.checked_source.unwrap()
    let index = chain.syntax_index.unwrap()
    assert_true(physical_equal(checked, result.mod_out))
    assert_eq(
      dae_work_family_for_commit_effects(
        exact_report.effects,
        exact_report.primary_def,
      ),
      DaeDroppedResultWork,
    )
    // A fresh wrapper has equal encoded values but a different module object.
    let wrapped = result.mod_out.with_code_sec(result.mod_out.code_sec.unwrap())
    assert_false(physical_equal(wrapped, result.mod_out))
    assert_eq(
      @binary.encode_module(wrapped).unwrap(),
      @binary.encode_module(result.mod_out).unwrap(),
    )
    let report : DaeCoreResultApplication = match fault {
      1 => { ..exact_report, primary_def: 0, }
      2 => { ..exact_report, mod_out: wrapped, }
      3 => { ..exact_report, effects: dae_commit_effects_empty(4), }
      6 => { ..exact_report, applied: false, }
      7 => { ..exact_report, changed: false, }
      _ => exact_report
    }
    if fault == 4 {
      chain.checked_source = Some(wrapped)
    } else if fault == 5 {
      chain.checked_source = None
    }
    let presented_result = if fault == 8 {
      { ..result, changed: false, }
    } else {
      result
    }
    let result_saved = @binary.encode_module(result.mod_out).unwrap()
    dae_numeric_result_validation_retain_report(
      Some(chain),
      presented_result,
      report,
    )
    if fault == 0 {
      assert_true(chain.numeric_result_source)
      assert_true(physical_equal(chain.checked_source.unwrap(), checked))
      assert_true(physical_equal(chain.syntax_index.unwrap(), index))
    } else {
      assert_true(chain.checked_source is None)
      assert_true(chain.syntax_index is None)
      assert_false(chain.numeric_result_source)
    }
    assert_eq(@binary.encode_module(result.mod_out).unwrap(), result_saved)
    assert_eq(@binary.encode_module(first.result.mod_out).unwrap(), first_saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    @validate.validate_module(result.mod_out).unwrap()
    // Counts below show this was a real numeric lifetime before perturbation.
    assert_eq(work.full_gates, 1)
    assert_eq(work.full_bodies, 4)
    assert_eq(work.partial_gates, 1)
    assert_eq(work.partial_bodies, 2)
    assert_eq(work.matched_sources, 1)
    assert_eq(work.envelope_matches, 1)
    assert_eq(work.index_builds, 1)
  }
}
