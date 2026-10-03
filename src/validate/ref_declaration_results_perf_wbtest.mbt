///|
fn ref_decl_boxed_reference_instr(
  instr : Instruction,
  env : Env,
  declared : @bitset.BitSet,
) -> Result[Unit, String] {
  match instr {
    RefFunc(f) => {
      if env.has_func(f) && !is_declared_ref_func(declared, f) {
        return Err("undeclared function reference: \{f}")
      }
      Ok(())
    }
    Block(_, Expr(body)) | Loop(_, Expr(body)) => {
      for inner in body {
        if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
          return Err(e)
        }
      }
      Ok(())
    }
    If(_, then_body, else_body) => {
      for inner in then_body {
        if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
          return Err(e)
        }
      }
      match else_body {
        Some(branch) =>
          for inner in branch {
            if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
              return Err(e)
            }
          }
        None => ()
      }
      Ok(())
    }
    Try(_, Expr(body), catches, _) => {
      for inner in body {
        if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
          return Err(e)
        }
      }
      for catch_ in catches {
        let Expr(catch_body) = match catch_ {
          LegacyCatch(_, catch_body) | LegacyCatchAll(catch_body) => catch_body
        }
        for inner in catch_body {
          if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
            return Err(e)
          }
        }
      }
      Ok(())
    }
    TryTable(_, _, Expr(body)) => {
      for inner in body {
        if ref_decl_boxed_reference_instr(inner, env, declared) is Err(e) {
          return Err(e)
        }
      }
      Ok(())
    }
    _ => Ok(())
  }
}

///|
fn ref_decl_boxed_reference_expr(
  expr : Expr,
  env : Env,
  declared : @bitset.BitSet,
) -> Result[Unit, String] {
  let Expr(instructions) = expr
  for instruction in instructions {
    if ref_decl_boxed_reference_instr(instruction, env, declared) is Err(error) {
      return Err(error)
    }
  }
  Ok(())
}

///|
fn ref_declaration_results_bench(
  it : @bench.T,
  kind : Int,
  before : Bool,
) -> Unit raise {
  let env = Env::new().with_module(ref_declaration_results_module([]))
  let declared = @bitset.BitSet::new(2)
  declared.set(0, true)
  let mut expression = Expr::new(
    Array::make(
      if kind == 0 {
        0
      } else {
        128
      },
      if kind == 2 {
        Instruction::ref_func(FuncIdx::new(0U))
      } else {
        Instruction::nop()
      },
    ),
  )
  if kind == 3 {
    for _ in 0..<16 {
      expression = Expr::new([
        Instruction::block(BlockType::void_(), expression),
      ])
    }
  }
  if kind == 4 {
    let Expr(instructions) = expression
    instructions.push(Instruction::ref_func(FuncIdx::new(1U)))
  }
  assert_eq(
    validate_ref_func_declarations_in_expr(expression, env, declared),
    ref_decl_boxed_reference_expr(expression, env, declared),
  )
  it.bench(fn() {
    it.keep(
      if before {
        ref_decl_boxed_reference_expr(expression, env, declared)
      } else {
        validate_ref_func_declarations_in_expr(expression, env, declared)
      },
    )
  })
}

///|
test "bench declaration results empty before" (it : @bench.T) {
  ref_declaration_results_bench(it, 0, true)
}

///|
test "bench declaration results empty current" (it : @bench.T) {
  ref_declaration_results_bench(it, 0, false)
}

///|
test "bench declaration results flat before" (it : @bench.T) {
  ref_declaration_results_bench(it, 1, true)
}

///|
test "bench declaration results flat current" (it : @bench.T) {
  ref_declaration_results_bench(it, 1, false)
}

///|
test "bench declaration results references before" (it : @bench.T) {
  ref_declaration_results_bench(it, 2, true)
}

///|
test "bench declaration results references current" (it : @bench.T) {
  ref_declaration_results_bench(it, 2, false)
}

///|
test "bench declaration results nested before" (it : @bench.T) {
  ref_declaration_results_bench(it, 3, true)
}

///|
test "bench declaration results nested current" (it : @bench.T) {
  ref_declaration_results_bench(it, 3, false)
}

///|
test "bench declaration results late-invalid before" (it : @bench.T) {
  ref_declaration_results_bench(it, 4, true)
}

///|
test "bench declaration results late-invalid current" (it : @bench.T) {
  ref_declaration_results_bench(it, 4, false)
}
