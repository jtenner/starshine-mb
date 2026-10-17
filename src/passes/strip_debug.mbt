// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
pub fn strip_debug_summary() -> String {
  "Remove the structured/raw name section payload while preserving other custom sections."
}

///|
pub fn strip_debug_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  if mod_.custom_secs.length() == 0 &&
    mod_.name_sec is None &&
    mod_.raw_name_sec_payload is None {
    return mod_
  }
  mod_.without_name_sec()
}
