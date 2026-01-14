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
      TI32Const(b.unsafe_read_uint32_le(0).reinterpret_as_int())
    Literal(I64LiteralKind, b) =>
      TI64Const(b.unsafe_read_uint64_le(0).reinterpret_as_int64())
    Literal(F32LiteralKind, b) =>
      TF32Const(F32(Float::reinterpret_from_uint(b.unsafe_read_uint32_le(0))))
    Literal(F64LiteralKind, b) =>
      TF64Const(b.unsafe_read_uint64_le(0).reinterpret_as_double())
    Literal(V128LiteralKind, b) =>
      TV128Const(
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
pub fn ConstHoistingState::new() -> ConstHoistingState {
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
fn i32_lit(val : Int) -> Literal {
  let b = @buffer.new(size_hint=4)
  b.write_int_le(val)
  Literal(I32LiteralKind, b.to_bytes())
}

///|
fn i64_lit(val : Int64) -> Literal {
  let b = @buffer.new(size_hint=8)
  b.write_int64_le(val)
  Literal(I64LiteralKind, b.to_bytes())
}

///|
fn f32_lit(val : Float) -> Literal {
  let b = @buffer.new(size_hint=4)
  b.write_float_le(val)
  Literal(F32LiteralKind, b.to_bytes())
}

///|
fn f64_lit(val : Double) -> Literal {
  let b = @buffer.new(size_hint=8)
  b.write_double_le(val)
  Literal(F64LiteralKind, b.to_bytes())
}

///|
fn v128_lit(
  b0 : Byte,
  b1 : Byte,
  b2 : Byte,
  b3 : Byte,
  b4 : Byte,
  b5 : Byte,
  b6 : Byte,
  b7 : Byte,
  b8 : Byte,
  b9 : Byte,
  b10 : Byte,
  b11 : Byte,
  b12 : Byte,
  b13 : Byte,
  b14 : Byte,
  b15 : Byte,
) -> Literal {
  let b = Bytes::from_array([
    b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
  ])
  Literal(V128LiteralKind, b)
}

///|
fn replace_literal_pass() -> ModuleTransformer[Map[Literal, LocalIdx]] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_tinstruction: Some(fn(self, t, i) {
      match i {
        TI32Const(I32(val)) => {
          let lit = i32_lit(val)
          if t.get(lit) is Some(idx) {
            change(t, @lib.TLocalGet(idx))
          } else {
            unchanged()
          }
        }
        TI64Const(I64(val)) => {
          let lit = i64_lit(val)
          if t.get(lit) is Some(idx) {
            change(t, @lib.TLocalGet(idx))
          } else {
            unchanged()
          }
        }
        TF32Const(F32(val)) => {
          let lit = f32_lit(val)
          if t.get(lit) is Some(idx) {
            change(t, @lib.TLocalGet(idx))
          } else {
            unchanged()
          }
        }
        TF64Const(F64(val)) => {
          let lit = f64_lit(val)
          if t.get(lit) is Some(idx) {
            change(t, @lib.TLocalGet(idx))
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
          let lit = v128_lit(
            b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15,
          )
          if t.get(lit) is Some(idx) {
            change(t, @lib.TLocalGet(idx))
          } else {
            unchanged()
          }
        }
        _ => self.walk_tinstruction_default(t, i)
      }
    }),
  }
}

///|
pub fn const_hoisting_pass() -> ModuleTransformer[ConstHoistingState] {
  ModuleTransformer::{
    ..ModuleTransformer::new(),
    on_func: Some(fn(self, t, func) {
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
            replacers.set(lit, @lib.LocalIdx(next))
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
        body.0.insert(0, TLocalSet(idx, con))
      }
      change(t, TFunc(locals, body))
    }),
    on_tinstruction: Some(fn(self, t, i) {
      match i {
        TI32Const(I32(val)) => t.uses(i32_lit(val))
        TI64Const(I64(val)) => t.uses(i64_lit(val))
        TF32Const(F32(val)) => t.uses(f32_lit(val))
        TF64Const(F64(val)) => t.uses(f64_lit(val))
        // In the case of v128 constants, simd locals are expensive and encoding is tricky
        // TV128Const(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15) => 
        //   t.uses(v128_lit(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15))
        _ => ()
      }
      self.walk_tinstruction_default(t, i)
    }),
  }
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
  let f = @lib.TFunc([], TExpr::new([TI32Const(I32(7))]))
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      assert_eq(locals.length(), 0)
      assert_eq(instrs.length(), 1)
      assert_eq(instrs[0], TI32Const(7))
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: large constant is hoisted" {
  let big = 100000
  let f = @lib.TFunc(
    [],
    TExpr::new([TI32Const(I32(big)), TI32Const(I32(big)), TI32Const(I32(big))]),
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
  let f = @lib.TFunc(
    [],
    TExpr::new([TI32Const(I32(0)), TI32Const(I32(0)), TI32Const(I32(0))]),
  )
  let f2 = run_hoist(f)
  match f2 {
    TFunc(locals, TExpr(instrs)) => {
      assert_eq(locals.length(), 0)
      assert_eq(instrs.length(), 3)
      for i in instrs {
        assert_true(i is @lib.TI32Const(_))
      }
    }
    _ => fail("expected TFunc")
  }
}

///|
test "const hoisting: different literals are not merged" {
  let f = Func::t_func(
    [],
    TExpr::new([TI32Const(I32(10)), TI32Const(I32(20)), TI32Const(I32(10))]),
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
    TExpr::new([TF64Const(F64(pi)), TF64Const(F64(pi)), TF64Const(F64(pi))]),
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
