///|
pub fn expand_locals(decls : Array[Locals]) -> Result[Array[ValType], String] {
  let out : Array[ValType] = []
  for d in decls {
    let Locals(n, vt) = d
    let count = n.reinterpret_as_int()
    if count < 0 {
      return Err("locals: negative count")
    }
    for _ in 0..<count {
      out.push(vt)
    }
  }
  Ok(out)
}

///|
pub fn uses(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  let walker = ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tinstruction: Some(fn(self, _, i) {
      match i {
        TInstr::TLocalGet(idx) => result.add(idx)
        _ => ()
      }
      self.walk_tinstruction_default((), i)
    }),
  }
  ignore(walker.walk_texpr_default((), TExpr::new([instr])))
  result
}

///|
pub fn defs(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  match instr {
    TInstr::TLocalSet(idx, _) => result.add(idx)
    _ => ()
  }
  result
}

///|
test "liveness: local.get is a use" {
  let x = LocalIdx::new(0)
  let instr = TInstr::local_get(x)
  let u = uses(instr)
  let d = defs(instr)
  assert_true(u.contains(x))
  assert_true(d.is_empty())
}

///|
test "liveness: local.set defines and value may use" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instr = TInstr::local_set(x, TInstr::local_get(y))
  let u = uses(instr)
  let d = defs(instr)
  assert_true(d.contains(x))
  assert_true(!d.contains(y))
  assert_true(u.contains(y))
  assert_true(!u.contains(x))
}

///|
test "liveness: nested expressions propagate uses" {
  let x = LocalIdx::new(0)
  let y = LocalIdx::new(1)
  let instr = TInstr::unary(
    UnaryOp::i32_eqz(),
    TInstr::binary(
      BinaryOp::i32_add(),
      TInstr::local_get(x),
      TInstr::local_get(y),
    ),
  )
  let u = uses(instr)
  let d = defs(instr)
  assert_true(u.contains(x))
  assert_true(u.contains(y))
  assert_true(d.is_empty())
}
