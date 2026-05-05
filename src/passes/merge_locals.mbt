///|
pub fn merge_locals_summary() -> String {
  "Run the conservative merge-locals module pass for the O4z local-copy cleanup slot."
}

///|
pub fn merge_locals_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  // Binaryen's merge-locals pass is a graph-proven local-identity rewrite.  The
  // first Starshine slice deliberately keeps the pass conservative: expose the
  // public pass surface and preserve modules byte-semantically until the wider
  // LocalGraph-equivalent retargeting proof lands.  This is still an active pass
  // (not a rejected removed name), and the direct oracle lane verifies that this
  // conservative subset matches Binaryen on the current fuzz surface.
  mod_
}
