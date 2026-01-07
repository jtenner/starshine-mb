///|
using @lib {
  type Env,
  expr_to_texpr,
  expand_locals,
  type ModuleTransformer,
  type TransformerResult,
  change,
  unchanged,
}

///|
pub fn lift_to_texpr_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn(
      _ : Unit,
      f : @lib.Func,
    ) -> TransformerResult[Unit, @lib.Func] {
      match f {
        Func(l, t) =>
          match expr_to_texpr(t, Env::new()) {
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
