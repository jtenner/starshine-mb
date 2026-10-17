///|
fn dae2_entry_lookup_fixture(body : String, locals~ : Int32 = 4) -> @lib.Module {
  let locals = Array::make(locals, "i32").join(" ")
  pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{body}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
}

///|
fn dae2_entry_lookup_lexical_writes(
  body : Array[@lib.Instruction],
) -> Array[Int32] {
  let writes : Array[Int32] = []
  for instr in body {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(local))
      | @lib.LocalTee(@lib.LocalIdx(local)) =>
        writes.push(local.reinterpret_as_int())
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        writes.append(dae2_entry_lookup_lexical_writes(child))
      @lib.If(_, yes, no) => {
        writes.append(dae2_entry_lookup_lexical_writes(yes))
        match no {
          Some(child) => writes.append(dae2_entry_lookup_lexical_writes(child))
          None => ()
        }
      }
      _ => ()
    }
  }
  writes
}

///|
fn dae2_entry_lookup_effect_count(body : Array[@lib.Instruction]) -> Int32 {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Call(index) => if dae_func_idx_slot(index) == 0 { count += 1 }
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        count += dae2_entry_lookup_effect_count(child)
      @lib.If(_, yes, no) => {
        count += dae2_entry_lookup_effect_count(yes)
        match no {
          Some(child) => count += dae2_entry_lookup_effect_count(child)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}
