///|
fn encode_module_stringrefs_before_index(mod_ : Module) -> Array[Bytes] {
  /// Keep insertion order while de-duplicating byte arrays.
  fn push_unique(out : Array[Bytes], bytes : Bytes) -> Unit {
    for existing in out {
      if existing == bytes {
        return
      }
    }
    out.push(bytes)
  }

  /// Recurse through structured control instructions and collect string constants
  /// that can be reached in nested blocks for local declarations and exports.
  fn collect_instruction(instr : Instruction, out : Array[Bytes]) -> Unit {
    match instr {
      StringConst(bytes) => push_unique(out, bytes)
      Block(_, Expr(instrs))
      | Loop(_, Expr(instrs))
      | TryTable(_, _, Expr(instrs)) =>
        for child in instrs {
          collect_instruction(child, out)
        }
      Try(_, Expr(instrs), catches, _) => {
        for child in instrs {
          collect_instruction(child, out)
        }
        for catch_ in catches {
          let Expr(catch_instrs) = match catch_ {
            @lib.LegacyCatch(_, body) | @lib.LegacyCatchAll(body) => body
          }
          for child in catch_instrs {
            collect_instruction(child, out)
          }
        }
      }
      If(_, if_block, else_block) => {
        for child in if_block {
          collect_instruction(child, out)
        }
        match else_block {
          Some(instrs) =>
            for child in instrs {
              collect_instruction(child, out)
            }
          None => ()
        }
      }
      _ => ()
    }
  }

  let out : Array[Bytes] = []
  match mod_.stringrefs_sec {
    Some(StringRefsSec(strings)) =>
      for bytes in strings {
        push_unique(out, bytes)
      }
    None => ()
  }
  match mod_.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(_, Expr(instrs)) = global
        for instr in instrs {
          collect_instruction(instr, out)
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        let Func(_, expr) = func
        let Expr(instrs) = expr
        for instr in instrs {
          collect_instruction(instr, out)
        }
      }
    None => ()
  }
  out
}
