///|
fn lower_to_expr_pass() -> ModuleTransformer[Unit] {
  ModuleTransformer::new().on_func_evt(fn(
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
  })
}

///|
fn run_lower_to_expr_pass(mod : Module) -> Module {
  let t = lower_to_expr_pass()
  let (_, mod) = t.walk_module((), mod).unwrap().unwrap()
  mod
}

///|
test "run_lower_to_expr_pass converts TFunc locals into grouped locals" {
  let func = Func::t_func(
    [ValType::i32(), ValType::i32(), ValType::f64()],
    TExpr::new([TInstr::nop()]),
  )
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let lowered = run_lower_to_expr_pass(mod)
  match lowered.code_sec {
    Some(CodeSec([Func(locals, _)])) => {
      assert_eq(locals.length(), 2)
      match locals[0] {
        Locals(n, vt) => {
          assert_eq(n.reinterpret_as_int(), 2)
          assert_eq(vt, ValType::i32())
        }
      }
    }
    _ => fail("expected lowered Func with grouped locals")
  }
}
