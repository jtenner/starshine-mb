// Bounded coverage for C3 candidate validation ordering.
// The invalid candidates below are intentionally unsupported intermediate
// modules. They test validated fallback; they are not accepted optimizations.

///|
// Frozen pre-change ordering over prebuilt candidate references. This is the
// selection performed by the old cleanup, with candidate building kept outside.
fn oi_local_candidate_frozen_select(
  before : @lib.Module,
  grouped : @lib.Module,
  frequency : @lib.Module?,
) -> @lib.Module {
  let baseline = if before.compiler_fact_custom_section is Some(_) {
    before.without_compiler_fact_custom_section()
  } else {
    before
  }
  let mut best = before
  if !physical_equal(grouped, before) {
    match @binary.encoded_module_sizes(baseline, grouped) {
      Ok((old_size, new_size)) if new_size < old_size =>
        if oi_validate_local_group_changed_bodies(before, grouped) {
          best = grouped
        }
      _ => ()
    }
  }
  match frequency {
    Some(candidate) if !physical_equal(candidate, before) => {
      let cost_before = if physical_equal(best, before) {
        baseline
      } else {
        best
      }
      match @binary.encoded_module_sizes(cost_before, candidate) {
        Ok((old_size, new_size)) if new_size < old_size =>
          if oi_validate_local_group_changed_bodies(before, candidate) {
            return candidate
          }
        _ => ()
      }
    }
    _ => ()
  }
  best
}

///|
fn oi_local_candidate_triplet() -> (@lib.Module, @lib.Module, @lib.Module) {
  let before = encoded_profitability_local_fixture()
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(before)
  let frequency = reorder_locals_run_module_pass(before)
  (before, grouped, frequency)
}

///|
fn oi_local_candidate_replace_body(
  candidate : @lib.Module,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let @lib.Func(locals, _) = candidate.code_sec.unwrap().0[0]
  candidate.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
}

///|
fn oi_local_candidate_invalid_group(grouped : @lib.Module) -> @lib.Module {
  let @lib.Func(_, @lib.Expr(body)) = grouped.code_sec.unwrap().0[0]
  let next : Array[@lib.Instruction] = []
  let mut removed = 0
  for instr in body {
    if instr is @lib.Drop && removed < 5 {
      removed += 1
    } else {
      next.push(instr)
    }
  }
  // Intentionally invalid: five values remain on a void function's stack.
  oi_local_candidate_replace_body(grouped, next)
}

///|
fn oi_local_candidate_invalid_frequency(frequency : @lib.Module) -> @lib.Module {
  let @lib.Func(_, @lib.Expr(body)) = frequency.code_sec.unwrap().0[0]
  let next = body.copy()
  // Intentionally invalid: an extra result remains in a void function.
  next.push(@lib.Instruction::i32_const(@lib.I32(0)))
  oi_local_candidate_replace_body(frequency, next)
}

///|
fn oi_local_candidate_check_result(
  before : @lib.Module,
  grouped : @lib.Module,
  frequency : @lib.Module?,
  expected : @lib.Module,
) -> Unit raise {
  // Preserve the frozen old selection contract after deferring validation.
  let old = oi_local_candidate_frozen_select(before, grouped, frequency)
  let selected = oi_select_local_group_candidate(before, grouped, frequency)
  assert_true(physical_equal(old, expected))
  assert_true(physical_equal(selected, expected))
  assert_eq(
    @binary.encode_module(selected).unwrap(),
    @binary.encode_module(old).unwrap(),
  )
  ignore(@validate.validate_module(selected).unwrap())
}

///|
test "OI selection rejects intentionally invalid cheaper grouping and uses valid frequency" {
  let (before, grouped, frequency) = oi_local_candidate_triplet()
  let invalid = oi_local_candidate_invalid_group(grouped)
  assert_eq(encoded_profitability_size(before), 185)
  assert_eq(encoded_profitability_size(grouped), 183)
  assert_eq(encoded_profitability_size(frequency), 179)
  assert_eq(encoded_profitability_size(invalid), 178)
  assert_true(@validate.validate_module(invalid) is Err(_))
  assert_false(oi_validate_local_group_changed_bodies(before, invalid))
  oi_local_candidate_check_result(before, invalid, Some(frequency), frequency)
}

///|
test "OI selection rejects intentionally invalid cheaper frequency and uses valid grouping" {
  let (before, grouped, frequency) = oi_local_candidate_triplet()
  let invalid = oi_local_candidate_invalid_frequency(frequency)
  assert_eq(encoded_profitability_size(invalid), 181)
  assert_true(
    encoded_profitability_size(invalid) < encoded_profitability_size(grouped),
  )
  assert_true(@validate.validate_module(invalid) is Err(_))
  assert_false(oi_validate_local_group_changed_bodies(before, invalid))
  oi_local_candidate_check_result(before, grouped, Some(invalid), grouped)
}

///|
test "OI selection retains original identity when both candidates are intentionally invalid" {
  let (before, grouped, frequency) = oi_local_candidate_triplet()
  let invalid_group = oi_local_candidate_invalid_group(grouped)
  let invalid_frequency = oi_local_candidate_invalid_frequency(frequency)
  assert_true(@validate.validate_module(invalid_group) is Err(_))
  assert_true(@validate.validate_module(invalid_frequency) is Err(_))
  assert_false(oi_validate_local_group_changed_bodies(before, invalid_group))
  assert_false(
    oi_validate_local_group_changed_bodies(before, invalid_frequency),
  )
  let bytes = @binary.encode_module(before).unwrap()
  oi_local_candidate_check_result(
    before,
    invalid_group,
    Some(invalid_frequency),
    before,
  )
  assert_eq(@binary.encode_module(before).unwrap(), bytes)
}

///|
test "OI selection keeps grouping preference on equal profitable candidate sizes" {
  let (before, grouped, _) = oi_local_candidate_triplet()
  let @lib.Func(_, @lib.Expr(body)) = grouped.code_sec.unwrap().0[0]
  let next = body.copy()
  // The first read is i32 local 127 (two opcode/immediate bytes). A dropped
  // i32.const 0 has the same encoded length and the same void-function result.
  next[0] = @lib.Instruction::i32_const(@lib.I32(0))
  let tied = oi_local_candidate_replace_body(grouped, next)
  assert_eq(
    encoded_profitability_size(grouped),
    encoded_profitability_size(tied),
  )
  assert_true(
    encoded_profitability_size(grouped) < encoded_profitability_size(before),
  )
  ignore(@validate.validate_module(tied).unwrap())
  oi_local_candidate_check_result(before, grouped, Some(tied), grouped)
}

///|
test "OI selection retains original identity on unchanged and equal-original candidates" {
  let (before, _, _) = oi_local_candidate_triplet()
  let @lib.Func(_, @lib.Expr(body)) = before.code_sec.unwrap().0[0]
  let equal_original = oi_local_candidate_replace_body(before, body.copy())
  assert_eq(
    encoded_profitability_size(equal_original),
    encoded_profitability_size(before),
  )
  oi_local_candidate_check_result(before, before, None, before)
  oi_local_candidate_check_result(
    before,
    equal_original,
    Some(equal_original),
    before,
  )
  let comparisons = [0]
  let untouched = oi_group_numeric_locals_if_smaller(
    before,
    touched=Some([false]),
    function_comparisons=Some(comparisons),
  )
  assert_true(physical_equal(untouched, before))
  assert_eq(comparisons[0], 0)
}

///|
test "OI current and frozen cleanup retain the smaller frequency candidate" {
  let (before, grouped, frequency) = oi_local_candidate_triplet()
  let original_bytes = @binary.encode_module(before).unwrap()
  let expected = @binary.encode_module(frequency).unwrap()
  assert_true(expected.length() < encoded_profitability_size(grouped))
  for
    selected in [
      oi_group_numeric_locals_if_smaller_frozen_c3(before),
      oi_group_numeric_locals_if_smaller(before),
      oi_cleanup_module_encoding_frozen_c3(before),
      oi_cleanup_module_encoding(before),
    ] {
    ignore(@validate.validate_module(selected).unwrap())
    assert_eq(@binary.encode_module(selected).unwrap(), expected)
  }
  assert_eq(@binary.encode_module(before).unwrap(), original_bytes)
}
