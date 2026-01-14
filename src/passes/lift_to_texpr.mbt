///|
pub fn lift_to_texpr_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn(
      _ : ModuleTransformer[Unit],
      _ : Unit,
      f : @lib.Func,
    ) -> TransformerResult[Unit, @lib.Func] {
      match f {
        Func(l, t) =>
          match t.to_texpr(Env::new()) {
            Ok(t) =>
              match expand_locals(l) {
                Ok(l) => change((), @lib.TFunc(l, t))
                Err(t) => Err(t)
              }
            Err(t) => Err(t)
          }
        TFunc(_, _) => unchanged()
      }
    }),
  }
}
