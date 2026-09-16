///|
// Run after all writeback repair: restored functions still use original indices.
fn oi_cleanup_module_encoding(mod_ : @lib.Module) -> @lib.Module {
  pass_cleanup_unused_type_groups(mod_)
}
