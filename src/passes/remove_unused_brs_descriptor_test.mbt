///|
test "remove-unused-brs descriptor declares directly required analyses" {
  // Direct pass_require_cfg and pass_require_use_def calls need metadata too.
  @debug.assert_eq(@ir.hot_pass_requires(remove_unused_brs_descriptor()), [
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::use_def(),
  ])
}
