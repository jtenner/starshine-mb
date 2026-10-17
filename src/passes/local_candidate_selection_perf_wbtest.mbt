///|
fn oi_local_candidate_perf_input() -> @lib.Module {
  let seed = encoded_profitability_local_fixture()
  let func = seed.code_sec.unwrap().0[0]
  seed
  .with_func_sec(@lib.FuncSec::new(Array::make(1000, @lib.TypeIdx::new(0U))))
  .with_code_sec(@lib.CodeSec::new(Array::make(1000, func)))
}

///|
fn oi_local_candidate_measure(
  retention : @bench.T,
  run : (Bool) -> @lib.Module,
  reference : Bool,
  repetitions : Int32,
  initial : @lib.Module,
) -> (UInt64, @lib.Module) {
  let mut result = initial
  let start = @lib.trace_now_us()
  for _ in 0..<repetitions {
    result = run(reference)
    retention.keep(result)
  }
  let elapsed = @lib.trace_elapsed_us_since(start)
  (elapsed, result)
}

///|
fn oi_local_candidate_paired_samples(actual_cleanup : Bool) -> Unit raise {
  let before = oi_local_candidate_perf_input()
  let original = @binary.encode_module(before).unwrap()
  ignore(@validate.validate_module(before).unwrap())
  let grouped = run_hot_pipeline_raw_group_body_locals_by_type_module(before)
  let frequency = reorder_locals_run_module_pass(before)
  ignore(@validate.validate_module(grouped).unwrap())
  ignore(@validate.validate_module(frequency).unwrap())
  let expected = @binary.encode_module(frequency).unwrap()
  let run = fn(reference : Bool) {
    if actual_cleanup {
      if reference {
        oi_cleanup_module_encoding_frozen_c3(before)
      } else {
        oi_cleanup_module_encoding(before)
      }
    } else if reference {
      oi_local_candidate_frozen_select(before, grouped, Some(frequency))
    } else {
      oi_select_local_group_candidate(before, grouped, Some(frequency))
    }
  }
  // Validate output and exact byte identity before any calibration or sample.
  for reference in [true, false] {
    let result = run(reference)
    ignore(@validate.validate_module(result).unwrap())
    assert_eq(@binary.encode_module(result).unwrap(), expected)
  }
  assert_true(expected.length() < original.length())
  // Use one fixed batch size for both variants and all seven raw samples.
  // Calibration is separate and discarded. Both batches target >=20ms.
  let retention = @bench.Bench()
  let mut repetitions = 1
  let mut reference_calibration = 0UL
  let mut candidate_calibration = 0UL
  while true {
    let (old_time, _) = oi_local_candidate_measure(
      retention, run, true, repetitions, before,
    )
    let (new_time, _) = oi_local_candidate_measure(
      retention, run, false, repetitions, before,
    )
    reference_calibration = old_time
    candidate_calibration = new_time
    if (old_time >= 20000UL && new_time >= 20000UL) || repetitions >= 256 {
      break
    }
    repetitions *= 2
  }
  assert_true(reference_calibration > 0UL && candidate_calibration > 0UL)
  let label = if actual_cleanup { "cleanup" } else { "selector" }
  println(
    "OI local cost kind=\{label} functions=1000 repetitions=\{repetitions} calibration_reference_us=\{reference_calibration} calibration_candidate_us=\{candidate_calibration} output_bytes=\{expected.length()}",
  )
  let reference_samples : Array[UInt64] = []
  let candidate_samples : Array[UInt64] = []
  for sample in 0..<7 {
    let outputs : Array[@lib.Module] = []
    for
      reference in (if sample % 2 == 0 { [true, false] } else { [false, true] }) {
      let (elapsed, result) = oi_local_candidate_measure(
        retention, run, reference, repetitions, before,
      )
      outputs.push(result)
      if reference {
        reference_samples.push(elapsed)
      } else {
        candidate_samples.push(elapsed)
      }
      println(
        "OI local cost kind=\{label} raw=\{sample} reference=\{reference} repetitions=\{repetitions} elapsed_us=\{elapsed}",
      )
    }
    // Keep validation and encoding outside both timed batches in each pair.
    for result in outputs {
      ignore(@validate.validate_module(result).unwrap())
      assert_eq(@binary.encode_module(result).unwrap(), expected)
    }
  }
  assert_eq(reference_samples.length(), 7)
  assert_eq(candidate_samples.length(), 7)
  assert_eq(@binary.encode_module(before).unwrap(), original)
  println(
    "OI local cost kind=\{label} reference_us=\{reference_samples} candidate_us=\{candidate_samples}",
  )
}

///|
#skip("manual paired native-release C3 selector samples; no default stress")
test "OI local candidate selector paired seven native raw samples" {
  oi_local_candidate_paired_samples(false)
}

///|
#skip("manual paired native-release C3 actual cleanup samples; no default stress")
test "OI local module cleanup paired seven native raw samples" {
  oi_local_candidate_paired_samples(true)
}
