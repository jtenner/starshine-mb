// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// Group only after repaired writeback, so restored functions keep their indices.
fn simplify_locals_cleanup_module_encoding(
  mod_ : @lib.Module,
  touched~ : Array[Bool]? = None,
  perf~ : HotPerfSession? = None,
) -> @lib.Module {
  let control_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-control-type",
  )
  let cleaned = pass_cleanup_control_and_type_encoding(mod_, touched~, perf~)
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-control-type", control_start,
  )
  let grouping_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group",
  )
  let grouped = oi_group_numeric_locals_if_smaller(cleaned, touched~, perf~)
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-local-group", grouping_start,
  )
  grouped
}
