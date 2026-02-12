///|
const MIN_USES = 2

///|
pub enum LiteralKind {
  I32LiteralKind
  I64LiteralKind
  F32LiteralKind
  F64LiteralKind
  V128LiteralKind
} derive(Eq, Hash, Show)

///|
pub struct Literal(LiteralKind, Bytes) derive(Eq, Hash, Show)

///|
fn Literal::i32(val : Int) -> Literal {
  let buf = @buffer.new(size_hint=4)
  buf.write_int_le(val)
  Literal(I32LiteralKind, buf.to_bytes())
}

///|
fn Literal::i64(val : Int64) -> Literal {
  let buf = @buffer.new(size_hint=8)
  buf.write_int64_le(val)
  Literal(I64LiteralKind, buf.to_bytes())
}

///|
fn Literal::f32(val : Float) -> Literal {
  let buf = @buffer.new(size_hint=4)
  buf.write_float_le(val)
  Literal(F32LiteralKind, buf.to_bytes())
}

///|
fn Literal::f64(val : Double) -> Literal {
  let buf = @buffer.new(size_hint=8)
  buf.write_double_le(val)
  Literal(F64LiteralKind, buf.to_bytes())
}

///|
fn Literal::v128(
  a : Byte,
  b : Byte,
  c : Byte,
  d : Byte,
  e : Byte,
  f : Byte,
  g : Byte,
  h : Byte,
  i : Byte,
  j : Byte,
  k : Byte,
  l : Byte,
  m : Byte,
  n : Byte,
  o : Byte,
  p : Byte,
) -> Literal {
  let val = Bytes::from_array([
    a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p,
  ])
  Literal(V128LiteralKind, val)
}

///|
fn Literal::byte_size(self : Literal) -> Int {
  match self {
    Literal(I32LiteralKind, b) =>
      size_signed(
        b.unsafe_read_uint32_le(0).reinterpret_as_int().to_int64(),
        32,
      ).unwrap()
    Literal(I64LiteralKind, b) =>
      size_signed(b.unsafe_read_uint64_le(0).reinterpret_as_int64(), 64).unwrap()
    Literal(F32LiteralKind, _) => 4
    Literal(F64LiteralKind, _) => 8
    Literal(V128LiteralKind, _) => 16
  }
}

///|
fn Literal::get_tinst(self : Literal) -> TInstr {
  match self {
    Literal(I32LiteralKind, b) =>
      TInstr::i32_const(b.unsafe_read_uint32_le(0).reinterpret_as_int())
    Literal(I64LiteralKind, b) =>
      TInstr::i64_const(b.unsafe_read_uint64_le(0).reinterpret_as_int64())
    Literal(F32LiteralKind, b) =>
      TInstr::f32_const(
        F32(Float::reinterpret_from_uint(b.unsafe_read_uint32_le(0))),
      )
    Literal(F64LiteralKind, b) =>
      TInstr::f64_const(b.unsafe_read_uint64_le(0).reinterpret_as_double())
    Literal(V128LiteralKind, b) =>
      TInstr::v128_const(
        b.unsafe_get(0),
        b.unsafe_get(1),
        b.unsafe_get(2),
        b.unsafe_get(3),
        b.unsafe_get(4),
        b.unsafe_get(5),
        b.unsafe_get(6),
        b.unsafe_get(7),
        b.unsafe_get(8),
        b.unsafe_get(9),
        b.unsafe_get(10),
        b.unsafe_get(11),
        b.unsafe_get(12),
        b.unsafe_get(13),
        b.unsafe_get(14),
        b.unsafe_get(15),
      )
  }
}

///|
fn LiteralKind::rank(self : Self) -> Int {
  match self {
    I32LiteralKind => 0
    I64LiteralKind => 1
    F32LiteralKind => 2
    F64LiteralKind => 3
    V128LiteralKind => 4
  }
}

///|
fn LiteralKind::get_valtype(self : Self) -> ValType {
  match self {
    I32LiteralKind => ValType::i32()
    I64LiteralKind => ValType::i64()
    F32LiteralKind => ValType::f32()
    F64LiteralKind => ValType::f64()
    V128LiteralKind => ValType::v128()
  }
}

///|
pub impl Compare for Literal with compare(l, r) {
  let kind = l.0.compare(r.0)
  if kind == 0 {
    l.1.compare(r.1)
  } else {
    kind
  }
}

///|
pub impl Compare for LiteralKind with compare(l, r) {
  l.rank().compare(r.rank())
}

///|
pub struct ConstHoistingState {
  usage : Map[Literal, Int]
}

///|
fn ConstHoistingState::new() -> ConstHoistingState {
  ConstHoistingState::{ usage: Map::new() }
}

///|
fn ConstHoistingState::uses(self : Self, literal : Literal) -> Unit {
  let usage = self.usage
  match usage.get(literal) {
    Some(i) => usage.set(literal, i + 1)
    None => usage.set(literal, 1)
  }
}

///|
fn replace_literal_pass() -> ModuleTransformer[Map[Literal, LocalIdx]] {
  ModuleTransformer::new().on_tinstruction_evt(fn(self, t, i) {
    match i {
      TI32Const(I32(val)) => {
        let lit = Literal::i32(val)
        if t.get(lit) is Some(idx) {
          change(t, TInstr::local_get(idx))
        } else {
          unchanged()
        }
      }
      TI64Const(I64(val)) => {
        let lit = Literal::i64(val)
        if t.get(lit) is Some(idx) {
          change(t, TInstr::local_get(idx))
        } else {
          unchanged()
        }
      }
      TF32Const(F32(val)) => {
        let lit = Literal::f32(val)
        if t.get(lit) is Some(idx) {
          change(t, TInstr::local_get(idx))
        } else {
          unchanged()
        }
      }
      TF64Const(F64(val)) => {
        let lit = Literal::f64(val)
        if t.get(lit) is Some(idx) {
          change(t, TInstr::local_get(idx))
        } else {
          unchanged()
        }
      }

      // this is likely not to be used because v128 consts are hardly worth hoisting
      TV128Const(
        b0,
        b1,
        b2,
        b3,
        b4,
        b5,
        b6,
        b7,
        b8,
        b9,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15
      ) => {
        let lit = Literal::v128(
          b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
        )
        if t.get(lit) is Some(idx) {
          change(t, TInstr::local_get(idx))
        } else {
          unchanged()
        }
      }
      _ => self.walk_tinstruction_default(t, i)
    }
  })
}

///|
fn const_hoisting_pass() -> ModuleTransformer[ConstHoistingState] {
  ModuleTransformer::new()
  .on_func_evt(fn(self, t : ConstHoistingState, func) {
    // reset uses of consts per function
    t.usage.clear()
    let (t, func) = match self.walk_func_default(t, func) {
      Ok(Some((t, func))) => (t, func)
      Ok(None) => (t, func)
      Err(t) => return Err(t)
    }
    let (locals, body) = match func {
      Func(_) =>
        return Err(
          "Invalid transformer state. Expected TFunc but received Func",
        )
      TFunc(locals, body) => (locals, body)
    }
    let replacer_pass = replace_literal_pass()
    let replacers = Map::new()
    for k in t.usage.iter() {
      let lit = k.0
      let count = k.1
      if count >= MIN_USES {
        let size = lit.byte_size()
        let before = count * (size + 1)
        let after = size + 2 + 2 * count
        if after < before {
          let next = locals.length().reinterpret_as_uint()
          locals.push(lit.0.get_valtype())
          replacers.set(lit, LocalIdx::new(next))
        }
      }
    }
    let body = match replacer_pass.walk_texpr_default(replacers, body) {
      Ok(Some((_, body))) => body
      Ok(None) => body
      Err(t) => return Err(t)
    }
    for k in replacers {
      let lit = k.0
      let idx = k.1
      let con = lit.get_tinst()
      body.0.insert(0, TInstr::local_set(idx, con))
    }
    change(t, Func::t_func(locals, body))
  })
  .on_tinstruction_evt(fn(self, t, i) {
    match i {
      TI32Const(I32(val)) => t.uses(Literal::i32(val))
      TI64Const(I64(val)) => t.uses(Literal::i64(val))
      TF32Const(F32(val)) => t.uses(Literal::f32(val))
      TF64Const(F64(val)) => t.uses(Literal::f64(val))
      // In the case of v128 constants, simd locals are expensive and encoding is tricky
      // TV128Const(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15) => 
      //   t.uses(v128_lit(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15))
      _ => ()
    }
    self.walk_tinstruction_default(t, i)
  })
}

///|
fn const_hoisting_ir_pass(_mod : Module) -> ModuleTransformer[IRContext] {
  let pass = const_hoisting_pass()
  ModuleTransformer::new().on_func_evt(fn(_, ctx : IRContext, func : Func) {
    match pass.walk_func(ConstHoistingState::new(), func) {
      Ok(Some((_, new_func))) => change(ctx, new_func)
      Ok(None) => unchanged()
      Err(e) => Err(e)
    }
  })
}

///|
fn run_hoist(f : Func) -> Func raise {
  let pass = const_hoisting_pass()
  let empty_state = ConstHoistingState::new()
  match pass.walk_func(empty_state, f) {
    Ok(Some((_, f))) => return f
    Ok(None) => ()
    Err(e) => assert_true(false, msg=e)
  }
  f
}

///|
test "const hoisting: single use does nothing" {
  let f = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      assert_eq(locals.length(), 0)
      assert_eq(instrs.length(), 1)
      assert_eq(instrs[0], TInstr::i32_const(I32(7)))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: large constant is hoisted" {
  let big = 100000
  let f = Func::t_func(
    [],
    TExpr::new([
      TInstr::i32_const(I32(big)),
      TInstr::i32_const(I32(big)),
      TInstr::i32_const(I32(big)),
    ]),
  )
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      // One new local
      assert_eq(locals.length(), 1)

      // First instruction is local.set
      assert_true(instrs[0] is TLocalSet(_))

      // Remaining are local.get
      assert_true(instrs[1] is TLocalGet(_))
      assert_true(instrs[2] is TLocalGet(_))
      assert_true(instrs[3] is TLocalGet(_))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: small constants are not hoisted" {
  let f = Func::t_func(
    [],
    TExpr::new([
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
      TInstr::i32_const(I32(0)),
    ]),
  )
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      assert_eq(locals.length(), 0)
      assert_eq(instrs.length(), 3)
      for i in instrs {
        assert_true(i is TInstr::TI32Const(_))
      }
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: different literals are not merged" {
  let f = Func::t_func(
    [],
    TExpr::new([
      TInstr::i32_const(I32(10)),
      TInstr::i32_const(I32(20)),
      TInstr::i32_const(I32(10)),
    ]),
  )
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      // 10 is small → not hoisted
      assert_eq(locals.length(), 0)
      assert_true(instrs[0] is TI32Const(_))
      assert_true(instrs[1] is TI32Const(_))
      assert_true(instrs[2] is TI32Const(_))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: f64 hoisted when repeated" {
  let pi = 3.141592653589793
  let f = Func::t_func(
    [],
    TExpr::new([
      TInstr::f64_const(F64(pi)),
      TInstr::f64_const(F64(pi)),
      TInstr::f64_const(F64(pi)),
    ]),
  )
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      assert_eq(locals.length(), 1)
      assert_true(instrs[0] is TLocalSet(_))
      assert_true(instrs[1] is TLocalGet(_))
      assert_true(instrs[2] is TLocalGet(_))
      assert_true(instrs[3] is TLocalGet(_))
    }
    _ => fail("expected TFunc")
  }
}
