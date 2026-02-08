///|
pub struct SquareMatrix[T] {
  storage : Map[UInt64, T]
  n : UInt
}

///|
pub fn[T] SquareMatrix::new(size? : UInt = 0) -> Self[T] {
  SquareMatrix::{
    storage: Map::new(capacity=(size * size).reinterpret_as_int()),
    n: size,
  }
}

///|
pub fn[T] SquareMatrix::get_or(
  self : SquareMatrix[T],
  or : T,
  x : UInt,
  y : UInt,
) -> Result[T, String] {
  let n = self.n
  if x >= n || y >= n {
    return Err("Index out of bounds")
  }
  let index = x.to_uint64() * n.to_uint64() + y.to_uint64()
  if self.storage.get(index) is Some(t) {
    Ok(t)
  } else {
    Ok(or)
  }
}

///|
pub fn[T : Default] SquareMatrix::get_or_default(
  self : SquareMatrix[T],
  x : UInt,
  y : UInt,
) -> Result[T, String] {
  SquareMatrix::get_or(self, T::default(), x, y)
}

///|
pub fn uses(instr : TInstr) -> Set[LocalIdx] {
  let result = Set::new()
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, i) {
    match i {
      TInstr::TLocalGet(idx) => result.add(idx)
      _ => ()
    }
    self.walk_tinstruction_default((), i)
  })
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
fn wrap_unit_func_pass(
  pass : ModuleTransformer[Unit],
) -> ModuleTransformer[IRContext] {
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func((), func) {
      Ok(Some((_, new_func))) => change(ctx, new_func)
      Ok(None) => unchanged()
      Err(e) => Err(e)
    }
  })
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

///|
test "SquareMatrix::get_or returns bounds error" {
  let matrix : SquareMatrix[Int] = SquareMatrix::new(size=2)
  match matrix.get_or(0, 2, 0) {
    Ok(_) => fail("expected out-of-bounds access to return error")
    Err(e) => assert_eq(e, "Index out of bounds")
  }
}

///|
test "wrap_unit_func_pass propagates wrapped pass errors" {
  let bad = ModuleTransformer::new().on_func_evt(fn(_, _, _ : Func) {
    Err("boom")
  })
  let wrapped = wrap_unit_func_pass(bad)
  let mod = Module::new().with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
  )
  let ctx = IRContext::new()
  match wrapped.walk_module(ctx, mod) {
    Err(e) => assert_eq(e, "boom")
    _ => fail("expected wrapped pass error to propagate")
  }
}
