///|
pub fn lower_to_expr_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn(
      _ : ModuleTransformer[Unit],
      _ : Unit,
      f : Func,
    ) -> TransformerResult[Unit, Func] {
      match f {
        TFunc(l, t) => {
          let locals = tlocals_to_locals(l)
          let expr = t.to_expr()
          change((), Func::new(locals, expr))
        }
        Func(_, _) => unchanged()
      }
    }),
  }
}

///|
pub fn run_lower_to_expr_pass(mod : Module) -> Module {
  let t = lower_to_expr_pass()
  let (_, mod) = t.walk_module((), mod).unwrap().unwrap()
  mod
}
