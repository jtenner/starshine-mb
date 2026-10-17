///|
fn dae2_validate_final_candidate(
  candidate : @lib.Module,
  validation_calls : Array[Int32]?,
  perf : HotPerfSession?,
) -> Result[Unit, String] {
  if validation_calls is Some(calls) {
    calls[0] += 1
  }
  let start = perf_start_timer_opt(perf, "detail:dae2:finalize:validate")
  let result = @validate.validate_module(candidate)
  perf_stop_timer_opt(perf, "detail:dae2:finalize:validate", start)
  match result {
    Ok(_) => Ok(())
    Err(error) => Err("dae2: invalid rewritten module: \{error}")
  }
}

///|
fn dae2_finalize_candidate(
  candidate : @lib.Module,
  validation_calls~ : Array[Int32]? = None,
  perf~ : HotPerfSession? = None,
) -> Result[@lib.Module, String] {
  // Retain the original validation order for compiler facts and raw payloads.
  if candidate.raw_name_sec_payload is Some(_) ||
    candidate.compiler_fact_custom_section is Some(_) {
    match dae2_validate_final_candidate(candidate, validation_calls, perf) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    return Ok(
      dfe_cleanup_simple_type_encoding(
        dae_prune_unused_simple_func_types(candidate, preserve_names=true),
      ),
    )
  }
  let grouped = dae_prune_unused_simple_func_types(
    candidate,
    preserve_names=true,
  )
  let encoding_candidate = dfe_cleanup_simple_type_encoding_candidate(grouped)
  let selected = encoding_candidate.unwrap_or(grouped)
  if !physical_equal(selected, candidate) {
    // An unused malformed declaration must not disappear before validation.
    // Types are the first full-validation phase, with this exact error text.
    // An unchanged candidate receives the same check in its full gate below.
    match @validate.validate_typesec(candidate.type_sec, @validate.Env::new()) {
      Ok(_) => ()
      Err(error) => return Err("dae2: invalid rewritten module: \{error}")
    }
    if candidate.name_sec is Some(_) {
      match @validate.validate_module_name_section(candidate) {
        Ok(_) => ()
        Err(_) =>
          // Cleanup may erase invalid names. Preserve body-before-name error
          // priority by checking the original module on this cold path.
          match
            dae2_validate_final_candidate(candidate, validation_calls, perf) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
      }
    }
  }
  match dae2_validate_final_candidate(selected, validation_calls, perf) {
    Ok(_) => Ok(selected)
    Err(error) => {
      // Remapped operands may change diagnostic text. Preserve the original
      // first error on invalid input instead of reporting the speculative one.
      match dae2_validate_final_candidate(candidate, validation_calls, perf) {
        Err(original_error) => return Err(original_error)
        Ok(_) => ()
      }
      // Match DFE's validating wrapper: an invalid encoding candidate rolls
      // back to its grouped input. Check that exact fallback before returning.
      if encoding_candidate is Some(_) {
        match dae2_validate_final_candidate(grouped, validation_calls, perf) {
          Ok(_) => Ok(grouped)
          Err(fallback_error) => Err(fallback_error)
        }
      } else {
        Err(error)
      }
    }
  }
}
