///| 
/// Copyright 2023 WebAssembly Community Group participants
/// 
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
/// 
///     http://www.apache.org/licenses/LICENSE-2.0
/// 
/// Unless required by applicable law or agreed to in writing, software
/// distributed under the License is distributed on an "AS IS" BASIS,
/// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/// See the License for the specific language governing permissions and
/// limitations under the License.
///

///|
fn lt_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => n += 1
          _ => ()
        }
      }
    None => ()
  }
  n
}

///|
fn lift_to_texpr_module_with_trace(
  mod : Module,
  trace : (String) -> Unit,
) -> Result[Module, String] {
  let base_env = Env::new().with_module(mod)
  let imported_funcs = lt_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let new_funcs : Array[Func] = []
      for def_idx in 0..<funcs.length() {
        let seen_funcs = def_idx + 1
        if seen_funcs <= 5 || seen_funcs % 500 == 0 {
          trace("func[\{seen_funcs}] visit")
        }
        match funcs[def_idx] {
          Func(locals_grouped, body) =>
            match expand_locals(locals_grouped) {
              Ok(expanded_locals) => {
                let abs_idx = imported_funcs + def_idx
                let func_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
                let results = match base_env.get_functype_by_funcidx(func_idx) {
                  Some(FuncType(_, rs)) => rs
                  None =>
                    return Err(
                      "lift_to_texpr missing function type for function index \{abs_idx}",
                    )
                }
                let env = base_env
                  .with_locals(expanded_locals)
                  .with_return_type(Some(results))
                match to_texpr(body, env) {
                  Ok(texpr) => {
                    if seen_funcs <= 5 || seen_funcs % 500 == 0 {
                      trace("func[\{seen_funcs}] lifted")
                    }
                    new_funcs.push(Func::t_func(expanded_locals, texpr))
                  }
                  Err(e) => {
                    if seen_funcs <= 20 || seen_funcs % 500 == 0 {
                      trace("func[\{seen_funcs}] to_texpr failed: \{e}")
                    }
                    return Err(
                      "lift_to_texpr failed at function \{abs_idx}: \{e}",
                    )
                  }
                }
              }
              Err(err) => {
                trace("func[\{seen_funcs}] expand_locals failed: \{err}")
                return Err(err)
              }
            }
          TFunc(_, _) => {
            if seen_funcs <= 5 || seen_funcs % 500 == 0 {
              trace("func[\{seen_funcs}] already-tfunc")
            }
            new_funcs.push(funcs[def_idx])
          }
        }
      }
      Ok(mod.with_code_sec(CodeSec::new(new_funcs)))
    }
    None => Ok(mod)
  }
}

///|
fn lift_to_texpr_pass_with_trace(
  trace : (String) -> Unit,
) -> ModuleTransformer[Unit] {
  let mut seen_funcs = 0
  ModuleTransformer::new().on_func_evt(fn(
    _ : ModuleTransformer[Unit],
    _ : Unit,
    f : Func,
  ) -> TransformerResult[Unit, Func] {
    seen_funcs += 1
    if seen_funcs <= 5 || seen_funcs % 500 == 0 {
      trace("func[\{seen_funcs}] visit")
    }
    match f {
      Func(l, t) =>
        match to_texpr(t, Env::new()) {
          Ok(t) =>
            match expand_locals(l) {
              Ok(l) => {
                if seen_funcs <= 5 || seen_funcs % 500 == 0 {
                  trace("func[\{seen_funcs}] lifted")
                }
                change((), Func::t_func(l, t))
              }
              Err(err) => {
                trace("func[\{seen_funcs}] expand_locals failed: \{err}")
                Err(err)
              }
            }
          Err(e) => {
            if seen_funcs <= 20 || seen_funcs % 500 == 0 {
              trace("func[\{seen_funcs}] to_texpr failed: \{e}")
            }
            unchanged()
          }
        }
      TFunc(_, _) => {
        if seen_funcs <= 5 || seen_funcs % 500 == 0 {
          trace("func[\{seen_funcs}] already-tfunc")
        }
        unchanged()
      }
    }
  })
}

///|
fn lift_to_texpr_pass() -> ModuleTransformer[Unit] {
  lift_to_texpr_pass_with_trace(fn(_) { () })
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

///|
test "lift_to_texpr_pass keeps original Func when conversion fails" {
  let func = Func::new([], Expr::new([Instruction::i32_add()]))
  let mod = Module::new().with_code_sec(CodeSec::new([func]))
  let pass = lift_to_texpr_pass()
  let result = pass.walk_module((), mod)
  match result {
    Ok(None) => ()
    Ok(Some((_, new_mod))) => assert_eq(new_mod, mod)
    Err(e) =>
      fail("expected graceful fallback on conversion failure, got: \{e}")
  }
}
