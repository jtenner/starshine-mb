///|
fn cmd_extract_proposal_feature_flags(
  args : Array[String],
) -> (Array[String], Array[@validate.ProposalFeature]) {
  let filtered : Array[String] = []
  let mut disabled : Array[@validate.ProposalFeature] = []
  for arg in args {
    if arg == "all-features" {
      disabled = []
      continue
    }
    let mut handled = false
    for feature in @validate.controlled_proposal_features() {
      let name = @validate.proposal_feature_name(feature)
      if arg == "disable-" + name {
        if !disabled.contains(feature) {
          disabled.push(feature)
        }
        handled = true
      } else if arg == "enable-" + name {
        disabled = disabled.filter(fn(other) { other != feature })
        handled = true
      }
    }
    if !handled {
      filtered.push(arg)
    }
  }
  (filtered, disabled)
}

///|
fn cmd_validate_proposal_features(
  mod_ : Module,
  disabled : Array[@validate.ProposalFeature],
) -> Result[Unit, CmdError] {
  if disabled.is_empty() {
    return Ok(())
  }
  match @validate.validate_module(mod_, disabled_features=disabled) {
    Ok(_) => Ok(())
    Err(err) =>
      Err(CmdError::OptimizeFailed(@validate.validation_error_message(err)))
  }
}
