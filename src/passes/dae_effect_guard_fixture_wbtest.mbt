///|
fn dae_effect_guard_fixture() -> (@lib.Module, @lib.Module) {
  (
    pass_test_module_from_wat(
      "(module (func $h (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) i32.const 7 call $h) (func (result f64) f64.const nan:0x123456))",
    ),
    pass_test_module_from_wat(
      "(module (func $h (result i32) i32.const 7) (func (export \"run\") (result i32) call $h) (func (result f64) f64.const nan:0x123456))",
    ).without_name_sec(),
  )
}

///|
fn dae_effect_guard_families() -> Array[DaeWorkFamily] {
  [
    DaeUnusedParameterWork,
    DaeUniformActualWork,
    DaeLocalizationRetryWork,
    DaeGcParameterRefinementWork,
    DaeGcResultRefinementWork,
    DaeDroppedResultWork,
    DaeControlReconstructionWork,
    DaeTypeRepairRetryWork,
    DaeForwardingWork,
    DaeBodyCleanupWork,
    DaePostCleanupBoundaryRevisitWork,
  ]
}

///|
fn dae_effect_guard_uses_other_bodies(family : DaeWorkFamily) -> Bool {
  match family {
    DaeLocalizationRetryWork
    | DaeGcResultRefinementWork
    | DaeDroppedResultWork => true
    _ => false
  }
}
