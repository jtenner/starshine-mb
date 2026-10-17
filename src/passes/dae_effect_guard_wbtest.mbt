///|
/// Compare every effect field and both source modules before the final work
/// assertion. The counter is at the actual Eq site in this private shadow.
/// Normal production has no counter. Source stripping binds the WB probe to
/// the current normal function. A future normal-only performance reversion
/// can keep behavior and this copied probe GREEN; rerun source binding and
/// the ordinary compiled-work proof to detect that performance-only change.
test "DAE effect fields match frozen behavior and the source-bound copied work probe" {
  let (input, output) = dae_effect_guard_fixture()
  let input_bytes = @binary.encode_module(input).unwrap()
  let output_bytes = @binary.encode_module(output).unwrap()
  let graph = dae_current_boundary_graph_new(input)
  let dependencies = dae_boundary_dependency_graph_new(graph)
  let records : Array[Array[Int32]] = []
  for family in dae_effect_guard_families() {
    for target in [-1, 0, 2, 3] {
      for changed in [false, true] {
        // The last replacement intentionally lacks the original functions.
        // Effect collection must still match its frozen pre-validation rule.
        for next in [output, input, @lib.Module::new()] {
          let next_bytes = @binary.encode_module(next).unwrap()
          let touched = [true, true, false]
          let candidate : DaePassResult = {
            mod_out: next,
            touched,
            changed,
            primary_def: target,
          }
          let item = dae_work_item_new(graph, dependencies, target, family)
          let count = [0]
          let actual = dae_work_item_candidate_effects(
            input, graph, item, candidate,
          )
          let observed = dae_effect_guard_probe_candidate_effects(
            input,
            graph,
            item,
            candidate,
            row_comparisons=Some(count),
          )
          assert_eq(observed, actual)
          let expected = dae_effect_guard_frozen_candidate_effects(
            input, graph, item, candidate,
          )
          // Derived Eq covers every field, including complete invalidation and
          // reason arrays. This does not substitute a copy of effect logic.
          assert_eq(actual, expected)
          assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
          assert_eq(@binary.encode_module(output).unwrap(), output_bytes)
          assert_eq(@binary.encode_module(next).unwrap(), next_bytes)
          assert_eq(touched, [true, true, false])
          if !changed {
            assert_eq(actual, dae_commit_effects_empty(3))
          }
          if changed && physical_equal(next, output) {
            assert_true(actual.invalidation_domains.contains(DaeInvalidateBody))
            if target == 0 {
              assert_true(actual.parameter_changed[0])
            }
          }
          if changed && physical_equal(next, input) {
            // The first-loop exact body facts stay unchanged for retained NaN
            // bytes. The existing numeric Eq decisions below stay unchanged.
            assert_false(
              actual.invalidation_domains.contains(DaeInvalidateBody),
            )
            if target == 2 {
              match family {
                DaeUnusedParameterWork
                | DaeUniformActualWork
                | DaeLocalizationRetryWork
                | DaeGcParameterRefinementWork
                | DaeGcResultRefinementWork
                | DaeDroppedResultWork
                | DaePostCleanupBoundaryRevisitWork =>
                  assert_true(actual.worth_optimizing[2])
                _ => ()
              }
            }
          }
          let available = match next.code_sec {
            Some(@lib.CodeSec(funcs)) => funcs.length().min(3)
            None => 0
          }
          let needed = if changed && dae_effect_guard_uses_other_bodies(family) {
            available - (if target >= 0 && target < available { 1 } else { 0 })
          } else {
            0
          }
          records.push([dae_work_family_slot(family), target, count[0], needed])
        }
      }
    }
  }
  @validate.validate_module(input).unwrap()
  @validate.validate_module(output).unwrap()
  // The copied-probe work model follows all behavior and ownership checks.
  // Unused families require zero Eq calls. Used families exclude the target
  // before Eq and preserve all remaining numeric NaN comparison decisions.
  for row in records {
    if row[2] != row[3] {
      fail(
        "copied-probe second-loop Eq calls violate required work: family,target,actual,required=\{row}",
      )
    }
  }
}
