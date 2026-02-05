
pub (all) enum ModulePass {
  AbstractTypeRefining(AbstractTypeRefiningPassProps)
  AlignmentLowering
}

pub fn optimize_module(mod : Module, passes : Array[ModulePass]) -> Result[Module, String] {
  let mut mod = mod
  let ctx = IRContext::new()
  ctx.set_mod(mod)

  match lift_to_texpr_pass().walk_module((), mod) {
    Ok(Some((_, mod))) => {
      ctx.set_mod(mod)
    }
    Ok(None) => ()
    Err(e) => return Err(e)
  }

  for pass in passes {
    ctx.set_mod(mod)
    let pass = match pass {
      AbstractTypeRefining(props) => 
        abstract_type_refining(mod, props.traps_never_happen)
      AlignmentLowering => alignment_lowering_pass(mod)
    }

    match pass.walk_module(ctx, mod) {
      Ok(Some((_, final_mod))) => {
        mod = final_mod
        ctx.set_mod(final_mod)
      }
      Ok(None) => ()
      Err(e) => return Err(e)
    }
  }
  Ok(mod)
}
