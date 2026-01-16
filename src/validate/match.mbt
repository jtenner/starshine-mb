///|
pub trait Match {
  matches(Self, Self, Env) -> Bool
}

///|
pub trait DeclMatch {
  matches_decl(Self, Self, Env) -> Bool
}

///|
pub impl[T : Match] Match for Array[T] with matches(self, other, env) {
  if self.length() != other.length() {
    return false
  }
  for i in 0..<self.length() {
    if !self[i].matches(other[i], env) {
      return false
    }
  }
  true
}

///|
pub impl Match for CompType with matches(self, other, env) {
  match (self, other) {
    // self <: other
    (FuncCompType(p_self, r_self), FuncCompType(p_other, r_other)) =>
      // contravariant in params, covariant in results
      Match::matches(p_other, p_self, env) &&
      Match::matches(r_self, r_other, env)
    (StructCompType(fs0), StructCompType(fs1)) => Match::matches(fs0, fs1, env)
    (ArrayCompType(f0), ArrayCompType(f1)) => Match::matches(f0, f1, env)
    _ => false
  }
}

///|
pub impl Match for ValType with matches(self, other, env) {
  match (self, other) {
    (RefTypeValType(r0), RefTypeValType(r1)) => Match::matches(r0, r1, env)
    _ => self == other
  }
}

///|
pub impl Match for RefType with matches(self, other, env) {
  let ht0 = self.get_heap_type()
  let ht1 = other.get_heap_type()

  // Heap type compatibility (start with equality; extend later)
  if !Match::matches(ht0, ht1, env) {
    return false
  }

  // Nullability: non-null <: nullable
  let n0 = self.is_nullable()
  let n1 = other.is_nullable()
  (!n0 && n1) || n0 == n1
}

///|
pub impl Match for FieldType with matches(self, other, env) {
  let FieldType(st0, m0) = self
  let FieldType(st1, m1) = other
  match (m0, m1) {
    (Const, Const) => Match::matches(st0, st1, env) // covariant
    (Var, Var) => Match::matches(st0, st1, env) && Match::matches(st1, st0, env) // invariant
    _ => false
  }
}

///|
pub impl Match for StorageType with matches(self, other, env) {
  match (self, other) {
    (ValTypeStorageType(v1), ValTypeStorageType(v2)) =>
      Match::matches(v1, v2, env)
    (PackTypeStorageType(p1), PackTypeStorageType(p2)) => p1 == p2
    _ => false
  }
}

///|
pub impl Match for AbsHeapType with matches(self, other, _) {
  if self == other {
    return true
  }
  match (self, other) {
    // eq <: any
    (EqAbsHeapType, AnyAbsHeapType) => true

    // i31/struct/array <: eq
    (I31AbsHeapType, EqAbsHeapType) => true
    (StructAbsHeapType, EqAbsHeapType) => true
    (ArrayAbsHeapType, EqAbsHeapType) => true

    // i31/struct/array <: any (transitive via eq)
    (I31AbsHeapType, AnyAbsHeapType) => true
    (StructAbsHeapType, AnyAbsHeapType) => true
    (ArrayAbsHeapType, AnyAbsHeapType) => true

    // none <: all internal types
    (NoneAbsHeapType, AnyAbsHeapType) => true
    (NoneAbsHeapType, EqAbsHeapType) => true
    (NoneAbsHeapType, I31AbsHeapType) => true
    (NoneAbsHeapType, StructAbsHeapType) => true
    (NoneAbsHeapType, ArrayAbsHeapType) => true

    // nofunc <: func
    (NoFuncAbsHeapType, FuncAbsHeapType) => true

    // noextern <: extern
    (NoExternAbsHeapType, ExternAbsHeapType) => true

    // noexn <: exn
    (NoExnAbsHeapType, ExnAbsHeapType) => true
    _ => false
  }
}

///|
pub impl Match for HeapType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16
  heaptype_matches_fuel(self, other, env, fuel)
}

///|
fn heaptype_matches_fuel(
  h1 : HeapType,
  h2 : HeapType,
  env : Env,
  fuel : Int,
) -> Bool {
  if h1 == h2 {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (h1, h2) {
    (AbsHeapTypeHeapType(a1), AbsHeapTypeHeapType(a2)) =>
      Match::matches(a1, a2, env)

    // Spec: defined type judgement
    (DefTypeHeapType(dt1), DefTypeHeapType(dt2)) =>
      deftype_matches_fuel(dt1, dt2, env, fuel - 1)

    // typeidx/recidx unfold on either side
    (HeapType(tidx), _) =>
      match env.resolve_subtype(tidx) {
        None => false
        Some(st1) => subtype_as_heap_fuel(st1, h2, env, fuel - 1)
      }
    (_, HeapType(tidx)) => heap_vs_typeidx_fuel(h1, tidx, env, fuel - 1)

    // deftype vs abs: use expansion-kind checks (struct/array/func → ...)
    (DefTypeHeapType(dt), AbsHeapTypeHeapType(abs)) =>
      deftype_matches_abs_fuel(dt, abs, env, fuel - 1)

    // abs vs deftype: conservative (generally false in subtype direction)
    (AbsHeapTypeHeapType(_), DefTypeHeapType(_)) => false
  }
}

///|
fn subtype_as_heap_fuel(
  st : SubType,
  target : HeapType,
  env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  let (is_final, supers, ct) = match st {
    CompTypeSubType(ct) => (false, [], ct)
    SubType(is_final, supers, ct) => (is_final, supers, ct)
  }

  // 1) Direct shape match against abstract heap supertypes
  match target {
    AbsHeapTypeHeapType(abs) => {
      if comptype_matches_abs(ct, abs) {
        return true
      }
      if is_final {
        return false
      }
    }
    _ => if is_final { return false }
  }

  // 2) Chase declared supertypes
  for tu in supers {
    if heaptype_matches_fuel(HeapType::new(tu), target, env, fuel - 1) {
      return true
    }
  }
  false
}

///|
fn comptype_matches_abs(ct : CompType, abs : AbsHeapType) -> Bool {
  match ct {
    StructCompType(_) =>
      abs == AbsHeapType::struct_() ||
      abs == AbsHeapType::eq() ||
      abs == AbsHeapType::any()
    ArrayCompType(_) =>
      abs == AbsHeapType::array() ||
      abs == AbsHeapType::eq() ||
      abs == AbsHeapType::any()
    FuncCompType(_, _) =>
      abs == AbsHeapType::func() || abs == AbsHeapType::any()
  }
}

///|
fn heap_vs_typeidx_fuel(
  h : HeapType,
  target : TypeIdx,
  env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  match h {
    AbsHeapTypeHeapType(_) => false
    HeapType(tidx1) =>
      typeidx_leq_typeidx_fuel(tidx1, target, env, fuel - 1, [])
    DefTypeHeapType(dt1) =>
      match dt1.project() {
        None => false
        Some(st1) => {
          let DefType(rt1, _) = dt1
          let env1 = env_with_rectype(env, rt1)
          match st1 {
            CompTypeSubType(_) => false
            SubType(is_final, supers, _) => {
              if is_final {
                return false
              }
              for tu in supers {
                if typeidx_leq_typeidx_fuel(tu, target, env1, fuel - 1, []) {
                  return true
                }
              }
              false
            }
          }
        }
      }
  }
}

///|
fn deftype_matches_abs_fuel(
  dt : DefType,
  abs : AbsHeapType,
  _env : Env,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }

  // let DefType(rt, _) = dt
  // let env2 = env_with_rectype(env, rt)

  match dt.project() {
    None => false
    Some(st) =>
      match st.get_comptype() {
        StructCompType(_) =>
          abs == AbsHeapType::struct_() ||
          abs == AbsHeapType::eq() ||
          abs == AbsHeapType::any()
        ArrayCompType(_) =>
          abs == AbsHeapType::array() ||
          abs == AbsHeapType::eq() ||
          abs == AbsHeapType::any()
        FuncCompType(_, _) =>
          abs == AbsHeapType::func() || abs == AbsHeapType::any()
      }
  }
}

///|
fn env_with_rectype(env : Env, rt : RecType) -> Env {
  match rt {
    SingleRecType(st) => env_add_rec_group(env, [st])
    GroupRecType(sts) => env_add_rec_group(env, sts)
  }
}

// Adjust this to your preferred stack API (immut/mut)

///|
fn env_add_rec_group(env : Env, group : Array[SubType]) -> Env {
  let rs = env.rec_stack.copy()
  rs.push(group)
  Env::{
    global_types: env.global_types,
    rec_stack: rs,
    funcs: env.funcs,
    tables: env.tables,
    mems: env.mems,
    globals: env.globals,
    elems: env.elems,
    datas: env.datas,
    tags: env.tags,
    locals: env.locals,
    labels: env.labels,
    return_type: env.return_type,
  }
}

///|
pub impl Match for DefType with matches(self, other, env) {
  let fuel = env.global_types.length() + 16 // Int
  deftype_matches_fuel(self, other, env, fuel)
}

///|
fn deftype_matches_fuel(
  dt1 : DefType,
  dt2 : DefType,
  env : Env,
  fuel : Int,
) -> Bool {
  // clos_C(dt1) == clos_C(dt2)
  if dt1 == dt2 {
    return true
  }
  if fuel <= 0 {
    return false
  }

  // Put dt1’s rectype in scope for any RecIdx references during unroll/chasing
  let DefType(rt1, _) = dt1
  let env1 = env_with_rectype(env, rt1)
  match dt1.project() {
    None => false
    Some(st1) =>
      match st1 {
        CompTypeSubType(_) => false
        SubType(is_final, supers, _) => {
          // final types have no proper subtypes
          if is_final {
            return false
          }
          let ht2 = HeapType::def_type(dt2)
          for tu in supers {
            // “typeuse*[i] matches heaptype deftype2”
            if heaptype_matches_fuel(HeapType::new(tu), ht2, env1, fuel - 1) {
              return true
            }
          }
          false
        }
      }
  }
}

///|
pub impl Match for Limits with matches(self, other, _) {
  match (self, other) {
    (I32Limits(n1, m1), I32Limits(n2, m2)) =>
      limits_range_matches_u64(
        n1.to_uint64(),
        m1.map(fn(x) { x.to_uint64() }),
        n2.to_uint64(),
        m2.map(fn(x) { x.to_uint64() }),
      )
    (I64Limits(n1, m1), I64Limits(n2, m2)) =>
      limits_range_matches_u64(n1, m1, n2, m2)
    _ => false
  }
}

// Implements: [n1..m1?] ≤ [n2..m2?]

///|
fn limits_range_matches_u64(
  n1 : UInt64,
  m1 : UInt64?,
  n2 : UInt64,
  m2 : UInt64?,
) -> Bool {
  // n1 >= n2
  if n1 < n2 {
    return false
  }
  match (m1, m2) {
    // [n1..m1] ≤ [n2..m2] requires m1 <= m2
    (Some(x1), Some(x2)) => x1 <= x2

    // [n1..m1] ≤ [n2..∞] always (given n1>=n2)
    (Some(_), None) => true

    // [n1..∞] ≤ [n2..∞] ok
    (None, None) => true

    // [n1..∞] ≤ [n2..m2] impossible
    (None, Some(_)) => false
  }
}

///|
pub impl Match for TagType with matches(self, other, env) {
  let TagType(a) = self
  let TagType(b) = other
  typeidx_leq_typeidx(a, b, env) && typeidx_leq_typeidx(b, a, env)
}

///|
fn typeidx_leq_typeidx(a : TypeIdx, b : TypeIdx, env : Env) -> Bool {
  let fuel = env.global_types.length() + 16
  typeidx_leq_typeidx_fuel(a, b, env, fuel, [])
}

///|
fn typeidx_leq_typeidx_fuel(
  a : TypeIdx,
  b : TypeIdx,
  env : Env,
  fuel : Int,
  visited : Array[TypeIdx],
) -> Bool {
  if a == b {
    return true
  }
  if fuel <= 0 {
    return false
  }

  // cycle guard
  for v in visited {
    if v == a {
      return false
    }
  }
  match env.resolve_subtype(a) {
    None => false
    Some(st) =>
      match st {
        CompTypeSubType(_) => false
        SubType(is_final, _, _) => {
          if is_final {
            return false
          }
          let visited2 = visited.copy()
          visited2.push(a)
          for s in st.super_types() {
            if typeidx_leq_typeidx_fuel(s, b, env, fuel - 1, visited2) {
              return true
            }
          }
          false
        }
      }
  }
}

///|
pub impl Match for MemType with matches(self, other, env) {
  let MemType(l1) = self
  let MemType(l2) = other
  Match::matches(l1, l2, env)
}

///|
pub impl Match for GlobalType with matches(self, other, env) {
  let GlobalType(v1, m1) = self
  let GlobalType(v2, m2) = other

  // Always: valtype1 ≤ valtype2
  if !Match::matches(v1, v2, env) {
    return false
  }
  match (m1, m2) {
    // const ≤ const (covariant already checked)
    (false, false) => true

    // mut ≤ mut requires invariance
    (true, true) => Match::matches(v2, v1, env)

    // mixed mutability does not match
    _ => false
  }
}

///|
pub impl Match for TableType with matches(self, other, env) {
  let TableType(rt1, lim1) = self
  let TableType(rt2, lim2) = other
  Match::matches(lim1, lim2, env) &&
  Match::matches(rt1, rt2, env) &&
  Match::matches(rt2, rt1, env)
}

///|
pub impl Match for ExternType with matches(self, other, env) {
  match (self, other) {
    (TagExternType(t1), TagExternType(t2)) => Match::matches(t1, t2, env)
    (GlobalExternType(g1), GlobalExternType(g2)) => Match::matches(g1, g2, env)
    (MemExternType(m1), MemExternType(m2)) => Match::matches(m1, m2, env)
    (TableExternType(t1), TableExternType(t2)) => Match::matches(t1, t2, env)

    // Spec says: func deftype1 ≤ func deftype2 iff deftype1 ≤ deftype2.
    (FuncExternType(ti1), FuncExternType(ti2)) => {
      // Optional: ensure both are actually function types
      if env.resolve_functype(ti1) is None {
        return false
      }
      if env.resolve_functype(ti2) is None {
        return false
      }
      typeidx_leq_typeidx(ti1, ti2, env)
    }
    _ => false
  }
}

// =============================================================================
// AbsHeapType Tests
// =============================================================================

///|
test "AbsHeapType: reflexivity" {
  let env = Env::new()
  assert_true(Match::matches(AbsHeapType::any(), AbsHeapType::any(), env))
  assert_true(Match::matches(AbsHeapType::eq(), AbsHeapType::eq(), env))
  assert_true(Match::matches(AbsHeapType::i31(), AbsHeapType::i31(), env))
  assert_true(
    Match::matches(AbsHeapType::struct_(), AbsHeapType::struct_(), env),
  )
  assert_true(Match::matches(AbsHeapType::array(), AbsHeapType::array(), env))
  assert_true(Match::matches(AbsHeapType::func(), AbsHeapType::func(), env))
  assert_true(
    Match::matches(AbsHeapType::extern_(), AbsHeapType::extern_(), env),
  )
  assert_true(Match::matches(AbsHeapType::none(), AbsHeapType::none(), env))
  assert_true(
    Match::matches(AbsHeapType::no_func(), AbsHeapType::no_func(), env),
  )
  assert_true(
    Match::matches(AbsHeapType::no_extern(), AbsHeapType::no_extern(), env),
  )
  assert_true(Match::matches(AbsHeapType::no_exn(), AbsHeapType::no_exn(), env))
}

///|
test "AbsHeapType: eq <: any" {
  let env = Env::new()
  assert_true(Match::matches(AbsHeapType::eq(), AbsHeapType::any(), env))
  assert_false(Match::matches(AbsHeapType::any(), AbsHeapType::eq(), env))
}

///|
test "AbsHeapType: i31/struct/array <: eq" {
  let env = Env::new()
  assert_true(Match::matches(AbsHeapType::i31(), AbsHeapType::eq(), env))
  assert_true(Match::matches(AbsHeapType::struct_(), AbsHeapType::eq(), env))
  assert_true(Match::matches(AbsHeapType::array(), AbsHeapType::eq(), env))

  // reverse should not hold
  assert_false(Match::matches(AbsHeapType::eq(), AbsHeapType::i31(), env))
  assert_false(Match::matches(AbsHeapType::eq(), AbsHeapType::struct_(), env))
  assert_false(Match::matches(AbsHeapType::eq(), AbsHeapType::array(), env))
}

///|
test "AbsHeapType: none <: any" {
  let env = Env::new()
  assert_true(Match::matches(AbsHeapType::none(), AbsHeapType::any(), env))
  assert_false(Match::matches(AbsHeapType::any(), AbsHeapType::none(), env))
}

///|
test "AbsHeapType: noX <: X (bottom types)" {
  let env = Env::new()
  assert_true(Match::matches(AbsHeapType::no_func(), AbsHeapType::func(), env))
  assert_true(
    Match::matches(AbsHeapType::no_extern(), AbsHeapType::extern_(), env),
  )
  assert_true(Match::matches(AbsHeapType::no_exn(), AbsHeapType::exn(), env))

  // reverse should not hold
  assert_false(Match::matches(AbsHeapType::func(), AbsHeapType::no_func(), env))
  assert_false(
    Match::matches(AbsHeapType::extern_(), AbsHeapType::no_extern(), env),
  )
  assert_false(Match::matches(AbsHeapType::exn(), AbsHeapType::no_exn(), env))
}

///|
test "AbsHeapType: unrelated types don't match" {
  let env = Env::new()
  assert_false(Match::matches(AbsHeapType::func(), AbsHeapType::extern_(), env))
  assert_false(Match::matches(AbsHeapType::extern_(), AbsHeapType::func(), env))
  assert_false(Match::matches(AbsHeapType::i31(), AbsHeapType::func(), env))
  assert_false(
    Match::matches(AbsHeapType::struct_(), AbsHeapType::array(), env),
  )
}

// =============================================================================
// Limits Tests
// =============================================================================

///|
test "Limits: reflexivity" {
  let env = Env::new()
  let l1 = Limits::i32(10, Some(100))
  let l2 = Limits::i64(10UL, Some(100UL))
  assert_true(Match::matches(l1, l1, env))
  assert_true(Match::matches(l2, l2, env))
}

///|
test "Limits: n1 >= n2 required" {
  let env = Env::new()
  // [10..100] matches [5..100] (10 >= 5)
  assert_true(
    Match::matches(Limits::i32(10, Some(100)), Limits::i32(5, Some(100)), env),
  )
  // [5..100] does not match [10..100] (5 < 10)
  assert_false(
    Match::matches(Limits::i32(5, Some(100)), Limits::i32(10, Some(100)), env),
  )
}

///|
test "Limits: m1 <= m2 required when both bounded" {
  let env = Env::new()
  // [10..50] matches [10..100] (50 <= 100)
  assert_true(
    Match::matches(Limits::i32(10, Some(50)), Limits::i32(10, Some(100)), env),
  )
  // [10..100] does not match [10..50] (100 > 50)
  assert_false(
    Match::matches(Limits::i32(10, Some(100)), Limits::i32(10, Some(50)), env),
  )
}

///|
test "Limits: bounded matches unbounded" {
  let env = Env::new()
  // [10..100] matches [10..∞]
  assert_true(
    Match::matches(Limits::i32(10, Some(100)), Limits::i32(10, None), env),
  )
}

///|
test "Limits: unbounded matches unbounded" {
  let env = Env::new()
  assert_true(Match::matches(Limits::i32(10, None), Limits::i32(10, None), env))
  assert_true(Match::matches(Limits::i32(10, None), Limits::i32(5, None), env))
}

///|
test "Limits: unbounded does not match bounded" {
  let env = Env::new()
  // [10..∞] does not match [10..100]
  assert_false(
    Match::matches(Limits::i32(10, None), Limits::i32(10, Some(100)), env),
  )
}

///|
test "Limits: i32 vs i64 don't match" {
  let env = Env::new()
  assert_false(
    Match::matches(
      Limits::i32(10, Some(100)),
      Limits::i64(10UL, Some(100UL)),
      env,
    ),
  )
  assert_false(
    Match::matches(
      Limits::i64(10UL, Some(100UL)),
      Limits::i32(10, Some(100)),
      env,
    ),
  )
}

// =============================================================================
// MemType Tests
// =============================================================================

///|
test "MemType: delegates to limits" {
  let env = Env::new()
  let m1 = @lib.MemType(Limits::i32(1, Some(10)))
  let m2 = @lib.MemType(Limits::i32(1, Some(20)))
  let m3 = @lib.MemType(Limits::i32(2, Some(10)))
  assert_true(Match::matches(m1, m1, env))
  assert_true(Match::matches(m1, m2, env)) // [1..10] <: [1..20]
  assert_false(Match::matches(m2, m1, env)) // [1..20] not <: [1..10]
  assert_false(Match::matches(m1, m3, env)) // Match::matches(min, 
}

// =============================================================================
// StorageType Tests
// =============================================================================

///|
test "StorageType: equality based" {
  let env = Env::new()
  // Assuming storage types like StorageType::pack_type(PackType::i8()), StorageType::pack_type(PackType::i16()), StorageType::val_type
  let s1 = StorageType::pack_type(PackType::i8())
  let s2 = StorageType::pack_type(PackType::i16())
  assert_true(Match::matches(s1, s1, env))
  assert_true(Match::matches(s2, s2, env))
  assert_false(Match::matches(s1, s2, env))
}

// =============================================================================
// FieldType Tests
// =============================================================================

///|
test "FieldType: const is covariant" {
  let env = Env::new()
  let st = StorageType::pack_type(PackType::i8())
  let f1 = FieldType::new(st, Const)
  let f2 = FieldType::new(st, Const)
  assert_true(Match::matches(f1, f2, env))
}

///|
test "FieldType: var is invariant" {
  let env = Env::new()
  let st = StorageType::pack_type(PackType::i8())
  let f1 = FieldType::new(st, Var)
  let f2 = FieldType::new(st, Var)
  assert_true(Match::matches(f1, f2, env))
}

///|
test "FieldType: const vs var don't match" {
  let env = Env::new()
  let st = StorageType::pack_type(PackType::i8())
  let const_field = FieldType::new(st, Const)
  let var_field = FieldType::new(st, Var)
  assert_false(Match::matches(const_field, var_field, env))
  assert_false(Match::matches(var_field, const_field, env))
}

// =============================================================================
// ValType Tests
// =============================================================================

///|
test "ValType: primitive types use equality" {
  let env = Env::new()
  assert_true(Match::matches(@lib.ValType::i32(), ValType::i32(), env))
  assert_true(Match::matches(@lib.ValType::i64(), ValType::i64(), env))
  assert_true(Match::matches(@lib.ValType::f32(), ValType::f32(), env))
  assert_true(Match::matches(@lib.ValType::f64(), ValType::f64(), env))
  assert_false(Match::matches(@lib.ValType::i32(), ValType::i64(), env))
  assert_false(Match::matches(@lib.ValType::f32(), ValType::f64(), env))
}

///|
test "ValType: ref types delegate to RefType matching" {
  let env = Env::new()
  // (ref null any) matches (ref null any)
  let rt1 = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let rt2 = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_true(
    Match::matches(@lib.ValType::ref_type(rt1), ValType::ref_type(rt2), env),
  )
}

// =============================================================================
// RefType Tests
// =============================================================================

///|
test "RefType: nullability - non-null <: nullable" {
  let env = Env::new()
  let non_null = RefType::new(false, HeapType::abs(AbsHeapType::any()))
  let nullable = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_true(Match::matches(non_null, nullable, env))
  assert_false(Match::matches(nullable, non_null, env))
}

///|
test "RefType: same nullability" {
  let env = Env::new()
  let null1 = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let null2 = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let non1 = RefType::new(false, HeapType::abs(AbsHeapType::any()))
  let non2 = RefType::new(false, HeapType::abs(AbsHeapType::any()))
  assert_true(Match::matches(null1, null2, env))
  assert_true(Match::matches(non1, non2, env))
}

///|
test "RefType: heap type subtyping with nullability" {
  let env = Env::new()
  // (ref null eq) <: (ref null any)
  let ref_eq = RefType::new(true, HeapType::abs(AbsHeapType::eq()))
  let ref_any = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_true(Match::matches(ref_eq, ref_any, env))
  assert_false(Match::matches(ref_any, ref_eq, env))
}

///|
test "RefType: non-null subtype matches nullable supertype" {
  let env = Env::new()
  // (ref eq) <: (ref null any)
  let ref_eq_nonnull = RefType::new(false, HeapType::abs(AbsHeapType::eq()))
  let ref_any_null = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  assert_true(Match::matches(ref_eq_nonnull, ref_any_null, env))
}

// =============================================================================
// HeapType Tests (wrapping AbsHeapType)
// =============================================================================

///|
test "HeapType: abs heap type matching" {
  let env = Env::new()
  let h1 = HeapType::abs(AbsHeapType::eq())
  let h2 = HeapType::abs(AbsHeapType::any())
  assert_true(Match::matches(h1, h2, env))
  assert_false(Match::matches(h2, h1, env))
}

// =============================================================================
// Array[T] Tests
// =============================================================================

///|
test "Array: empty arrays match" {
  let env = Env::new()
  let arr1 : Array[ValType] = []
  let arr2 : Array[ValType] = []
  assert_true(Match::matches(arr1, arr2, env))
}

///|
test "Array: length mismatch" {
  let env = Env::new()
  let arr1 = [@lib.ValType::i32()]
  let arr2 = [@lib.ValType::i32(), ValType::i64()]
  assert_false(Match::matches(arr1, arr2, env))
}

///|
test "Array: element-wise matching" {
  let env = Env::new()
  let arr1 = [@lib.ValType::i32(), ValType::i64()]
  let arr2 = [@lib.ValType::i32(), ValType::i64()]
  let arr3 = [@lib.ValType::i32(), ValType::f64()]
  assert_true(Match::matches(arr1, arr2, env))
  assert_false(Match::matches(arr1, arr3, env))
}

// =============================================================================
// CompType Tests
// =============================================================================

///|
test "CompType: FuncCompType - contravariant params, covariant results" {
  let env = Env::new()

  // For functions: (p1 -> r1) <: (p2 -> r2) iff p2 <: p1 and r1 <: r2
  // Using ref types for subtyping examples
  let ref_any = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::any())),
  )
  let ref_eq = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::eq())),
  )

  // func(any) -> eq  <:  func(eq) -> any
  // params: eq <: any (contravariant check)
  // results: eq <: any (covariant check)
  let f1 = CompType::func([ref_any], [ref_eq])
  let f2 = CompType::func([ref_eq], [ref_any])
  assert_true(Match::matches(f1, f2, env))
  assert_false(Match::matches(f2, f1, env))
}

///|
test "CompType: FuncCompType - reflexivity" {
  let env = Env::new()
  let f = CompType::func([ValType::i32()], [ValType::i64()])
  assert_true(Match::matches(f, f, env))
}

///|
test "CompType: FuncCompType - param count mismatch" {
  let env = Env::new()
  let f1 = CompType::func([ValType::i32()], [])
  let f2 = CompType::func([ValType::i32(), ValType::i64()], [])
  assert_false(Match::matches(f1, f2, env))
}

///|
test "CompType: StructCompType - field matching" {
  let env = Env::new()
  let s1 = CompType::struct_([
    FieldType::new(StorageType::pack_type(PackType::i8()), Const),
  ])
  let s2 = CompType::struct_([
    FieldType::new(StorageType::pack_type(PackType::i8()), Const),
  ])
  let s3 = CompType::struct_([
    FieldType::new(StorageType::pack_type(PackType::i16()), Const),
  ])
  assert_true(Match::matches(s1, s2, env))
  assert_false(Match::matches(s1, s3, env))
}

///|
test "CompType: ArrayCompType - field matching" {
  let env = Env::new()
  let a1 = CompType::array(
    FieldType::new(StorageType::pack_type(PackType::i8()), Const),
  )
  let a2 = CompType::array(
    FieldType::new(StorageType::pack_type(PackType::i8()), Const),
  )
  let a3 = CompType::array(
    FieldType::new(StorageType::pack_type(PackType::i8()), Var),
  )
  assert_true(Match::matches(a1, a2, env))
  assert_false(Match::matches(a1, a3, env))
}

///|
test "CompType: different kinds don't match" {
  let env = Env::new()
  let func = CompType::func([], [])
  let struct_ = CompType::struct_([])
  let array = CompType::array(
    FieldType::new(StorageType::pack_type(PackType::i8()), Const),
  )
  assert_false(Match::matches(func, struct_, env))
  assert_false(Match::matches(struct_, array, env))
  assert_false(Match::matches(array, func, env))
}

// =============================================================================
// GlobalType Tests
// =============================================================================

///|
test "GlobalType: const is covariant" {
  let env = Env::new()
  let ref_eq = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::eq())),
  )
  let ref_any = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::any())),
  )
  let g1 = @lib.GlobalType(ref_eq, false) // const
  let g2 = @lib.GlobalType(ref_any, false) // const

  // (const eq) <: (const any)
  assert_true(Match::matches(g1, g2, env))
  assert_false(Match::matches(g2, g1, env))
}

///|
test "GlobalType: mut is invariant" {
  let env = Env::new()
  let ref_eq = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::eq())),
  )
  let ref_any = @lib.ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::any())),
  )
  let g1 = @lib.GlobalType(ref_eq, true) // mut
  let g2 = @lib.GlobalType(ref_any, true) // mut

  // (mut eq) does not match (mut any) - invariant
  assert_false(Match::matches(g1, g2, env))
  assert_false(Match::matches(g2, g1, env))
}

///|
test "GlobalType: mut self-match" {
  let env = Env::new()
  let g = @lib.GlobalType(ValType::i32(), true)
  assert_true(Match::matches(g, g, env))
}

///|
test "GlobalType: const vs mut don't match" {
  let env = Env::new()
  let const_g = @lib.GlobalType(ValType::i32(), false)
  let mut_g = @lib.GlobalType(ValType::i32(), true)
  assert_false(Match::matches(const_g, mut_g, env))
  assert_false(Match::matches(mut_g, const_g, env))
}

// =============================================================================
// TableType Tests
// =============================================================================

///|
test "TableType: limits and reftype must match" {
  let env = Env::new()
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let t1 = @lib.TableType(rt, Limits::i32(0, Some(100)))
  let t2 = @lib.TableType(rt, Limits::i32(0, Some(200)))

  // limits: [0..100] <: [0..200]
  // reftype must be invariant
  assert_true(Match::matches(t1, t2, env))
}

///|
test "TableType: reftype is invariant" {
  let env = Env::new()
  let rt_func = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let rt_any = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let limits = Limits::i32(0, Some(100))
  let t1 = @lib.TableType(rt_func, limits)
  let t2 = @lib.TableType(rt_any, limits)

  // Even though func might be a subtype, table element type is invariant
  assert_false(Match::matches(t1, t2, env))
  assert_false(Match::matches(t2, t1, env))
}

// =============================================================================
// TagType Tests
// =============================================================================

///|
test "TagType: requires bidirectional typeidx matching" {
  let env = Env::new()
  // Assuming typeidx 0 exists and matches itself
  let t1 = @lib.TagType(TypeIdx::new(0))
  let t2 = @lib.TagType(TypeIdx::new(0))
  assert_true(Match::matches(t1, t2, env))
}

// =============================================================================
// ExternType Tests
// =============================================================================

///|
test "ExternType: different kinds don't match" {
  let env = Env::new()
  let mem = @lib.MemExternType(MemType(Limits::i32(1, None)))
  let global = @lib.GlobalExternType(GlobalType(ValType::i32(), false))
  assert_false(Match::matches(mem, global, env))
  assert_false(Match::matches(global, mem, env))
}

///|
test "ExternType: MemExternType delegates to MemType" {
  let env = Env::new()
  let m1 = @lib.MemExternType(MemType(Limits::i32(1, Some(10))))
  let m2 = @lib.MemExternType(MemType(Limits::i32(1, Some(20))))
  assert_true(Match::matches(m1, m2, env))
  assert_false(Match::matches(m2, m1, env))
}

///|
test "ExternType: GlobalExternType delegates to GlobalType" {
  let env = Env::new()
  let g1 = @lib.GlobalExternType(GlobalType(ValType::i32(), false))
  let g2 = @lib.GlobalExternType(GlobalType(ValType::i32(), false))
  assert_true(Match::matches(g1, g2, env))
}

///|
test "ExternType: TableExternType delegates to TableType" {
  let env = Env::new()
  let rt = RefType::new(true, HeapType::abs(AbsHeapType::func()))
  let t1 = @lib.TableExternType(TableType(rt, Limits::i32(0, Some(10))))
  let t2 = @lib.TableExternType(TableType(rt, Limits::i32(0, Some(10))))
  assert_true(Match::matches(t1, t2, env))
}

// =============================================================================
// Edge Cases & Integration Tests
// =============================================================================

///|
test "transitive subtyping: i31 <: eq <: any" {
  let env = Env::new()
  // i31 <: eq
  assert_true(Match::matches(AbsHeapType::i31(), AbsHeapType::eq(), env))
  // eq <: any
  assert_true(Match::matches(AbsHeapType::eq(), AbsHeapType::any(), env))
  // i31 <: any (transitively, though not directly in AbsHeapType.matches)
  // This should work through HeapType matching
  let h_i31 = HeapType::abs(AbsHeapType::i31())
  let h_any = HeapType::abs(AbsHeapType::any())
  assert_true(Match::matches(h_i31, h_any, env))
}

///|
test "complex function type subtyping" {
  let env = Env::new()

  // func(ref null any, ref null any) -> (ref null eq)
  // <:
  // func(ref null eq, ref null eq) -> (ref null any)
  let ref_any = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::any())),
  )
  let ref_eq = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::eq())),
  )
  let f1 = CompType::func([ref_any, ref_any], [ref_eq])
  let f2 = CompType::func([ref_eq, ref_eq], [ref_any])
  assert_true(Match::matches(f1, f2, env))
}

///|
test "nested ref type in struct field" {
  let env = Env::new()

  // const field with ref type - covariant
  let ref_eq = RefType::new(true, HeapType::abs(AbsHeapType::eq()))
  let ref_any = RefType::new(true, HeapType::abs(AbsHeapType::any()))
  let st_eq = StorageType::val_type(ValType::ref_type(ref_eq))
  let st_any = StorageType::val_type(ValType::ref_type(ref_any))
  let f1 = FieldType::new(st_eq, Const)
  let f2 = FieldType::new(st_any, Const)
  assert_true(Match::matches(f1, f2, env))
  assert_false(Match::matches(f2, f1, env))
}
