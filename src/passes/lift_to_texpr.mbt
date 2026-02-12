///|
fn lift_to_texpr_pass() -> ModuleTransformer[Unit] {
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

///|
test "lift_to_texpr_pass expands grouped locals when lifting Func" {
  let func = Func::new(
    [Locals::new(2, ValType::i32())],
    Expr::new([Instruction::local_get(LocalIdx::new(1)), Instruction::drop()]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = lift_to_texpr_pass()
  let result = pass.walk_module((), mod)
  match result {
    Ok(Some((_, new_mod))) =>
      match new_mod.code_sec {
        Some(CodeSec([TFunc(locals, _)])) => assert_eq(locals.length(), 2)
        _ => fail("expected lifted TFunc with expanded locals")
      }
    Ok(None) => fail("expected module change")
    Err(e) => fail("unexpected lift_to_texpr_pass error: \{e}")
  }
}
