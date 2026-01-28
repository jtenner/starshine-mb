///|
pub fn lift_to_texpr_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::new().on_func_evt(fn(
    _ : ModuleTransformer[Unit],
    _ : Unit,
    f : Func,
  ) -> TransformerResult[Unit, Func] {
    match f {
      Func(l, t) =>
        match to_texpr(t, Env::new()) {
          Ok(t) =>
            match expand_locals(l) {
              Ok(l) => change((), Func::t_func(l, t))
              Err(t) => Err(t)
            }
          Err(t) => Err(t)
        }
      TFunc(_, _) => unchanged()
    }
  })
}
