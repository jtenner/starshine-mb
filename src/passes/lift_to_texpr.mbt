pub fn lift_to_texpr_pass() -> @lib.ModuleTransformer[Unit] {
  @lib.ModuleTransformer::{
    ..@lib.ModuleTransformer::new(),
    on_func: Some(fn (_ : Unit, f : @lib.Func) -> @lib.TransformerResult[Unit, @lib.Func] {
      match f {
        Func(l, t) => match @lib.expr_to_texpr(t, @lib.Env::new()) {
          Ok(t) => match @lib.expand_locals(l) {
            Ok(l) => @lib.change((), @lib.TFunc(l, t))
            Err(t) => Err(t)
          }
          Err(t) => Err(t)
        }
        TFunc(_, _) => @lib.unchanged()
      }
    })
  }
}